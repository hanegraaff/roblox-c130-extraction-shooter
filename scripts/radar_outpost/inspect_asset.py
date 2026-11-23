"""Reopen the source and independently load both GLBs in empty Blender scenes.
Compare component identity, units, UVs, geometry and panel-state ray intersections.
Run route and camera probes against the saved model and the reimported geometry.
"""
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

# Blender executes -P files outside the script directory.
from layout import BAYS, STAIRS, STEPS, RISE, RUN, ROOF
from envelope import Bay

SOURCE = ROOT/'assets/blender/radar-outpost'
EXPORT = ROOT/'assets/exports/radar-outpost'
catalog = json.loads((SOURCE/'panel-catalog.json').read_text())
bounds_tolerance = .0002


def close(a, b, tol=bounds_tolerance):
    return (Vector(a)-Vector(b)).length < tol


def named(objects):
    return {o.name: o for o in objects if o.type == 'MESH'}


def trees(objects):
    vertices = []
    faces = []
    for o in objects:
        base = len(vertices)
        vertices.extend(o.matrix_world @ v.co for v in o.data.vertices)
        faces.extend(tuple(base+i for i in f.vertices) for f in o.data.polygons)
    return BVHTree.FromPolygons(vertices, faces)


def distance(tree, origin, direction, maximum=100):
    return tree.ray_cast(Vector(origin), Vector(direction).normalized(), maximum)[3]


def snapshot(objects):
    data = {}
    for name, obj in objects.items():
        mesh = obj.data
        mesh.calc_loop_triangles()
        corners = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
        data[name] = {'min': [min(p[k] for p in corners) for k in range(3)],
                      'max': [max(p[k] for p in corners) for k in range(3)],
                      'pivot': list(obj.matrix_world.translation), 'triangles': len(mesh.loop_triangles),
                      'materials': sorted({mesh.materials[p.material_index].name for p in mesh.polygons})}
        assert mesh.uv_layers.active and all(math.isfinite(n)
                                             for v in mesh.uv_layers.active.uv for n in v.vector), name
        assert all(math.isfinite(n) for v in mesh.vertices for n in v.co), name
        assert all(p.area > 1e-10 and abs(p.normal.length-1) < .0001 for p in mesh.polygons), name
    return data


def compare(before, after):
    assert before.keys() == after.keys(), (sorted(before.keys()-after.keys())
                                           [:12], sorted(after.keys()-before.keys())[:12])
    for name, item in before.items():
        match = after[name]
        for prop in ['min', 'max', 'pivot']:
            assert close(item[prop], match[prop]), (name, prop, item[prop], match[prop])
        for prop in ['triangles', 'materials']:
            assert item[prop] == match[prop], (name, prop, item[prop], match[prop])


def combined_extent(items):
    return [[round(f(v[key][a] for v in items.values()), 4) for a in range(3)] for f, key in [(min, 'min'), (max, 'max')]]


def panel_tests(objects):
    bays = {k: Bay(k, a, b, g) for k, a, b, g in BAYS}
    count = 0
    for rec in catalog['panels']:
        bay = bays[rec['id'].split('_')[-1]]
        roof = rec['surface'] == 'Roof'
        for stage, state in rec['states'].items():
            if stage == 'Total':
                assert state == {'visual': None, 'solid': None}
                continue
            for name in state.values():
                obj = objects[name]
                assert close(obj.matrix_world.translation, rec['pivotXYZ']), (name, rec['pivotXYZ'])
                tree = trees([obj])
                for location in (0, -.38, .38):
                    x = location*bay.span
                    if roof:
                        point = bay.roof_point((x, .53, ROOF+4))
                        direction = (0, 0, -1)
                    else:
                        z = 8.58 if rec['story'] == '01' else 17.63
                        point = bay.wall_point((x, 2.5, z))
                        direction = (-bay.out.x, -bay.out.y, 0)
                    d = distance(tree, point, direction, 5.5)
                    assert (d is None) == (stage == 'Heavy' and location == 0), (name, location, d)
                    count += 1
                if not roof:
                    z = (4.63 if rec['story'] == '01' else 13.9)
                    # Axis avoid the corner X brace and the two window bars.
                    x = .13*bay.span
                    p = bay.wall_point((x, 2.5, z))
                    assert distance(tree, p, (-bay.out.x, -bay.out.y, 0),
                                    4.5) is None, (name, 'blocked authored aperture')
                    count += 1
    return count


def routes(assembly, library):
    stable = [o for o in assembly.values() if o.get('role') in ('walkable', 'support')]
    pristine_solids = [o for o in library.values() if o.name.endswith('ProxyIntact')]
    walk = trees(stable+pristine_solids)
    visible = trees(list(assembly.values()))
    floor = trees([o for o in stable if o.get('role') == 'walkable'])
    foot_probes = 0
    min_headroom = 100
    for name, x, sgn in STAIRS:
        for i in range(STEPS):
            y = sgn*(-15+(i+.5)*RUN)
            for dx in (-2.55, 0, 2.55):
                z = (i+1)*RISE
                d = distance(floor, (x+dx, y, z+.25), (0, 0, -1), .55)
                assert d is not None and abs(d-.25) < .002, (name, i, dx, d)
                overhead = distance(walk, (x+dx, y, z+.01), (0, 0, 1))
                if overhead is not None:
                    min_headroom = min(min_headroom, overhead+.01)
                assert overhead is None or overhead > 5.49, (name, i, overhead)
                foot_probes += 1
        for y, z in [(sgn*15.5, 10), (-sgn*16, 0)]:
            assert abs(distance(floor, (x, y, z+.2), (0, 0, -1), .5)-.2) < .001
    assert abs(distance(floor, (0, 20, 10.25), (0, 0, -1), .5)-.25) < .001
    # Ground gate crossing at three heights and three lateral offsets per portal.
    for k, a, b, gate in BAYS:
        if not gate:
            continue
        bay = Bay(k, a, b, gate)
        for z in (.42, 3.15, 5.5):
            for x in (-2.5, 0, 2.5):
                p = bay.wall_point((x, 2.35, z))
                # Follow the approach through the lintel and past installed floor equipment.
                depth = 13.0 if k[0] in ('S', 'N') else 8.5
                assert distance(visible, p, (-bay.out.x, -bay.out.y, 0), depth) is None, (k, x, z)
    gallery = [(0, -19.7), (12, -19.7), (21.2, -19.7), (26.8, -16), (26.8, -7), (26.8, 0),
               (26.8, 13), (25, 17.2), (21, 19), (12, 19), (0, 19), (-12, 19), (-21, 19),
               (-26.8, 15), (-26.8, 0), (-26.8, -15), (-21, -19), (-12, -19)]
    for a, b in zip(gallery, gallery[1:]+gallery[:1]):
        for k in range(11):
            x, y = Vector(a).lerp(Vector(b), k/10)
            assert abs(distance(floor, (x, y, 10.3), (0, 0, -1), .5)-.3) < .001, (x, y)
            assert distance(visible, (x, y, 10.10), (0, 0, 1),
                            5.42) is None, (x, y, 'dressing in gallery route')
    # Camera observations describe available space for a straight trailing camera.
    cameras = {}
    for key, pos, vec in [('court toward south gate', (7, -10, 4), (0, -1, .30)),
                          ('gallery along south walkway', (1, -19.7, 14), (1, 0, .30)),
                          ('gallery looking through an empty bay', (1, -19.7, 14), (0, -1, .30)),
                          ('gallery backed toward a column', (0, -19.7, 14), (0, -1, .30)),
                          ('west stair midway', (-18.5, 1, 9.6), (0, -1, .30))]:
        d = distance(visible, pos, vec, 12.5)
        cameras[key] = round(d, 2) if d is not None else 'clear to 12.5'
    # Sample a standing figure's upper body from directly above at points in the open court.
    sky = {}
    for x, y in [(-9, -8), (9, -8), (10, 5), (-10, 7), (0, -12), (0, 13)]:
        sky[f'{x},{y}'] = distance(visible, (x, y, 5.5), (0, 0, 1), 60) is None
    assert sum(sky.values()) >= 4, sky
    # Measure between opposing visible faces at rail height, with equipment installed.
    widths = {}
    for label, (x, y, z), direction in [
        ('north console to curved gallery rail', (-12.85, 18.3, 11.76), (0, 1, 0)),
        ('west stair between top rails', (-18.5, .05, 7.13), (1, 0, 0)),
    ]:
        positive = distance(visible, (x, y, z), direction, 16)
        negative = distance(visible, (x, y, z), tuple(-v for v in direction), 16)
        if label.startswith('west') and (positive is None or negative is None):
            # Inclined rails pass z=7.13 slightly before the center of tread nine.
            for k in range(21):
                level = z-.26+k*.026
                positive = distance(visible, (x, y, level), direction, 9)
                negative = distance(visible, (x, y, level), tuple(-v for v in direction), 9)
                if positive is not None and negative is not None:
                    break
        assert positive is not None and negative is not None, (label, positive, negative)
        widths[label] = round(positive+negative, 2)
    assert widths['north console to curved gallery rail'] > 4.5
    assert 7.5 < widths['west stair between top rails'] < 8
    return {'stairFootAndHeadProbes': foot_probes, 'stairMinimumOverheadStuds': round(min_headroom, 2),
            'clearWidthsStuds': widths, 'gateCrossings': 36, 'upperLoopSamples': len(gallery)*11, 'cameraClearanceStuds': cameras, 'openSkyAtCourtSamples': sky}


def load_glb(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return named(bpy.context.scene.objects)


def glb_stats(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+length])
    assert not doc.get('cameras') and all(
        'extensions' not in n or 'KHR_lights_punctual' not in n['extensions'] for n in doc['nodes'])
    assert all('uri' not in x for x in doc['buffers']+doc['images'])
    assert all('TEXCOORD_0' in p['attributes'] and 'NORMAL' in p['attributes']
               for m in doc['meshes'] for p in m['primitives'])
    return {'bytes': len(raw), 'objects': len(doc['nodes']), 'uniqueMeshes': len(doc['meshes']),
            'materials': len(doc['materials']), 'packedTextures': len(doc['images']),
            'uniqueTriangles': sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives']),
            'largestPrimitiveTriangles': max(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives']),
            'sha256': hashlib.sha256(raw).hexdigest()}


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'vesper-array.blend'))
    library_group = next(c for c in bpy.data.collections if c.name.startswith('05'))
    library_group.hide_viewport = False
    bpy.context.view_layer.update()
    lib = named(library_group.objects)
    assembly = named(o for c in bpy.data.collections if c.name[:2] in (
        '01', '02', '03', '04') for o in c.objects)
    src = snapshot(assembly)
    damage = snapshot(lib)
    assert all(img.packed_file for img in bpy.data.images if img.source == 'FILE')
    texture_bytes = sum(i.size[0]*i.size[1]*4 for i in bpy.data.images if i.source == 'FILE')
    source_checks = panel_tests(assembly | lib)
    source_routes = routes(assembly, lib)
    art = EXPORT/'vesper-array.glb'
    libpath = EXPORT/'damage-library.glb'
    imported = load_glb(art)
    rebuilt = snapshot(imported)
    compare(src, rebuilt)
    assert close(rebuilt['Foundation • 64 x 48']['min'], (-32, -24, -.66))
    assert close(rebuilt['Foundation • 64 x 48']['max'], (32, 24, 0))
    # Load the supplemental states into the same empty import scene for cross-file tests.
    bpy.ops.import_scene.gltf(filepath=str(libpath))
    imported_lib = named(o for o in bpy.context.scene.objects if o.name in lib)
    # The second GLB brings identical shared materials; Blender suffixes the duplicate names.
    restored = snapshot(imported_lib)
    for item in restored.values():
        item['materials'] = [k.partition('.')[0] for k in item['materials']]
    compare(damage, restored)
    assert source_checks == panel_tests(imported | imported_lib)
    assert source_routes == routes(imported, imported_lib)
    bounds = combined_extent(rebuilt)
    for lo, hi, limit in zip(bounds[0][:2], bounds[1][:2], (32, 24)):
        assert abs(lo+limit) < .001 and abs(hi-limit) < .001, (lo, hi)
    assert bounds[1][2]+catalog['robloxSiteXYZ'][1] < 32
    metrics = glb_stats(art)
    metrics['assembledTriangles'] = sum(item['triangles'] for item in rebuilt.values())
    assert metrics['assembledTriangles'] < 125000 and metrics['largestPrimitiveTriangles'] < 10000
    result = {'blender': bpy.app.version_string, 'sourceSha256': hashlib.sha256((SOURCE/'vesper-array.blend').read_bytes()).hexdigest(),
              'siteBoundsBlenderXYZ': combined_extent(rebuilt), 'pristineAssembly': metrics, 'damageLibrary': glb_stats(libpath),
              'decodedSourceTexturesRGBA8Bytes': texture_bytes, 'panelCount': len(catalog['panels']),
              'panelRaysPerRepresentation': source_checks, 'routesSourceAndReimport': source_routes}
    (ROOT/'docs/images/radar-outpost/inspection.json').write_text(json.dumps(result, indent=2)+'\n')
    print('VESPER ROUND TRIP OK', json.dumps(result))


main()
