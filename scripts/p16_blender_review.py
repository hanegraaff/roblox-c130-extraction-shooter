"""Clean-open P16, audit real saved/exported data and render review cameras.

Blender command: Blender --background <military-outpost.blend> --python
scripts/p16_blender_review.py -- --audit --render. Only evidence outputs change;
the reviewed .blend is never saved or mutated on disk. --render may be limited
with --view Exterior / Floor_1 / Floor_2 / Cutaway / damage.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/blender/military-outpost'
EXPORT=ROOT/'assets/exports/military-outpost'
EVIDENCE=ROOT/'docs/evidence/p16'
sys.path.insert(0,str(ROOT/'scripts'))
import p16_audit as portable_audit


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def bounds(obj):
    pts=[obj.matrix_world@Vector(p) for p in obj.bound_box]
    return [[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]]


def mesh_info(obj):
    deps=bpy.context.evaluated_depsgraph_get();eo=obj.evaluated_get(deps);me=eo.to_mesh();me.calc_loop_triangles()
    record=dict(name=obj.name,triangles=len(me.loop_triangles),vertices=len(me.vertices),uv_layers=len(me.uv_layers),bounds=bounds(eo),
      materials=[m.name.split('.')[0] for m in me.materials],material_triangles={})
    for tri in me.loop_triangles:
        material=me.materials[tri.material_index].name.split('.')[0]
        record['material_triangles'][material]=record['material_triangles'].get(material,0)+1
    eo.to_mesh_clear();return record


def blender_geometry(objects):
    """Read evaluated world-space triangle meshes; never substitute dimensions."""
    deps=bpy.context.evaluated_depsgraph_get();vertices=[];triangles=[];names=[]
    for o in objects:
        if o.type!='MESH':continue
        evaluated=o.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles();offset=len(vertices)
        vertices.extend(tuple(o.matrix_world@v.co) for v in mesh.vertices)
        for tri in mesh.loop_triangles:
            triangles.append(tuple(offset+i for i in tri.vertices));names.append(o.name)
        evaluated.to_mesh_clear()
    return dict(vertices=vertices,triangles=triangles,triangle_objects=names)


def audit():
    assert bpy.data.filepath and Path(bpy.data.filepath).resolve()==SOURCE/'military-outpost.blend','wrong saved source'
    inventory=json.loads((SOURCE/'asset-inventory.json').read_text())
    required=[f'{i:02d}_' for i in range(1,12)]
    for prefix in required:assert any(c.name.startswith(prefix) for c in bpy.data.collections),prefix
    cameras=['Exterior','Floor_1','Floor_2','Cutaway','Damage_front','Damage_back','Isolated_kit']
    for name in cameras:assert name in bpy.data.objects and bpy.data.objects[name].type=='CAMERA',name
    images=[]
    for im in bpy.data.images:
        if im.type!='IMAGE':continue
        images.append(dict(name=im.name,size=list(im.size),packed=im.packed_file is not None,filepath=im.filepath))
        assert im.packed_file is not None,'unpacked dependency '+im.name
        assert list(im.size)==[512,512],im.name
    assert len(images)==12,images
    for m in bpy.data.materials:
        if not m.use_nodes:continue
        textures=[n for n in m.node_tree.nodes if n.type=='TEX_IMAGE']
        assert len(textures)==1 and textures[0].image is not None,'missing baked texture '+m.name
    assembly=[]
    for c in bpy.data.collections:
        if c.name[:2] in ('01','02','03','04','05'):
            assembly.extend(mesh_info(o) for o in c.objects if o.type=='MESH')
    assert sum(o['triangles'] for o in assembly)==inventory['measured']['assembly_triangles']
    assert all(o['uv_layers']>0 and o['materials'] for o in assembly)
    source_objects=[o for c in bpy.data.collections if c.name[:2] in ('01','02','03','04','05') for o in c.objects if o.type=='MESH']
    navigation=portable_audit.inspect_navigation(blender_geometry(source_objects))
    max_mesh=max(o['triangles'] for o in assembly)
    # FBX import-friendly per-mesh limit selected for audit; actual Roblox cost P17.
    assert max_mesh<=10000,('per mesh triangle cap',max_mesh)
    report=dict(suite='P16BlenderReopen',passed=True,blender_version=bpy.app.version_string,
      source_sha256=digest(SOURCE/'military-outpost.blend'),collection_count=len(bpy.data.collections),cameras=cameras,
      images=images,missing_dependencies=0,assembly_meshes=len(assembly),assembly_triangles=sum(o['triangles'] for o in assembly),
      max_mesh_triangles=max_mesh,navigation=navigation,assets=assembly)
    (EVIDENCE/'blender-reopen.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('assets','images')}))
    return assembly


def prepare(view):
    for c in bpy.context.scene.collection.children:
        c.hide_viewport=False;c.hide_render=c.name[:2] in ('06','07','08','11')
        for o in c.objects:o.hide_render=bool(o.get('export_only'))
    scene=bpy.context.scene
    scene.camera=bpy.data.objects[view]
    if view=='Isolated_kit':
        bpy.data.objects['Review ground'].hide_render=True
        for c in bpy.context.scene.collection.children:c.hide_render=c.name not in ('11_Reusable_Kit','09_Review_Cameras_Lights')
    if view=='Cutaway':
        for o in bpy.data.collections['02_Destructible_Panels'].objects:
            if 'Roof' in o.name:o.hide_render=True
        for o in bpy.data.collections['01_Stable_Structure'].objects:
            if 'Roof parapet' in o.name:o.hide_render=True
        for o in bpy.data.collections['03_Exterior_Dressing'].objects:
            if any(k in o.name for k in ('Rooftop','HVAC','Mast','Antenna','Satellite','Dish','Roof conduit')):o.hide_render=True
    if view.startswith('Floor'):
        bpy.data.collections['10_Scale_Guide'].hide_render=True
    scene.render.resolution_x=1280;scene.render.resolution_y=900
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'


def render_view(view):
    prepare(view)
    scene=bpy.context.scene;scene.render.filepath=str(EVIDENCE/(view.lower().replace('_','-')+'.png'))
    bpy.ops.render.render(write_still=True)
    return [Path(scene.render.filepath)]


def damage_renders():
    rendered=[]
    scene=bpy.context.scene
    catalog=json.loads((SOURCE/'panel-catalog.json').read_text())
    for c in scene.collection.children:c.hide_render=c.name not in ('06_Damage_Gallery','09_Review_Cameras_Lights')
    for o in bpy.data.collections['09_Review_Cameras_Lights'].objects:
        if o.type=='MESH':o.hide_render=True
    col=bpy.data.collections['06_Damage_Gallery'];col.hide_viewport=False
    scene.render.resolution_x=1600;scene.render.resolution_y=440
    # Color-management monochrome is a true view transform of same geometry/light.
    scene.view_settings.view_transform='AgX'
    for fi,fam in enumerate(catalog['families']):
        gy=fi*22;h=fam['dimensions_studs'][2]
        for i,o in enumerate(v for v in bpy.data.collections['09_Review_Cameras_Lights'].objects if v.type=='LIGHT'):
            o.location=(15+i*12,gy+(-18 if i%2 else 18),25)
            o.rotation_euler=(Vector((30,gy,4))-o.location).to_track_quat('-Z','Y').to_euler()
            o.data.energy=16000;o.data.color=(1,1,1)
        scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.4,.4,.4,1)
        for o in col.objects:
            o.hide_render=not (gy-4<=o.location.y<=gy+4)
        for side in ('front','back'):
            camera=bpy.data.objects['Damage_'+side]
            camera.data.type='ORTHO';camera.data.ortho_scale=82
            camera.location=(30,gy+(-55 if side=='front' else 55),h*.5+9)
            target=Vector((30,gy,h*.5-.4))
            camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
            # For back view order is intentionally reversed; each caption identifies state.
            for mode in ('normal','grayscale'):
                scene.render.filepath=str(EVIDENCE/f"damage-{fam['id']}-{side}-{mode}.png")
                # Native CPU color-mode conversion avoids a GPU compositor requirement.
                scene.render.image_settings.color_mode='BW' if mode=='grayscale' else 'RGB'
                bpy.ops.render.render(write_still=True)
                rendered.append(Path(scene.render.filepath))
    scene.render.image_settings.color_mode='RGB'
    return rendered


def fbx_audit(expected):
    library_cols=[bpy.data.collections[k] for k in ('07_Panel_Library','08_Collision_Proxies')]
    for c in library_cols:
        c.hide_viewport=False
        for o in c.objects:o.hide_set(False)
    bpy.context.view_layer.update()
    library_expected=[mesh_info(o) for c in library_cols for o in c.objects if o.type=='MESH']
    # A new empty scene in this process ensures the importer cannot accidentally
    # reuse authored objects. Reopen itself was already a separate clean process.
    for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.import_scene.fbx(filepath=str(EXPORT/'outpost-assembly-v1.fbx'),use_anim=False)
    imported={o.name:mesh_info(o) for o in bpy.context.scene.objects if o.type=='MESH'}
    assert set(imported)=={o['name'] for o in expected},('mesh identity mismatch',len(imported),len(expected))
    maxerr=0
    for before in expected:
        after=imported[before['name']]
        assert after['triangles']==before['triangles'],before['name']
        assert after['uv_layers']>0,before['name']
        assert after['material_triangles']==before['material_triangles'],('FBX material mismatch',before['name'])
        err=max(abs(a-b) for rowa,rowb in zip(before['bounds'],after['bounds']) for a,b in zip(rowa,rowb));maxerr=max(maxerr,err)
        assert err<.001,(before['name'],err)
    navigation=portable_audit.inspect_navigation(blender_geometry([o for o in bpy.context.scene.objects if o.type=='MESH']))
    for mat in bpy.data.materials:
        if mat.users==0 or not mat.use_nodes:continue
        images=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE']
        assert images and all(im is not None and (im.packed_file or Path(bpy.path.abspath(im.filepath)).is_file()) for im in images),('FBX missing texture',mat.name)
    for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.import_scene.fbx(filepath=str(EXPORT/'panel-library-v1.fbx'),use_anim=False)
    lib={o.name:mesh_info(o) for o in bpy.context.scene.objects if o.type=='MESH'}
    assert set(lib)=={o['name'] for o in library_expected},('panel library identities',len(lib),len(library_expected))
    for before in library_expected:
        after=lib[before['name']]
        assert after['triangles']==before['triangles'] and after['uv_layers']>0,before['name']
        assert after['material_triangles']==before['material_triangles'],('panel FBX material mismatch',before['name'])
        assert max(abs(a-b) for ra,rb in zip(before['bounds'],after['bounds']) for a,b in zip(ra,rb))<.001,before['name']
    kit_records=[]
    for entry in json.loads((SOURCE/'reusable-kit.json').read_text())['assets']:
        for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.ops.import_scene.fbx(filepath=str(EXPORT/entry['fbx']),use_anim=False)
        meshes=[mesh_info(o) for o in bpy.context.scene.objects if o.type=='MESH']
        assert len(meshes)==1 and meshes[0]['triangles']==entry['triangles'] and meshes[0]['uv_layers']>0,entry['family']
        kit_records.append(dict(family=entry['family'],fbx_sha256=digest(EXPORT/entry['fbx']),triangles=entry['triangles']))
    report=dict(suite='P16ExportAudit-FBX',passed=True,blender_version=bpy.app.version_string,
      fbx_sha256=digest(EXPORT/'outpost-assembly-v1.fbx'),imported_meshes=len(imported),
      imported_triangles=sum(o['triangles'] for o in imported.values()),max_bound_error_studs=maxerr,
      scale_axes_verified=True,uv_materials_verified=True,navigation=navigation,panel_library_meshes=len(lib),
      panel_library_sha256=digest(EXPORT/'panel-library-v1.fbx'),reusable_kit=kit_records)
    (EVIDENCE/'fbx-import.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))


def write_render_metadata(rendered=None):
    """Regenerate complete source/script/image proof using only verified receipts.

    Partial --view runs retain prior receipts only for the identical source and
    review script. Merely leaving old PNGs in the directory cannot count as a new
    render. --render-manifest-only rebinds the already verified receipt to HEAD
    after the coordinator commits the tested source; no ad-hoc snippet is needed.
    """
    source_hash=digest(SOURCE/'military-outpost.blend');script_hash=digest(Path(__file__))
    receipt_path=EVIDENCE/'render-evidence.json';files={}
    if receipt_path.exists():
        previous=json.loads(receipt_path.read_text())
        if previous.get('source_sha256')==source_hash and previous.get('review_script_sha256')==script_hash:
            for entry in previous['files']:
                path=ROOT/entry['path']
                if path.is_file() and portable_audit.png_record(path,ROOT)==entry:files[entry['path']]=entry
    for path in rendered or ():
        entry=portable_audit.png_record(path,ROOT);files[entry['path']]=entry
    expected=portable_audit.expected_render_paths(json.loads((SOURCE/'panel-catalog.json').read_text()))
    complete=set(files)==expected
    if rendered is None:assert complete,'incomplete or stale render receipts; run full --render first'
    receipt=dict(schema_version=1,suite='P16SavedSceneRenders',passed=complete,blender_version=bpy.app.version_string,
      source_path=str((SOURCE/'military-outpost.blend').relative_to(ROOT)),source_sha256=source_hash,
      review_script_path=str(Path(__file__).resolve().relative_to(ROOT)),review_script_sha256=script_hash,
      command=['/Applications/Blender.app/Contents/MacOS/Blender','--background','assets/blender/military-outpost/military-outpost.blend',
        '--python-exit-code','1','--python','scripts/p16_blender_review.py','--','--render'],
      renderer='Cycles CPU,24samples,denoising; native PNG BW grayscale, no GPU compositor',
      image_count=len(files),files=[files[path] for path in sorted(files)])
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    matches=True
    for path,expected_hash in ((receipt['source_path'],source_hash),(receipt['review_script_path'],script_hash)):
        try:committed=subprocess.check_output(['git','show',f'{commit}:{path}'],cwd=ROOT,stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:matches=False;continue
        matches=matches and hashlib.sha256(committed).hexdigest()==expected_hash
    manifest=dict(receipt,source_commit=commit,source_commit_matches_art=matches)
    (EVIDENCE/'render-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(dict(suite='P16SavedSceneRenders',passed=complete,image_count=len(files),source_sha256=source_hash,source_commit=commit,source_commit_matches_art=matches)))


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    p=argparse.ArgumentParser();p.add_argument('--audit',action='store_true');p.add_argument('--render',action='store_true');p.add_argument('--view',action='append');p.add_argument('--fbx-audit',action='store_true');p.add_argument('--render-manifest-only',action='store_true');a=p.parse_args(args)
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    expected=audit() if a.audit or a.fbx_audit else None
    if a.render:
        rendered=[]
        views=a.view or ['Exterior','Floor_1','Floor_2','Cutaway','Isolated_kit','damage']
        for view in views:
            rendered.extend(damage_renders() if view=='damage' else render_view(view))
        write_render_metadata(rendered)
    if a.render_manifest_only:write_render_metadata()
    if a.fbx_audit:fbx_audit(expected)


if __name__=='__main__':main()
