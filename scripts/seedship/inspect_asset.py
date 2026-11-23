"""Measure the saved source and independently reimport all three glTFs for art QA."""
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path[:0]=[str(HERE),str(HERE.parent/'radar_outpost')]
from hull import Face

SOURCE=ROOT/'assets/blender/alien-spaceship'
EXPORT=ROOT/'assets/exports/alien-spaceship'
CATALOG=json.loads((SOURCE/'panel-catalog.json').read_text())
LIBRARIES=['light-and-intact-proxies.glb','heavy-and-fragments.glb']
DOWN=Vector((0,0,-1))
UP=-DOWN


def close(a,b,eps=.002):
    return (Vector(a)-Vector(b)).length < eps


def bvh(objects):
    vertices=[]
    faces=[]
    for o in objects:
        start=len(vertices)
        vertices.extend(o.matrix_world @ v.co for v in o.data.vertices)
        o.data.calc_loop_triangles()
        faces.extend([[start+i for i in f.vertices] for f in o.data.loop_triangles])
    return BVHTree.FromPolygons(vertices,faces,all_triangles=True)


def snapshot(objects):
    result={}
    for o in objects:
        m=o.data
        m.calc_loop_triangles()
        assert m.uv_layers.active and all(math.isfinite(k) for p in m.uv_layers.active.uv for k in p.vector),o.name
        assert all(math.isfinite(k) for v in m.vertices for k in v.co),o.name
        # The glTF exporter may discard zero-area triangles from imported n-gons.
        assert all(p.area>1e-11 and abs(p.normal.length-1)<.002 for p in m.polygons),o.name
        coords=[o.matrix_world @ v.co for v in m.vertices]
        result[o.name]=dict(low=[min(v[k] for v in coords) for k in range(3)],
                            high=[max(v[k] for v in coords) for k in range(3)],
                            origin=list(o.matrix_world.translation),triangles=len(m.loop_triangles),
                            role=o.get('Role'),materials={s.name.split(' • ')[0] for s in m.materials})
    return result


def compare(src,imp):
    assert src.keys()==imp.keys(),src.keys() ^ imp.keys()
    for name,old in src.items():
        new=imp[name]
        for key in ('low','high','origin'):
            assert close(old[key],new[key]),(name,key,old[key],new[key])
        for key in ('role','materials','triangles'):
            assert old[key]==new[key],(name,key,old[key],new[key])


def gltf_stats(path):
    raw=path.read_bytes()
    size=struct.unpack_from('<I',raw,12)[0]
    d=json.loads(raw[20:20+size])
    assert not d.get('cameras') and not d.get('animations') and 'KHR_lights_punctual' not in d.get('extensionsUsed',[])
    assert all('uri' not in item for item in d['buffers']+d['images'])
    assert all({'NORMAL','TEXCOORD_0','POSITION'}<=p['attributes'].keys() for m in d['meshes'] for p in m['primitives'])
    tris=[sum(d['accessors'][p['indices']]['count']//3 for p in m['primitives']) for m in d['meshes']]
    return dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),objects=len(d['nodes']),uniqueMeshes=len(tris),
                assembledTriangles=sum(tris[n['mesh']] for n in d['nodes'] if 'mesh' in n),
                largestMeshTriangles=max(tris),materials=len(d['materials']),embeddedImages=len(d['images']))


def distance(tree,p,dir,limit):
    return tree.ray_cast(Vector(p),Vector(dir).normalized(),limit)[3]


def navigation(objects):
    all_art=bvh(objects)
    floors=bvh(o for o in objects if o.get('Role','').startswith('Walkable'))
    def sample(x,y,z):
        d=distance(floors,(x,y,z+.26),DOWN,.51)
        assert d is not None and abs(d-.26)<.045,('missing support',x,y,z,d)
        head=distance(all_art,(x,y,z+.14),UP,60)
        assert head is None or head+.14>5.55,('standing clearance',x,y,z,head)
        return head+.14 if head is not None else 60
    stair=[]; galleries=[]; hall=[]
    for sign in (-1,1):
        for step in range(24):
            for offset in (-3.8,0,3.8):
                stair.append(sample(sign*56+offset,-38.5+step,16*(step+1)/24))
        for y in range(-14,33):
            for offset in (-2,0,2):
                galleries.append(sample(sign*56+offset,y,16))
        for y in range(-50,-38):
            hall.append(sample(sign*56,y-.5,0))
    for x in range(-56,57):
        for y in (30,32,34):
            galleries.append(sample(x,y,16))
    for y in range(-56,44):
        for x in (-8,8):
            hall.append(sample(x,y,0))
    for x in range(-97,98):
        if abs(x)>12:
            hall.append(sample(x,0,0))
    for j in range(6):
        hall.append(sample(0,-71+j*2,-2.4+(j+1)*.4))
    # Probe both edges of the specified gate widths, plus the center, at
    # shin, shoulder and head height. Sensors start outside the fitted shell.
    rays=0
    for offset in (-15.96,-8,0,8,15.96):
        for h in (.5,3.3,5.5):
            assert distance(all_art,(offset,-65,h),(0,1,0),18) is None,('south gate',offset,h)
            rays+=1
    for side in (-1,1):
        for offset in (-7.96,0,7.96):
            for h in (.5,3.3,5.5):
                assert distance(all_art,(side*105,offset,h),(-side,0,0),17) is None,('side gate',side,offset,h)
                rays+=1
    for x in (60,62,64):
        for h in (1.3,3.4,5.5):
            assert distance(all_art,(x,-62,h),(0,1,0),20) is None,('impact opening',x,h)
            rays+=1
        for y in range(-59,-46):
            point=floors.ray_cast((x,y,2.3),DOWN,6)[0]
            assert point is not None,('impact threshold',x,y)
            sample(x,y,point.z)
    cams={}
    for label,p,d in [('arrival hall',(-6,-28,4),(0,-1,.28)),('mid stair',(56,-27,12),(0,-1,.26)),
                      ('crossover',(17,30,20),(-1,0,.25)),('vault',(65,23,4),(-1,0,.2))]:
        dist=distance(all_art,p,d,12.5)
        cams[label]=round(dist,2) if dist is not None else 'clear to 12.5'
    return dict(treadSamples=len(stair),minimumStairHeadroom=round(min(stair),2),upperRouteSamples=len(galleries),
                minimumUpperRouteHeadroom=round(min(galleries),2),groundRouteSamples=len(hall),entryCrossingRays=rays,
                impactThresholdSamples=39,trailingCameraRaysStuds=cams)


def recovery_checks(objects):
    """Verify the sole specimen, its actual bedding, and the furnished access route."""
    names = {o.name for o in objects}
    assert not any(n.startswith('Scale •') for n in names), 'Survey figure in assembly'
    bodies = [o for o in objects if o.get('Role') == 'PreservedSpecimen']
    details = [o for o in objects if o.get('Role') == 'SpecimenDetail']
    assert len(bodies) == 1 and len(details) == 2
    equipment = [o for o in objects if o.get('Equipment')]
    gear = {o['Equipment']: o for o in equipment}
    expected = {'ExaminationSlab','Telemetry','Scanner','DiagnosticTerminal','InductionDrive',
                'PhaseManifold','MemoryRack','InstrumentTray','FoldNavigator'}
    assert set(gear) == expected, expected ^ set(gear)
    assert len(equipment) == len(expected), 'Duplicated recovery equipment'
    # Blender can read boolean glTF extras as integer ID properties.
    assert all(o.get('ThermalNonCover') == 1 for o in [*bodies,*details,*equipment])
    cx,cy,_ = gear['ExaminationSlab'].matrix_world.translation
    bed,skin = bvh([gear['ExaminationSlab']]),bvh(bodies)
    clearances = {}
    for label,dx,dy in [('cranium',0,3.15),('upper back',0,.42),('pelvis',0,-1.02),('right calf',.54,-2.83)]:
        x,y = cx+dx,cy+dy
        pad = bed.ray_cast((x,y,6),DOWN,6)[0]
        underside = skin.ray_cast((x,y,1),UP,6)[0]
        assert pad is not None and underside is not None,label
        gap = underside.z-pad.z
        assert -.045 <= gap <= .17,(label,gap)
        clearances[label] = round(gap,3)

    # Follow a four-stud-wide route from the central side aisle to the near
    # edge of the slab. Five height probes include its center and four corners.
    furnishings = bvh(objects)
    floor = bvh(o for o in objects if o.get('Role') == 'WalkableFloor')
    probes = 0
    for station in range(14):
        y = 1.25+station
        for dx,dy in [(0,0),(-2,-.75),(2,-.75),(-2,.75),(2,.75)]:
            x = cx-4.45+dx
            support = floor.ray_cast((x,y+dy,.4),DOWN,.6)[0]
            assert support is not None,(x,y+dy)
            assert distance(furnishings,(x,y+dy,.16),UP,5.5) is None,('obstructed berth approach',x,y+dy)
            probes += 1
    return dict(preservedSpecimens=1,instruments=sorted(gear),bedGapStuds=clearances,
                clearBerthApproachSamples=probes)


def panel_checks(objects):
    by_name={o.name:o for o in objects}
    count=0
    fractions=[]
    for record in CATALOG['panels']:
        label=record['id']
        _,tier,index=label.split('_')
        face=Face(int(index)-1,['Skirt','Mantle','Roof','Crown'].index(tier))
        trees={}
        for key in ('pristine','light','heavy','intactAndLightQuery','heavyQuery'):
            obj=by_name[record[key]]
            assert close(obj.matrix_world.translation,record['pivot']) and obj['PanelId']==label,(key,label)
            trees[key]=bvh([obj])
        assert record['total'] is None
        original=left=0
        center_clear=False
        for ix in range(21):
            for iy in range(17):
                u,v=(ix+.41)/21,(iy+.39)/17
                origin=face.point(u,v,3)
                hits={key:distance(tree,origin,-face.norm,7) is not None for key,tree in trees.items()}
                assert not hits['heavyQuery'] or hits['intactAndLightQuery'],('residual outside intact',label,u,v)
                # Near a bevel, the oblique projection of the cosmetic metal can
                # differ from the proxy. Test away from silhouettes and cut faces.
                if hits['intactAndLightQuery']:
                    original+=1
                    if hits['heavyQuery']:
                        left+=1
                    if not hits['heavyQuery'] and not hits['heavy'] and .26<(v if face.cut_axis else u)<.74:
                        center_clear=True
                if hits['heavyQuery']:
                    assert hits['heavy'],('missing visible residual',label,u,v)
                if hits['intactAndLightQuery']:
                    assert hits['pristine'] and hits['light'],('missing skin',label,u,v)
                count+=len(trees)
        fraction=1-left/original
        assert center_clear and .435<=fraction<=.565,(label,fraction,original)
        fractions.append(fraction)
    return dict(panelCount=len(fractions),raycasts=count,minSampledHeavyOpenFraction=round(min(fractions),3),
                maxSampledHeavyOpenFraction=round(max(fractions),3))


def main():
    p=SOURCE/'prism-seedship.blend'
    bpy.ops.wm.open_mainfile(filepath=str(p))
    groups=sorted((c for c in bpy.data.collections if c.name[:2].isdigit()),key=lambda c:c.name)
    assert len(groups)==6
    assert groups[4].hide_render and groups[4].hide_viewport
    groups[4].hide_viewport=False
    bpy.context.view_layer.update()
    review_sets={o.name for o in groups[5].objects if o.type=='MESH'}
    assert review_sets=={'Set • dry lake bed','Set • eroded mesas and talus'},review_sets
    assert not any(o.name.startswith('Scale •') or o.type=='ARMATURE' for o in bpy.data.objects)
    assert bpy.context.scene.camera.name=='Recovery bay'
    assembly=[o for g in groups[:4] for o in g.objects]
    lib=list(groups[4].objects)
    src,alt=snapshot(assembly),snapshot(lib)
    recovery=recovery_checks(assembly)
    source_nav=navigation(assembly)
    source_panels=panel_checks(assembly+lib)
    images=[i for i in bpy.data.images if i.source=='FILE']
    assert all(i.packed_file for i in images)
    texture_bytes=sum(i.size[0]*i.size[1]*4 for i in images)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(EXPORT/'prism-seedship.glb'))
    imported=list(bpy.context.scene.objects)
    compare(src,snapshot(imported))
    assert recovery_checks(imported)==recovery
    nav=navigation(imported)
    assert nav==source_nav,(nav,source_nav)
    for name in LIBRARIES:
        bpy.ops.import_scene.gltf(filepath=str(EXPORT/name))
    library=[o for o in bpy.context.scene.objects if o.name in alt]
    compare(alt,snapshot(library))
    checked=panel_checks(imported+library)
    assert checked==source_panels
    limits=[[round(op(a[key][k] for a in src.values()),3) for k in range(3)] for op,key in [(min,'low'),(max,'high')]]
    assert limits[1][0]-limits[0][0]<=212 and limits[1][1]-limits[0][1]<=146 and abs(limits[1][2]-40)<.005,limits
    assert len(CATALOG['fragments'])==4
    report=dict(blender=bpy.app.version_string,sourceSha256=hashlib.sha256(p.read_bytes()).hexdigest(),
                sourceAndReimportWorldBounds=limits,textureDecodedBytes=texture_bytes,sourceAndReimportRoutes=nav,
                sourceAndReimportRecoveryBay=recovery,reviewSurveyFigures=0,sourceAndReimportPanels=checked,files={n:gltf_stats(EXPORT/n) for n in ['prism-seedship.glb',*LIBRARIES]})
    (ROOT/'docs/images/alien-spaceship/inspection.json').write_text(json.dumps(report,indent=2)+'\n')
    print('SEEDSHIP ROUND TRIP OK',json.dumps(report))


main()
