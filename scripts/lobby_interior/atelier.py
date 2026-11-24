"""Mesh, original surface and lighting tools for the editable P21 Blender assembly.

Every solid is created in studs. Mesh coordinates remain local to the object.
Repeated elements share mesh data. Review rigs live in a separate collection.
"""
from contextlib import contextmanager
from functools import lru_cache
import math
from pathlib import Path
import random
import struct
import zlib

import bpy
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/blender/lobby-interior"
EXPORT = ROOT / "assets/exports/lobby-interior"
VIEWS = ROOT / "docs/evidence/p21"
REF = ROOT / "src/images/redesigned-lobby"
P20 = ROOT / "assets/exports/lobby-bust/lobby-bust.glb"
PI = math.pi
TAU = math.tau
ctx = None
parent = None
materials = {}
C = {}
render_only = []
ceiling_objects = []
ceil_flag = False


def init():
    global ctx, parent
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for name in ("Main saloon", "Picture house", "Portrait gallery", "Approved P20 bust",
                 "Room ceilings", "Review cameras and lighting", "Placement guides"):
        col = bpy.data.collections.new(name)
        scene.collection.children.link(col)
        C[name] = col
    ctx = C["Main saloon"]
    parent = bpy.data.objects.new("Waiting Lobby | deck surface pivot", None)
    ctx.objects.link(parent)
    parent.empty_display_size = 1
    bpy.context.preferences.filepaths.save_version = 0


def section(name):
    global ctx
    ctx = C[name]


@contextmanager
def roof():
    """All ceiling elements can be hidden for the plan view with one collection toggle."""
    global ctx
    prev = ctx
    ctx = C["Room ceilings"]
    try:
        yield
    finally:
        ctx = prev


def srgb(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4


def rgb(code):
    return tuple(srgb(int(code[i:i+2], 16)/255) for i in (0, 2, 4)) + (1,)


def mat(name, code, rough=.45, metal=0, emit=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgb(code)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = m.diffuse_color
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = m.diffuse_color
        p.inputs["Emission Strength"].default_value = emit
    materials[name] = m
    return m


def image_mat(name, path, rough=.5, emission=0):
    m = mat(name, "ffffff", rough)
    im = bpy.data.images.load(str(path), check_existing=True)
    im.pack()
    texture = m.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = im
    p = m.node_tree.nodes.get("Principled BSDF")
    m.node_tree.links.new(texture.outputs["Color"], p.inputs["Base Color"])
    if emission:
        m.node_tree.links.new(texture.outputs["Color"], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = emission
    return m


def png(path, pixels):
    """Write original RGB arrays losslessly, without an external imaging dependency."""
    def chunk(key, data):
        return struct.pack(">I", len(data))+key+data+struct.pack(">I", zlib.crc32(key+data))
    h,w,_ = pixels.shape
    raw = b"".join(b"\0"+row.tobytes() for row in pixels.astype(np.uint8))
    path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,2,0,0,0))
                     +chunk(b"IDAT",zlib.compress(raw,8))+chunk(b"IEND",b""))


def surfaces(tmp):
    """Generate toroidally periodic wood, marble, terrazzo and upholstery swatches."""
    n=512
    y,x = np.mgrid[0:n,0:n]/n
    rng=np.random.default_rng(21021)
    micro=rng.normal(0,1,(n,n))
    # Compound ring curves and pores run along U; V traverses grain and growth rings.
    warp=.22*np.sin(TAU*x)+.10*np.sin(TAU*(x+2*y))+.06*np.cos(TAU*(3*x-y))
    ring=TAU*(12*y+warp+.17*np.sin(TAU*(2*y+.1*np.cos(TAU*x))))
    wood=3*np.cos(ring)+4*np.sin(ring*.0+TAU*(35*y+warp*2)) - 13*np.maximum(.0,np.cos(ring))**8
    wood+=2.4*np.sin(TAU*(85*y+.35*np.cos(TAU*2*x)))+2.1*micro+9*np.sin(TAU*(2*y+warp*.2))
    field=.5+.25*np.sin(TAU*(x+.22*np.sin(TAU*y)))+.10*np.cos(TAU*(2*y+x))
    field+=.08*np.sin(TAU*(3*x+2*y))+.036*np.sin(TAU*(6*x-3*y))+.013*np.cos(TAU*(13*y+x))
    field+=.007*np.sin(TAU*(22*x+15*y))+.003*np.cos(TAU*(37*x-19*y))
    marble=3.4*np.sin(TAU*field)+micro*1.1
    for band,strength,width in ((.33,24,.010),(.51,19,.006),(.68,13,.012),(.43,9,.003)):
        feather=np.clip(.33+.30*np.sin(TAU*(2*x+y+band))+.25*np.cos(TAU*(x-2*y-band))+.12*np.sin(TAU*7*y),.04,1)
        marble-=strength*feather*np.exp(-((field-band)/width)**2)
    plaster=2.1*np.sin(TAU*(x+2*y)) + 2.8*np.sin(TAU*(2*x-y)) + micro*1.9
    stone=rng.normal(0,4,(n,n))
    for _ in range(9500):
        i,j=rng.integers(2,n-3,2)
        col=rng.choice([-24,-12,9,14])
        stone[i:i+2,j:j+2] += col
    weave=1.8*(np.sin(TAU*x*128)+np.sin(TAU*y*171)) + micro*2.5
    samples={
       "Quarter-cut walnut": ("62402d",wood*1.3,.34),"Fumed oak":("382a24",wood*.88,.4),
       "Honed pearl marble":("deceb9",marble*.97,.205),"Parchment limestone":("dac5a4",plaster,.56),
       "Pale terrazzo":("cabcaa",stone,.29),"Petrol moquette":("28585a",weave,.79),
       "Claret velvet":("872639",weave*1.28,.65),"Bottle green hide":("245755",weave*.55,.43),
    }
    for name,(code,grain,rough) in samples.items():
        base=np.array([int(code[i:i+2],16) for i in (0,2,4)])
        pix=np.clip(base+grain[:,:,None]*np.array([1,.89,.73]),0,255)
        path=tmp/(name+".png"); png(path,pix)
        image_mat(name,path,rough)
    for name,code,r,m,e in (
        ("Champagne brass","c9a45d",.27,.74,0),("Gilt edge","e4c582",.23,.64,0),
        ("Patinated bronze","80603d",.34,.62,0),("Midnight enamel","143637",.33,.13,0),
        ("Teal silk","0c4142",.6,.06,0),("Ivory lacquer","ddcbb1",.4,.12,0),
        ("Amber alabaster","ffe5ab",.35,.06,1.8),("Opal diffuser","ffdfaa",.36,0,.55),
        ("Ebony","211d1c",.36,.05,0),("Deep shadow","151f23",.36,.08,0),
        ("Mortar","a89783",.53,0,0),("Gilt silk","c8a670",.51,.12,0),
        ("Palm forest","264b2d",.55,0,0),("Palm olive","55723a",.56,0,0),
        ("Palm jade","396741",.5,0,0),("Soil","30271e",.98,0,0),
        ("Bordeaux piping","a35551",.57,0,0),("Aisle light","ffd089",.31,0,2.5),
        ("Fine bronze","91794d",.35,.4,0),("Paper","e6d7b3",.83,0,0),
    ): mat(name,code,r,m,e)


def attach(name, data, loc=(0,0,0), rot=0, col=None):
    obj=bpy.data.objects.new(name,data)
    (col or ctx).objects.link(obj)
    obj.location=loc
    if isinstance(rot,(int,float)): obj.rotation_euler.z=rot
    else: obj.rotation_euler=rot
    if (col or ctx) not in (C["Review cameras and lighting"], C["Placement guides"]):
        obj.parent=parent
    return obj


def make_mesh(name, verts, faces, material, uv=None, smooth=False):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(materials[material])
    mesh.update()
    layer=mesh.uv_layers.new(name="UVMap")
    for f in mesh.polygons:
        f.use_smooth=smooth
        major=max(range(3),key=lambda i:abs(f.normal[i]))
        for k in f.loop_indices:
            idx=mesh.loops[k].vertex_index
            if uv is not None:
                t=uv[idx]
            else:
                p=verts[idx]
                # Grain follows long horizontals on horizontal boards and the Z axis on uprights.
                if major==2: t=(p[0]/12,p[1]/12)
                elif major==1:t=(p[0]/12,p[2]/12)
                else:t=(p[1]/12,p[2]/12)
            layer.data[k].uv=t
    return mesh


@lru_cache(maxsize=None)
def box_mesh(w,d,h,material,bevel):
    verts=[(x*w/2,y*d/2,z*h/2) for z in (-1,1) for y in (-1,1) for x in (-1,1)]
    faces=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)]
    m=make_mesh("Block | "+material,verts,faces,material)
    if material in ("Quarter-cut walnut","Fumed oak") and h>max(w,d)*1.5:
        layer=m.uv_layers.active
        for loop in layer.data:
            u,v=loop.uv; loop.uv=(v,u)
    # Bake shared bevel geometry just once per furniture profile.
    if bevel:
        import bmesh
        bm=bmesh.new(); bm.from_mesh(m)
        bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(bevel,w*.41,d*.41,h*.41),segments=3,affect="EDGES",
                        profile=.5,clamp_overlap=True)
        bm.to_mesh(m); bm.free(); m.update()
    return m


def box(name,loc,size,material,bevel=.025,rot=0):
    return attach(name,box_mesh(*(round(float(z),5) for z in size),material,bevel),loc,rot)


@lru_cache(maxsize=None)
def turned_mesh(profile,material,sides):
    verts=[(r*math.cos(TAU*i/sides),r*math.sin(TAU*i/sides),z) for r,z in profile for i in range(sides)]
    faces=[tuple(range(sides-1,-1,-1))]
    for j in range(len(profile)-1):
        for i in range(sides):
            k=j*sides+i; n=j*sides+(i+1)%sides
            faces.append((k,n,n+sides,k+sides))
    top=(len(profile)-1)*sides
    faces.append(tuple(top+i for i in range(sides)))
    m=make_mesh("Turned | "+material,verts,faces,material)
    for f in list(m.polygons)[1:-1]: f.use_smooth=True
    return m


def turned(name,loc,profile,material,sides=48):
    return attach(name,turned_mesh(tuple(tuple(row) for row in profile),material,sides),loc)


def rim(name,loc,radius,thickness,height,material,sides=96):
    """An open annular channel with a visible inner return and no disk over its diffuser."""
    key=f"Ring | {radius:.3f}/{thickness:.3f}/{height:.3f} {material}"
    m=bpy.data.meshes.get(key)
    if not m:
        verts=[]; faces=[]
        for r,z in ((radius-thickness,0),(radius,0),(radius,height),(radius-thickness,height)):
            for i in range(sides):
                t=TAU*i/sides; verts.append((r*math.cos(t),r*math.sin(t),z))
        for row in range(4):
            for i in range(sides):
                j=(i+1)%sides;k=((row+1)%4)*sides;b=row*sides
                faces.append((b+i,b+j,k+j,k+i))
        m=make_mesh(key,verts,faces,material)
        for poly in m.polygons:
            if poly.index//sides in (1,3):poly.use_smooth=True
    return attach(name,m,loc)


def rod(name,a,b,r,material,sides=12,r2=None):
    a,b=Vector(a),Vector(b)
    axis=b-a
    o=turned(name,a,[(r,0),(r if r2 is None else r2,round(axis.length,5))],material,sides)
    o.rotation_euler=axis.to_track_quat('Z','Y').to_euler()
    return o


def panel(name,verts,material,faces=None,uv=None):
    return attach(name,make_mesh(name,verts,faces or [tuple(range(len(verts)))],material,uv))


def frame(name,x,y,z,w,h,depth,width,material,angle=0):
    for pos, dims in [((0,(h-width)/2),(w,depth,width)),((0,-(h-width)/2),(w,depth,width)),
                      (((w-width)/2,0),(width,depth,h-width*2)),((-(w-width)/2,0),(width,depth,h-width*2))]:
        u,v=pos
        box(name,(x+math.cos(angle)*u,y+math.sin(angle)*u,z+v),dims,material,min(width/4,.055),angle)


def textmesh(name,body,location,size,material,width,angle=0):
    """Use Blender's bundled font; retain the actual extruded outlines in the export."""
    cr=bpy.data.curves.new(name,'FONT'); cr.body=body; cr.align_x='CENTER'; cr.align_y='CENTER'
    cr.size=size; cr.space_character=1.02; cr.extrude=.013; cr.bevel_depth=.006; cr.bevel_resolution=2
    cr.materials.append(materials[material])
    ob=attach(name,cr,location,(PI/2,0,angle))
    bpy.context.view_layer.update()
    # Bounding box here is in font-local coordinates.
    span=max(v[0] for v in ob.bound_box)-min(v[0] for v in ob.bound_box)
    uniform=min(1,width/span)
    ob.scale=(uniform,uniform,uniform)
    dg=bpy.context.evaluated_depsgraph_get()
    m=bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    repl=attach(name+" | raised letters",m,location,(PI/2,0,angle))
    repl.scale=ob.scale
    bpy.data.objects.remove(ob,do_unlink=True)
    return repl


def light(name,loc,target,power,size,tint=(1,.88,.7),shape='DISK',size_y=None):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape=shape;data.size=size;data.color=tint
    if shape=='RECTANGLE': data.size_y=size if size_y is None else size_y
    ob=attach(name,data,loc,col=C["Review cameras and lighting"])
    ob.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    return ob


def camera(name,loc,target,lens,res,orthoscale=0):
    data=bpy.data.cameras.new(name); data.lens=lens;data.clip_start=.12;data.clip_end=500
    if orthoscale: data.type='ORTHO';data.ortho_scale=orthoscale
    ob=attach(name,data,loc,col=C["Review cameras and lighting"])
    ob.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    ob["image_size"]=list(res)
    return ob


def local(wall,along,forward,z):
    """wall is (origin X,origin Y,angle). Positive forward faces into the room."""
    x,y,a=wall
    return (x+along*math.cos(a)+forward*math.sin(a),y+along*math.sin(a)-forward*math.cos(a),z)


def wall_box(wall,name,u,n,z,sz,material,bevel=.025):
    return box(name,local(wall,u,n,z),sz,material,bevel,wall[2])
