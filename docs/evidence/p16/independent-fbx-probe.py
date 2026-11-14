"""Clean-process FBX vs OBJ cross-format probe; no source data loaded."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
root=Path.cwd();directory=root/'assets/exports/military-outpost'

def obj_stats(path):
    # OBJ entries are world-space; each object's vertices precede its faces.
    result={};current=None;vertices=[]
    for line in path.read_text().splitlines():
        parts=line.split()
        if not parts:continue
        if parts[0]=='o':
            current=' '.join(parts[1:]);result[current]={'points':[],'triangles':0}
        elif parts[0]=='v':
            point=tuple(float(x) for x in parts[1:]);vertices.append(point);result[current]['points'].append(point)
        elif parts[0]=='f':result[current]['triangles']+=1
    for entry in result.values():entry['bounds']=[[min(p[i] for p in entry['points']) for i in range(3)],[max(p[i] for p in entry['points']) for i in range(3)]]
    return result

def clear():
    for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
    for m in list(bpy.data.materials):bpy.data.materials.remove(m)
    for im in list(bpy.data.images):bpy.data.images.remove(im)

def check(fbx,obj):
    clear();before=obj_stats(directory/obj)
    bpy.ops.import_scene.fbx(filepath=str(directory/fbx),use_anim=False)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert {o.name.replace(' ','_') for o in meshes}==set(before),({'missing':list(set(before)-{o.name.replace(' ','_') for o in meshes})[:5],'extra':list({o.name.replace(' ','_') for o in meshes}-set(before))[:5]})
    total=0;error=0
    deps=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        evaluated=o.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles();count=len(mesh.loop_triangles);total+=count
        assert count==before[o.name.replace(' ','_')]['triangles'];assert len(mesh.uv_layers)>0
        assert all(all(math.isfinite(c) for c in loop.uv) for loop in mesh.uv_layers.active.data)
        points=[o.matrix_world@v.co for v in mesh.vertices]
        bounds=[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]
        delta=max(abs(a-b) for rowa,rowb in zip(bounds,before[o.name.replace(' ','_')]['bounds']) for a,b in zip(rowa,rowb));error=max(error,delta)
        assert delta<.001,(o.name,delta)
        evaluated.to_mesh_clear()
    textures=[]
    for im in bpy.data.images:
        if im.type!='IMAGE':continue
        path=Path(bpy.path.abspath(im.filepath)).resolve()
        assert path.is_relative_to(directory.resolve()) and path.is_file(),(im.name,str(path))
        assert list(im.size)==[512,512] and len(im.pixels)==512*512*4,(im.name,list(im.size))
        textures.append(str(path.relative_to(root)))
    assert textures,(fbx,'no image dependency')
    return {'file':fbx,'meshes':len(meshes),'triangles':total,'max_cross_format_bound_error_studs':error,'textures':textures,'sha256':hashlib.sha256((directory/fbx).read_bytes()).hexdigest()}
records=[check('outpost-assembly-v1.fbx','outpost-assembly-v1.obj')]
for entry in json.loads((root/'assets/blender/military-outpost/reusable-kit.json').read_text())['assets']:records.append(check(entry['fbx'],entry['obj']))
print('P16_INDEPENDENT_FBX '+json.dumps({'passed':True,'records':records}))
