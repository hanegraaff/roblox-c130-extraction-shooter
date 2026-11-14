"""Read-only independent route headroom probe for saved source or clean FBX."""
import bpy,json,sys,hashlib,argparse
from pathlib import Path
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--expected-source');p.add_argument('--fbx',action='store_true');args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
root=Path.cwd();source=root/'assets/blender/military-outpost/military-outpost.blend';fbx=root/'assets/exports/military-outpost/outpost-assembly-v1.fbx'
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
if args.expected_source:assert source_hash==args.expected_source
if args.fbx:
 for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.import_scene.fbx(filepath=str(fbx),use_anim=False)
else:
 assert Path(bpy.data.filepath).resolve()==source.resolve()
 images=[im for im in bpy.data.images if im.type=='IMAGE']
 assert len(images)==12
 for im in images:assert im.packed_file and len(im.pixels)==512*512*4 and list(im.size)==[512,512],im.name
 assert len(bpy.data.collections)==11
 for name in ['Exterior','Floor_1','Floor_2','Cutaway','Damage_front','Damage_back','Isolated_kit']:assert bpy.data.objects[name].type=='CAMERA'
 for c in bpy.context.scene.collection.children:c.hide_viewport=c.name[:2] not in ('01','02','03','04','05')
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();samples=[]
for route,count,x0,y0,run,rise,extra,forward_offsets in [('Internal',16,-10,-15,2,.625,0,[-.7,0,.7]),('External',20,19.5,-28,1,.5,0,[-.3,0,.3])]:
 for step in range(count):
  foot=.125+(step+1)*rise+extra
  for lateral in [-1.8,0,1.8]:
   for forward in forward_offsets:
    point=Vector((x0+lateral,y0+run*step+forward,foot+.02))
    hit,where,normal,index,obj,matrix=bpy.context.scene.ray_cast(deps,point,Vector((0,0,1)),distance=6)
    samples.append(dict(route=route,step=step+1,position=list(point),blocked=hit,object=obj.name if hit else None,clearance=where.z-point.z if hit else 6))
failures=[s for s in samples if s['blocked']]
report=dict(suite='P16-independent-navigation',mode='FBX' if args.fbx else 'SavedBlend',source_sha256=source_hash,fbx_sha256=hashlib.sha256(fbx.read_bytes()).hexdigest(),packed_images_verified=12 if not args.fbx else None,samples=len(samples),failed_samples=len(failures),failures=failures,passed=not failures)
print('P16_INDEPENDENT_NAVIGATION '+json.dumps(report))
assert not failures,(len(failures),failures[:5])
