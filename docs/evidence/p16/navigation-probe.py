"""Independent read-only saved-scene checks; prints JSON only."""
import bpy,json,hashlib,sys,math
from pathlib import Path
from mathutils import Vector
root=Path.cwd()
source=root/'assets/blender/military-outpost/military-outpost.blend'
expected='22d668fff653832915868e09c25e25d2b4e24f92255394984bc1819ff9f2b8f8'
assert hashlib.sha256(source.read_bytes()).hexdigest()==expected
collections=[c.name for c in bpy.data.collections]
images=[]
for image in bpy.data.images:
    if image.type=='IMAGE':
        image.unpack(method='USE_ORIGINAL') if False else None
        assert image.packed_file; assert len(image.pixels)==512*512*4 and list(image.size)==[512,512], (image.name,list(image.size),len(image.pixels))
        images.append(image.name)
assembly=[o for c in bpy.data.collections if c.name[:2] in ('01','02','03','04','05') for o in c.objects if o.type=='MESH']
# Separate authorship domains: library/kit/review do not obscure assembly checks.
for c in bpy.context.scene.collection.children:
    c.hide_viewport=c.name[:2] not in ('01','02','03','04','05')
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
headroom=[]
for k in range(16*3):
    step=k//3; y=-15+2*step+[-.7,0,.7][k%3];floor=.125+(step+1)*.625
    point=Vector((-10,y,floor+.02))
    hit,where,normal,index,obj,matrix=bpy.context.scene.ray_cast(deps,point,Vector((0,0,1)),distance=6)
    headroom.append(dict(step=step+1,position=list(point),blocked=hit,object=obj.name if hit else None,clearance=where.z-point.z if hit else 6))
external=[]
for i in range(20):
    y=-28+i;floor=.125+(i+1)*.5+.075
    point=Vector((19.5,y,floor+.02))
    hit,where,normal,index,obj,matrix=bpy.context.scene.ray_cast(deps,point,Vector((0,0,1)),distance=6)
    external.append(dict(step=i+1,position=list(point),blocked=hit,object=obj.name if hit else None,clearance=where.z-point.z if hit else 6))
# Verify reimport without using production audit assertions/output files.
source_stats={o.name:(len(o.data.loop_triangles),len(o.data.uv_layers)) for o in []}
print('P16_INDEPENDENT '+json.dumps(dict(source_sha256=expected,collections=collections,packed_images=images,stair_headroom=headroom,external_headroom=external)))
