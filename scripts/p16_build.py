"""Author P16's original editable outpost and portable, baked-material exports.

Run with Blender 5.3 background/factory startup. Units are studs, Z-up and -Y
front. No network or existing Blender documents are touched. Rebuild replaces
only this package's named outputs. Review renders are produced by the separate
clean-reopen script, never by an unsaved in-memory authoring scene.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector, Matrix
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/military-outpost'
EXPORT = ROOT / 'assets/exports/military-outpost'
RNG = random.Random(1601)
MATS = {}
CURRENT = None
ASSETS = []
GROUP_COUNTERS = {}
PANEL_CATALOG = []
BUDGETS = dict(assembly_triangles=250000, package_triangles=400000,
               materials=18, textures=12, decoded_texture_bytes=16*1024*1024,
               single_file_bytes=20*1024*1024, package_bytes=45*1024*1024)


def collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def own(obj, name, mat=None, asset=None):
    obj.name = name
    for c in list(obj.users_collection): c.objects.unlink(obj)
    CURRENT.objects.link(obj)
    if mat: obj.data.materials.append(MATS[mat])
    if asset: obj['asset_category'] = asset
    return obj


def uv_box(obj):
    """Give every mesh a deterministic, meter-independent projected UV layer."""
    mesh = obj.data
    if not mesh.uv_layers: mesh.uv_layers.new(name='UVMap')
    layer = mesh.uv_layers.active
    for poly in mesh.polygons:
        axis = max(range(3), key=lambda i: abs(poly.normal[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            if obj.data.materials and obj.data.materials[0].name in ('screen','tactical'):
                extent=[max(abs(v.co[i]) for v in mesh.vertices)*2 for i in range(3)]
                layer.data[li].uv=(co[a]/max(extent[a],.001)+.5,co[b]/max(extent[b],.001)+.5)
            else:layer.data[li].uv = (co[a] / 4 + .5, co[b] / 4 + .5)


def cube(name, pos, size, mat='steel', bevel=.04, asset=None):
    x,y,z=(v/2 for v in size)
    vs=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    fs=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    o=mesh(name,vs,fs,mat);o.location=pos
    if asset:o['asset_category']=asset
    if bevel:
        mod=o.modifiers.new('Manufactured edge','BEVEL');mod.width=bevel;mod.segments=1
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o


def cyl(name, pos, radius, depth, mat='steel', rotation=(0,0,0), vertices=12, asset=None):
    vs=[(radius*math.cos(i*2*math.pi/vertices),radius*math.sin(i*2*math.pi/vertices),z)
        for z in (-depth/2,depth/2) for i in range(vertices)]
    fs=[tuple(reversed(range(vertices))),tuple(range(vertices,2*vertices))]
    fs.extend((i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices))
    o=mesh(name,vs,fs,mat);o.location=pos;o.rotation_euler=rotation
    if asset:o['asset_category']=asset
    return o


def rod(name, a, b, radius=.04, mat='steel', vertices=8):
    a,b=Vector(a),Vector(b)
    o=cyl(name,(a+b)/2,radius,(b-a).length,mat,vertices=vertices)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o


def text(name, body, pos, size=.45, mat='ivory', rotation=(math.pi/2,0,0)):
    cu=bpy.data.curves.new(name,'FONT'); cu.body=body;cu.size=size;cu.extrude=.003
    o=bpy.data.objects.new(name,cu); CURRENT.objects.link(o);o.location=pos;o.rotation_euler=rotation
    cu.materials.append(MATS[mat]);return o


def mesh(name, verts, faces, mat):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);CURRENT.objects.link(o);o.data.materials.append(MATS[mat]);uv_box(o);return o


def slab_polygon(name, points, depth, mat, y=0):
    n=len(points); vs=[(x,y-depth/2,z) for x,z in points]+[(x,y+depth/2,z) for x,z in points]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(name,vs,fs,mat)


def texture(name, color, kind):
    """Bake original color weathering/graphics to PNG; no render-only noise nodes."""
    n=512; yy,xx=np.mgrid[0:n,0:n]; rng=np.random.default_rng(1600+len(MATS))
    coarse=np.zeros((n,n))
    for octave in range(14):
        fx,fy=rng.uniform(.025,.6,2);phase=rng.uniform(0,math.tau)
        coarse+=np.sin(xx*fx+yy*fy+phase)*.0025
    grain=rng.random((n,n))*.035-.0175
    arr=np.empty((n,n,4),dtype=np.float32)
    for c in range(3):arr[:,:,c]=np.clip(color[c]+coarse+grain,0,1)
    arr[:,:,3]=1
    if kind=='concrete':
        # Irregular low-contrast grime/spalls, never earned combat cracks.
        for stain in range(30):
            x0,y0=rng.integers(0,n,2);rx,ry=rng.integers(4,24,2)
            patch=((xx-x0)/rx)**2+((yy-y0)/ry)**2<1
            irregular=patch & (rng.random((n,n))>.23)
            arr[irregular,:3]*=rng.uniform(.7,.9)
        pits=rng.random((n,n))>.984
        arr[pits,:3]*=.38
        for k in range(18):
            x0=rng.integers(n); y0=rng.integers(n)
            spot=(xx-x0)**2+(yy-y0)**2<rng.integers(2,16)**2
            arr[spot,:3]*=.83
    elif kind=='metal':
        rib=(np.cos(xx*math.pi/16)*.035)[:,:,None];arr[:,:,:3]+=rib
        rust=(rng.random((n,n))>.97)&(np.sin(xx*.04+yy*.017)>.25)
        arr[rust,:3]=(.21,.105,.045)
        for chip in range(48):
            x0,y0=rng.integers(0,n,2);rx,ry=rng.integers(3,13,2)
            chipped=((xx-x0)/rx)**2+((yy-y0)/ry)**2<1
            chipped &= rng.random((n,n))>.22
            arr[chipped,:3]=(.34,.32,.27) if chip%3 else (.22,.105,.045)
            streak=(abs(xx-x0)<max(1,rx//4))&(yy<y0)&(yy>y0-rng.integers(8,50))
            arr[streak,:3]*=.65
        arr[:,::64,:3]*=.65
    elif kind in ('screen','tactical'):
        arr[:,:,:3]=(.012,.055,.11)
        grid=(xx%32==0)|(yy%32==0);arr[grid,:3]=(.025,.15,.23)
        rad=np.sqrt((xx-256)**2+(yy-256)**2)
        rings=((rad%52)<2)&(rad<210)
        arr[rings,:3]=(.08,.58,.85)
        if kind=='tactical':
            topo=np.sin(xx*.026+yy*.009)*55+np.cos(yy*.021)*30
            lines=np.abs((yy-256+topo)%31)<1.5;arr[lines,:3]=(.06,.34,.49)
        else:
            sweep=(yy>256)&(np.abs((xx-256)-.6*(yy-256))<2);arr[sweep,:3]=(.15,.8,.95)
            for i in range(12):arr[30+i*6:32+i*6,20:90+i*3,:3]=(.08,.3,.46)
        for i in range(20):
            x0=int(rng.integers(80,430));y0=int(rng.integers(80,430));arr[y0-2:y0+2,x0-2:x0+2,:3]=(.3,.9,1)
    elif kind=='roof':
        arr[yy%128<3,:3]*=.55
        arr[(xx+64*(yy//128))%128<2,:3]*=.6
    image=bpy.data.images.new(name, width=n,height=n, alpha=True)
    image.pixels.foreach_set(np.clip(arr,0,1).ravel())
    image.filepath_raw=str(EXPORT/'textures'/f'{name}.png');image.file_format='PNG';image.save();image.pack()
    return image


def material(name, color, kind='plain', metallic=0, rough=.65, emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=rough
    image=texture(name,color,kind);node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
    m.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
    if emission:
        m.node_tree.links.new(node.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=emission
    MATS[name]=m;return m


def case(name, pos, size=(2.5,1.7,1.5), mat='olive'):
    x,y,z=pos;w,d,h=size
    cube(name+'.body',(x,y,z+h/2),(w,d,h),mat,.09,asset='sealed_case')
    cube(name+'.lid',(x,y,z+h*.78),(w+.04,d+.04,.12),'steel',.02)
    for dx in (-w*.32,w*.32):
        cube(name+'.strap',(x+dx,y,z+h/2),(.09,d+.09,h+.08),'steel',.01)
        cube(name+'.latch',(x+dx,y-d/2-.06,z+h*.58),(.22,.1,.3),'ivory',.02)
    cube(name+'.handle',(x,y-d/2-.08,z+h*.48),(.65,.12,.18),'dark',.03)
    cube(name+'.label',(x+w*.15,y-d/2-.065,z+h*.27),(.5,.025,.18),'ivory',.005)


def pallet(name,pos,w=3.6,d=2.4):
    x,y,z=pos
    for dx in (-w*.38,0,w*.38):cube(name+'.runner',(x+dx,y,z+.12),(.22,d,.24),'wood',.025)
    for j in range(5):cube(name+'.board',(x,y-d/2+d*(j+.5)/5,z+.3),(w,d/6,.12),'wood',.02)


def rack(name,pos, levels=3, boxes=True):
    x,y,z=pos;w,d,h=5.3,2.3,7.1
    for dx in (-w/2,w/2):
        for dy in (-d/2,d/2):
            cube(name+'.upright',(x+dx,y+dy,z+h/2),(.13,.13,h),'steel',.015,asset='storage_rack')
            for k in range(14):cube(name+'.slot',(x+dx,y+dy-.075,z+.3+k*.45),(.06,.015,.11),'dark',0)
    for k in range(levels):
        zz=z+.35+k*2.5
        cube(name+'.shelf',(x,y,zz),(w+.15,d,.14),'orange',.02)
        for dy in (-d/2,d/2):rod(name+'.brace',(x-w/2,y+dy,zz),(x+w/2,y+dy,zz+2.3),.035)
        if boxes:
            for dx in (-1.35,1.35):case(name+'.case',(x+dx,y,zz+.1),(2.4,1.8,1.6))


def light(name,pos,rotation=(0,0,0),power=100):
    o=cube(name+'.housing',pos,(2.8,.85,.22),'steel',.07,asset='utility_lamp');o.rotation_euler=rotation
    face=cube(name+'.diffuser',(pos[0],pos[1],pos[2]-.13),(2.5,.65,.04),'lamp',.015);face.rotation_euler=rotation
    data=bpy.data.lights.new(name,'AREA');data.energy=power*9;data.shape='RECTANGLE';data.size=2.5;data.size_y=.7
    l=bpy.data.objects.new(name+'.illumination',data);CURRENT.objects.link(l);l.location=(pos[0],pos[1],pos[2]-.2)


def louver(name,pos,size=(3,1,2.8),rotation=0):
    x,y,z=pos;w,d,h=size
    a=cube(name+'.cabinet',pos,size,'ivory',.08,asset='louver_vent');a.rotation_euler[2]=rotation
    for i in range(9):
        a=cube(name+'.slat',(x,y-d/2-.03,z-h*.4+i*h*.1),(w*.86,.15,.09),'dark',.01);a.rotation_euler[2]=rotation


def desk(name,pos,count=2):
    x,y,z=pos
    cube(name+'.top',(x,y,z+2.1),(7,2.2,.2),'steel',.08,asset='command_console')
    for dx in (-2.8,2.8):
        cube(name+'.cabinet',(x+dx,y,z+1),(1.2,2,2),'steel',.04)
        for k in range(3):
            cube(name+'.drawer',(x+dx,y-1.03,z+.45+k*.55),(1.05,.08,.42),'ivory',.015)
            cube(name+'.pull',(x+dx,y-1.09,z+.45+k*.55),(.4,.07,.055),'dark',.01)
    for i in range(count):
        xx=x+(i-(count-1)/2)*2.9
        cube(name+'.monitor',(xx,y+.4,z+3.35),(2.5,.22,1.75),'dark',.07,asset='monitor')
        cube(name+'.screen',(xx,y+.271,z+3.35),(2.24,.025,1.47),'screen',.01)
        cube(name+'.neck',(xx,y+.4,z+2.45),(.15,.2,.7),'steel',.01)
        cube(name+'.foot',(xx,y+.3,z+2.25),(1,.55,.06),'steel',.02)
        cube(name+'.keyboard',(xx,y-.5,z+2.27),(1.65,.5,.09),'dark',.02)
        for row in range(3):
            for col in range(10):cube(name+'.key',(xx-.7+col*.15,y-.68+row*.14,z+2.33),(.1,.08,.025),'ivory',0)
        for k in range(4):cube(name+'.switch',(xx-1+k*.2,y-.9,z+2.28),(.1,.09,.04),'orange',0)


def chair(name,pos):
    x,y,z=pos
    cube(name+'.seat',(x,y,z+1.6),(1.7,1.6,.3),'dark',.12,asset='operator_chair')
    cube(name+'.back',(x,y-.7,z+2.65),(1.65,.23,1.8),'dark',.12)
    cyl(name+'.stem',(x,y,z+.8),.11,1.5)
    for k in range(5):
        a=k*2*math.pi/5;xx=x+.85*math.cos(a);yy=y+.85*math.sin(a)
        rod(name+'.spoke',(x,y,z+.2),(xx,yy,z+.15),.06)
        cyl(name+'.wheel',(xx,yy,z+.14),.13,.15,'dark',rotation=(math.pi/2,0,0))
    for s in (-1,1):
        rod(name+'.arm',(x+s*.9,y,z+1.7),(x+s*.9,y,z+2.15),.06)
        cube(name+'.armrest',(x+s*.9,y,z+2.15),(.16,1.1,.13),'dark',.04)


def service(name,z):
    for x in ((-2,11) if z<10 else (-12,11)):
        cube(name+'.duct',(x,0,z),(1,42,.75),'steel',.03,asset='duct')
        for y in range(-20,21,4):
            cube(name+'.duct_seam',(x,y,z),(1.06,.08,.8),'ivory',.01)
        for dx in (-.45,.45):rod(name+'.cable_tray_rail',(x+3+dx,-21,z-.4),(x+3+dx,21,z-.4),.045)
        for y in range(-21,22):cube(name+'.tray_rung',(x+3,y,z-.42),(1,.06,.05),'steel',0)
        for dx in (0,.22):rod(name+'.conduit',(x+1.4+dx,-22,z-.2),(x+1.4+dx,22,z-.2),.055,'orange')


def original_rects(w,h,shape):
    if shape=='window':
        return [(-w/2,-h/2,-4,h/2),(4,-h/2,w/2,h/2),(-4,-h/2,4,-1),(-4,3,4,h/2)]
    if shape in ('door','garage'):
        hole=3 if shape=='door' else 6
        return [(-w/2,-h/2,-hole,h/2),(hole,-h/2,w/2,h/2),(-hole,3,hole,h/2)]
    return [(-w/2,-h/2,w/2,h/2)]


def area(rects):return sum((x1-x0)*(z1-z0) for x0,z0,x1,z1 in rects)


def heavy_rects(rects,w,h):
    """Cut half of the ORIGINAL blocking area, including door/window apertures.

    Eight material-dependent serrated rows retain side islands. Binary search
    solves actual rectangle union area rather than assuming a solid rectangle.
    Each returned solid also has a matching explicit collision proxy.
    """
    rows=16; result=[]
    offsets=[.0,.4,-.3,.1,-.2,.35,-.35,0]*2
    def clip(cut):
        out=[]
        for row in range(rows):
            lo=-h/2+h*row/rows;hi=lo+h/rows
            edge=max(.05,cut+offsets[row])
            for x0,z0,x1,z1 in rects:
                z0=max(z0,lo);z1=min(z1,hi)
                if z1<=z0:continue
                for a,b in ((x0,min(x1,-edge)),(max(x0,edge),x1)):
                    if b>a:out.append((a,z0,b,z1))
        return out
    lo,hi=0,w/2
    for _ in range(50):
        mid=(lo+hi)/2
        if area(clip(mid))>area(rects)*.5:lo=mid
        else:hi=mid
    return clip((lo+hi)/2)


def make_panel(name,w,h,t,family,shape,state):
    """Panel local coordinates: face X/Z, thickness Y; origin center/pivot."""
    base=original_rects(w,h,shape);rects=heavy_rects(base,w,h) if state=='Heavy' else base
    if state=='Total':rects=[]
    objs=[]
    mat={'corrugated':'teal','concrete':'concrete','roof':'roof'}[family]
    for i,(x0,z0,x1,z1) in enumerate(rects):
        if family=='roof':
            layers=[(-.34,.32,'concrete'),(.01,.36,'ivory'),(.35,.3,'roof')]
            for yy,dt,mm in layers:objs.append(cube(f'{name}.layer{i}.{mm}',((x0+x1)/2,yy,(z0+z1)/2),(x1-x0,dt,z1-z0),mm,0))
        else:
            objs.append(cube(f'{name}.solid{i}',((x0+x1)/2,0,(z0+z1)/2),(x1-x0,t,z1-z0),mat,0))
    # Corrugations are clipped to the surviving silhouette, on both faces.
    if family=='corrugated':
        for side in (-1,1):
            for i,(x0,z0,x1,z1) in enumerate(rects):
                start=math.ceil(x0/.5)
                for rib in range(start,math.floor(x1/.5)+1):
                    xx=rib*.5
                    if xx-.035<x0 or xx+.035>x1:continue
                    objs.append(cube(f'{name}.rib', (xx,side*(t/2+.04),(z0+z1)/2),(.07,.08,z1-z0),mat,0))
                # Reference orange identification stripe; restricted to original panels.
                low=max(z0,-2.6);high=min(z1,-1.8)
                if high>low:objs.append(cube(f'{name}.stripe',((x0+x1)/2,side*(t/2+.09),(low+high)/2),(x1-x0,.025,high-low),'orange',0))
    if state=='Light':
        # Material-specific positive earned damage. Both faces; never opens cover.
        for side in (-1,1):
            for k in range(9):
                xx=-w*.38+k*w*.09;zz=math.sin(k*2.1)*h*.25
                if not any(a+1<=xx<=c-1 and b+1<=zz<=d-1 for a,b,c,d in base):continue
                if family=='corrugated':
                    scar=cube(name+'.light_scored_crease',(xx,side*(t/2+.16),zz),(.08,.025,1.2),'dark',0);scar.rotation_euler[1]=.5
                    objs.append(scar)
                    objs.append(cube(name+'.light_exposed_metal',(xx+.09,side*(t/2+.17),zz),(.045,.025,1.15),'ivory',0))
                elif family=='concrete':
                    pts=[(xx-.4,zz+.4),(xx,zz),(xx+.16,zz-.55),(xx+.65,zz-.8)]
                    for a,b in zip(pts,pts[1:]):objs.append(rod(name+'.light_branch_crack',(a[0],side*.52,a[1]),(b[0],side*.52,b[1]),.035,'dark',6))
                else:
                    objs.append(cube(name+'.light_split_seam',(xx,side*.52,zz),(.12,.035,2),'dark',0))
                    objs.append(cube(name+'.light_spall',(xx+.15,side*.54,zz-.3),(.28,.04,.4),'concrete',0))
    if state=='Heavy':
        # Fractured end-grain / folded sheet lips / exposed rebar are silhouettes,
        # distinct by construction and limited to retained row solids.
        for side in (-1,1):
            for i,(a,b,c,d) in enumerate(rects):
                edge=c if c<0 else a
                if abs(edge)>=w*.49:continue
                if family=='corrugated':
                    lip=cube(name+'.heavy_bent_sheet',(edge+(-.10 if c<0 else .10),side*(t/2+.16),(b+d)/2),(.14,.4,d-b),'ivory',0)
                    lip.rotation_euler[2]=(-.5 if c<0 else .5)*side;objs.append(lip)
                elif family=='concrete':
                    points=[(edge,b),(edge+(-.18 if c<0 else .18),b+.12),(edge,d)]
                    objs.append(slab_polygon(name+'.heavy_aggregate',points,t+.04,'ivory'))
                else:
                    objs.append(rod(name+'.heavy_exposed_rebar',(edge+(-.2 if c<0 else .2),side*.54,b+.05),(edge+(-.2 if c<0 else .2),side*.54,d-.05),.035,'steel'))
    return objs,base,rects


def join_meshes(objects,name):
    if not objects:return None
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join();o=bpy.context.object;o.name=name
    # Exporters require unique material slots on shared mesh data.
    materials=list(o.data.materials); unique=[]; remap={}
    for i,m in enumerate(materials):
        if m not in unique:unique.append(m)
        remap[i]=unique.index(m)
    indices=[remap[p.material_index] for p in o.data.polygons]
    o.data.materials.clear()
    for m in unique:o.data.materials.append(m)
    for p,i in zip(o.data.polygons,indices):p.material_index=i
    # Move data to a true center origin without shifting geometry.
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return o


def obj_export(path, objects):
    """Portable triangulated OBJ with explicit UV and material names; no bpy importer."""
    bpy.context.view_layer.update()
    lines=['# P16 original authoring; units studs, Z up, front -Y','mtllib materials.mtl'];vi=1;ti=1
    deps=bpy.context.evaluated_depsgraph_get()
    for o in objects:
        if o.type!='MESH':continue
        eo=o.evaluated_get(deps);me=eo.to_mesh();me.calc_loop_triangles()
        lines.append('o '+o.name.replace(' ','_'))
        for v in me.vertices:
            p=Matrix.LocRotScale(o.location,o.rotation_euler.to_quaternion(),o.scale)@v.co;lines.append('v %.7g %.7g %.7g'%tuple(p))
        uv=me.uv_layers.active
        for loop in me.loops:
            x,y=uv.data[loop.index].uv if uv else (0,0);lines.append('vt %.7g %.7g'%(x,y))
        last=None
        for tri in me.loop_triangles:
            ma=me.materials[tri.material_index].name if me.materials else 'steel'
            if ma!=last:lines.append('usemtl '+ma);last=ma
            lines.append('f '+' '.join(f'{vi+v}/{ti+l}' for v,l in zip(tri.vertices,tri.loops)))
        vi+=len(me.vertices);ti+=len(me.loops);eo.to_mesh_clear()
    path.write_text('\n'.join(lines)+'\n')


def export_fbx(path,objects):
    visibility={c.name:c.hide_viewport for c in bpy.context.scene.collection.children}
    object_visibility={o.name:o.hide_get() for o in objects}
    for c in bpy.context.scene.collection.children:c.hide_viewport=False
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        if o.type=='MESH':o.hide_set(False);o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},
        apply_unit_scale=True,axis_forward='-Z',axis_up='Y',use_mesh_modifiers=True,
        mesh_smooth_type='FACE',add_leaf_bones=False,path_mode='RELATIVE',bake_anim=False)
    for c in bpy.context.scene.collection.children:c.hide_viewport=visibility[c.name]
    for o in objects:o.hide_set(object_visibility[o.name])


def build_damage():
    global CURRENT
    col=collection('06_Damage_Gallery');CURRENT=col
    specs=[('corrugated_wall','corrugated','solid',16,8,1),
           ('corrugated_window','corrugated','window',16,8,1),
           ('corrugated_door','corrugated','door',16,8,1),
           ('corrugated_garage','corrugated','garage',16,8,1),
           ('concrete_partition','concrete','solid',16,8,1),
           ('layered_roof','roof','solid',16,16,1)]
    library=collection('07_Panel_Library');library.hide_render=True
    proxies=collection('08_Collision_Proxies');proxies.hide_render=True;proxies.hide_viewport=True
    templates={}
    all_library=[]
    for family_index,(key,mat,shape,w,h,t) in enumerate(specs):
        entry=dict(id=key,material=mat,shape=shape,dimensions_studs=[w,t,h],pivot=[0,0,0],
                   source_collection='07_Panel_Library',states={},fragments=[],fragment_cap=4)
        for state_index,state in enumerate(('Pristine','Light','Heavy','Total')):
            CURRENT=library
            objs,base,rects=make_panel(key+'.'+state,w,h,t,mat,shape,state)
            o=join_meshes(objs,key+'.'+state)
            if o:templates[(key,state)]=o;all_library.append(o)
            objpath=f'{key}-{state.lower()}.obj';obj_export(EXPORT/objpath,[o] if o else [])
            CURRENT=proxies; ps=[]
            for i,(a,b,c,d) in enumerate(rects):ps.append(cube(key+'.'+state+'.proxy'+str(i),((a+c)/2,0,(b+d)/2),(c-a,t,d-b),'dark',0))
            proxpath=f'{key}-{state.lower()}-collision.obj';obj_export(EXPORT/proxpath,ps)
            all_library.extend(ps)
            entry['states'][state]=dict(mesh=objpath,collision=proxpath,source_object=o.name if o else None,
                rectangles=[list(r) for r in rects],blocking_area=area(rects),pristine_blocking_area=area(base),
                removed_fraction=1-area(rects)/area(base),object_count=1 if o else 0)
            # A pristine support surround, labels and the state itself remain in Total.
            CURRENT=col; gx=state_index*20;gy=family_index*22
            if o:
                cp=o.copy();cp.data=o.data;col.objects.link(cp);cp.name=f'Gallery.{key}.{state}';cp.location=(gx,gy,h/2+1)
            for x in (gx-w/2-.35,gx+w/2+.35):cube('Gallery stable edge',(x,gy,h/2+1),(.3,1,h+1),'steel',0)
            cube('Gallery plinth',(gx,gy,.25),(18,3,.5),'concrete',.04)
            for side in (-1,1):
                cube('Gallery caption card',(gx,gy+side*1.75,-1),(18,.12,2.4),'ivory',.025)
                rotation=(math.pi/2,0,0 if side<0 else math.pi)
                state_label=text('Gallery state label',state.upper(),(gx,gy+side*1.83,-.9),1.15,'dark',rotation)
                state_label.data.align_x='CENTER'
                family_label=text('Gallery family label',key.replace('_',' ').upper(),(gx,gy+side*1.83,-1.8),.52,'dark',rotation)
                family_label.data.align_x='CENTER'
        CURRENT=library
        for i in range(4):
            if mat=='corrugated':
                points=[(-.6,-.4),(.5,-.35),(.65,.4),(-.45,.55)]
                f=slab_polygon(key+'.fragment'+str(i),points,.12,'teal')
                # Original bent shard: noncoplanar front/back vertices.
                for v in f.data.vertices:
                    if v.co.x>.2:v.co.y+=.2*(v.co.x-.2)
            elif mat=='concrete':
                points=[(-.55,-.45),(.48,-.4),(.6,.32),(.05,.58),(-.5,.3)]
                f=slab_polygon(key+'.fragment'+str(i),points,.6,'concrete')
            else:
                f=cube(key+'.fragment'+str(i),(0,0,0),(1.2,.7,.9),'roof',0)
            fp=f'{key}-fragment-{i+1}.obj';obj_export(EXPORT/fp,[f]);all_library.append(f)
            entry['fragments'].append(dict(mesh=fp,source_object=f.name,max_dimensions_studs=[1.5,1.5,1.5]))
            CURRENT=col;cp=f.copy();cp.data=f.data;col.objects.link(cp);cp.name='Gallery.'+f.name;cp.location=(61+i*1.6,family_index*22-2,1)
            CURRENT=library
        PANEL_CATALOG.append(entry)
    # Library objects remain isolated at origin; only gallery duplicates render.
    export_fbx(EXPORT/'panel-library-v1.fbx',all_library)
    library.hide_viewport=True
    for o in all_library:o.hide_set(True)
    return templates


def instance_panel(templates,key,state,name,loc,rz=0,roof=False):
    source=templates[(key,state)]
    cp=source.copy();cp.data=source.data.copy();CURRENT.objects.link(cp);cp.name=name;cp.location=loc
    cp.hide_set(False)
    if roof:cp.rotation_euler[0]=math.pi/2
    cp.rotation_euler[2]=rz
    cp['panel_family']=key;cp['panel_state']=state;cp['stable_panel_id']=name
    return cp


def build_structure(templates):
    global CURRENT
    CURRENT=collection('01_Stable_Structure')
    cube('Foundation',(0,0,-.375),(32,48,1),'concrete',.07,asset='foundation')
    # Retain current main upper floor and the west internal stairwell/landings.
    cube('Upper_Main',(5.5,0,9.625),(19,46,1),'concrete',.04,asset='usable_upper_floor')
    cube('Upper_North_Landing',(-9.5,20.5,9.625),(11,5,1),'concrete',.04)
    cube('Upper_South_Rim',(-9.5,-20.5,9.625),(11,5,1),'concrete',.04)
    for x in (-16,0,16):
        for y in (-24,0,24):
            if x==0 and y==0:continue
            cube('Concrete pier',(x,y,10.0625),(1.6,1.6,20.125),'concrete',.1,asset='support_column')
            cube('Pier foot',(x,y,.75),(2.4,2.4,1.5),'concrete',.1)
            for z in (8.8,18.8):
                cube('Concrete haunch',(x,y,z),(2.4,2.4,1.1),'concrete',.1)
                cube('Steel pier plate',(x,y-.86,z),(1.1,.08,.65),'steel',.025)
                for dx in (-.32,.32):cyl('Anchor bolt',(x+dx,y-.94,z),.065,.09,'ivory',rotation=(math.pi/2,0,0),vertices=6)
    for z in (9.125,19.125):
        for x in (-16,16):cube('Perimeter long beam',(x,0,z),(2,46,2),'concrete',.08,asset='stable_beam')
        for y in (-24,0,24):
            if y==0 and z<10:
                # The west stairwell must remain open through the upper floor.
                cube('Cross beam stairwell return',(5.5,y,z),(19,1.5,2),'concrete',.08)
            else:cube('Cross beam',(0,y,z),(30,1.5,2),'concrete',.08)
    for k in range(16):
        height=(k+1)*.625; y=-15+2*k
        cube('Internal stair tread '+str(k+1),(-10,y,.125+height/2),(8,2,height),'concrete',.025,asset='internal_stair')
        cube('Tread nosing',(-10,y-.9,.125+height+.02),(7.8,.16,.04),'orange',0)
    cube('Internal top landing',(-10,17,9.625),(8,2,1),'concrete',.04,asset='usable_upper_floor')
    cube('Upper balcony threshold',(16,16,9.625),(3,6,1),'concrete',.04,asset='usable_upper_floor')
    for x in (-14,-6):
        for y,z in ((-15,2),(1,7),(15,12)):
            rod('Stair baluster',(x,y,z-2),(x,y,z+.5),.055)
        rod('Internal handrail',(x,-16,2.2),(x,17,12.2),.07)
    for y in range(-16,18,4):rod('Upper stairwell guardrail post',(-4,y,10.125),(-4,y,12.9),.055)
    for z in (11.4,12.9):rod('Upper stairwell guardrail',(-4,-17,z),(-4,17,z),.06)
    for y in (-23.5,23.5):cube('Roof parapet',(0,y,21.4),(32,1,1.5),'concrete',.07,asset='parapet')
    for x in (-15.5,15.5):cube('Roof parapet',(x,0,21.4),(1,46,1.5),'concrete',.07)
    CURRENT=collection('02_Destructible_Panels')
    world=json.loads((ROOT/'assets/world/Battlefield.model.json').read_text())
    def find(n,name):
        if n.get('Name')==name:return n
        for c in n.get('Children',[]):
            r=find(c,name)
            if r:return r
    nodes=find(world,'Outpost_Panels')['Children']; mapping=[]
    for n in nodes:
        name=n['Name'];p=n['Properties'];x,z,rZ=p['CFrame'][:3]
        location=(x-144,-(rZ-164),z)
        roof='Roof' in name
        # Retain all original panel IDs/pivots; explicit v2 aperture migration.
        key='layered_roof' if roof else 'corrugated_wall'
        if 'South' in name:key='corrugated_garage' if 'S01' in name else 'corrugated_window'
        elif 'East' in name and ('02' in name[-2:] or 'S02' in name):key='corrugated_window'
        if 'S02_East_01' in name:key='corrugated_door'
        rz=math.pi/2 if ('West' in name or 'East' in name) else 0
        o=instance_panel(templates,key,'Pristine',name,location,rz,roof)
        mapping.append(dict(panel_id=name,legacy_pivot_roblox=p['CFrame'],legacy_size_roblox=p['Size'],
          family=key,pivot_blender=list(location),rotation_z=rz,roof=roof,
          migration='v2 aperture changes; pivot/ID retained' if key in ('corrugated_window','corrugated_garage','corrugated_door') else 'ID/pivot retained'))
    # Existing South02 ground entry stays open; a nonblocking door surround frames it.
    # Exterior facade windows have real modeled apertures with fixed open glazing.
    for z in (4.125,14.125):
        for x in (-8,8):
            if z<10 and x==8:continue
            if z<10:continue
            for xx in (x-4,x+4):cube('Front window jamb',(xx,-24.57,z+1),(.14,.18,4.1),'steel',.025)
            for zz in (z-1,z+3):cube('Front window rail',(x,-24.57,zz),(8.1,.18,.14),'steel',.025)
            for xx in (x-1.35,x+1.35):cube('Front window mullion',(xx,-24.59,z+1),(.07,.18,4),'steel',.015)
    # Explicitly new interior partition: back storage alcove, outside center aisle.
    o=instance_panel(templates,'concrete_partition','Pristine','Outpost_v2_Interior01',(7,16,4.125))
    mapping.append(dict(panel_id=o.name,family='concrete_partition',pivot_blender=list(o.location),rotation_z=0,roof=False,migration='new v2 panel; does not replace a legacy identity'))
    (SOURCE/'panel-catalog.json').write_text(json.dumps(dict(schema_version=1,revision='p16-v1',
      unit='stud',face_axes=['X','Z'],thickness_axis='Y',families=PANEL_CATALOG,
      identity_migration=dict(version=2,legacy_count=len(nodes),legacy_world_center=[144,0,164],mapping=mapping,
       note='P17 must adopt the declared fixed apertures and additional interior panel, revalidate aim/navigation, and preserve authoritative IDs.'),
      safety=dict(max_fragments_per_transition=4,max_fragment_dimension=1.5,max_live_fragments=48,lifetime_seconds=8,max_initial_linear_speed=12,max_initial_angular_speed=4)),indent=2)+'\n')


def build_exterior():
    global CURRENT
    CURRENT=collection('03_Exterior_Dressing')
    # Upper right walkway and external stair match reference; keep inside <=24 X.
    cube('Exterior balcony landing',(19.5,7.75,9.85),(6,32.5,.55),'steel',.04,asset='balcony')
    for y in range(-8,25,4):
        for x in (16.8,22.4):
            if x<17 and abs(y-16)<3:continue # Clear the upper personnel doorway.
            rod('Balcony post',(x,y,10.125),(x,y,12.9),.07)
        for z in (11.2,12.9):
            rod('Balcony railing',(22.4,y,z),(22.4,min(y+4,24),z),.06)
    for y in (24,):
        rod('Balcony end rail',(16.8,y,12.9),(22.4,y,12.9),.07)
    for i in range(20):
        y=-28+i;z=.125+(i+1)*.5-.075
        cube('External open tread',(19.5,y,z),(5.6,1,.15),'steel',.02,asset='external_stair')
        cube('External anti slip nosing',(19.5,y-.38,z+.08),(5.4,.12,.025),'ivory',0)
    for x in (16.8,22.2):
        rod('Stair stringer',(x,-28,.3),(x,-8,10.3),.12)
        rod('External stair handrail',(x,-28,3),(x,-8,13),.07)
        for i in range(0,21,4):rod('External stair baluster',(x,-28+i,.3+i*.5),(x,-28+i,3+i*.5),.055)
    # Open personnel portal occupies the existing southern entrance.
    for z in (.125,10.125):
        portal_before=set(CURRENT.objects)
        for x in (5,11):cube('Entry portal jamb',(x,-24,z+3.8),(.35,.9,7.6),'steel',.05,asset='door_frame')
        cube('Entry portal head',(8,-24,z+7.7),(6.4,.9,.35),'steel',.05)
        for x,sgn in ((5,-1),(11,1)):
            leaf_before=set(CURRENT.objects)
            o=cube('Fixed open personnel door',(x,-25.8,z+3.5),(.18,3.4,6.8),'ivory',.04,asset='fixed_open_door')
            cube('Door vision slot',(x-.11*sgn,-25.6,z+4.7),(.03,.85,1.45),'dark',.02)
            rod('Door pull',(x-.18*sgn,-26,z+2.6),(x-.18*sgn,-26,z+3.8),.04)
            for leaf in set(CURRENT.objects)-leaf_before:leaf['portal_leaf_sign']=sgn
        aw=cube('Entry awning',(8,-25.5,z+8.0),(8,3,.12),'ivory',.03,asset='awning');aw.rotation_euler[0]=-.12
        light('Entry luminaire',(8,-24.8,z+7.5),power=75)
        if z>10:
            # Upper portal belongs to the east balcony; keep front windows intact.
            for o in set(CURRENT.objects)-portal_before:
                relative=o.location-Vector((8,-24,0))
                o.location=(16-relative.y,16+relative.x,relative.z)
                o.rotation_euler[2]+=math.pi/2
            # Fixed-open leaves fold back against the facade, leaving the narrow
            # balcony approach clear instead of projecting across its route.
            for o in set(CURRENT.objects)-portal_before:
                sign=o.get('portal_leaf_sign')
                if sign is None:continue
                old=Vector((17.8,16+sign*3,z+3.5));new=Vector((16.8,16+sign*4.8,z+3.5))
                angle=sign*math.pi/2
                o.location=new+Matrix.Rotation(angle,3,'Z')@(o.location-old)
                o.rotation_euler[2]+=angle
    cube('Garage roller drum',(-8,-24.1,7.75),(12.6,1.1,.8),'steel',.08,asset='garage_frame')
    for x in (-14,-2):cube('Garage track',(x,-24.65,3.6),(.25,.35,7.2),'steel',.02)
    for x in (-13,-3,5,11):
        cyl('Safety bollard',(x,-27,1.6),.25,3,'orange',asset='bollard')
        cube('Bollard foot',(x,-27,.25),(.8,.8,.5),'orange',.04)
    for y in (-18,4,19):
        louver('Wall vent',(16.65,y,5),(3,.7,2.8),rotation=math.pi/2)
        for z in (6.5,16.5):light('Facade lamp',(16.7,y,z),rotation=(0,0,math.pi/2),power=50)
    for x in (-15.1,15.1):
        rod('Downpipe',(x,-24.75,.5),(x,-24.75,20.5),.13)
        for z in (3,8,13,18):cube('Pipe clamp',(x,-24.75,z),(.5,.4,.13),'steel',.02)
    for x in (-12,12):
        louver('Rooftop HVAC',(x,10,23),(5,6,3))
        for dx in (-1.25,1.25):
            cyl('HVAC fan',(x+dx,10,24.58),.9,.1,'dark',vertices=20)
            for k in range(5):
                a=k*math.pi/5;rod('Fan grille',(x+dx-.8*math.cos(a),10-.8*math.sin(a),24.65),(x+dx+.8*math.cos(a),10+.8*math.sin(a),24.65),.025,'steel')
        cube('HVAC duct',(x,5.5,22),(2,3,2),'ivory',.1,asset='rooftop_duct')
    for x in (-9,7):rod('Roof conduit',(x,-20,21.2),(x,20,21.2),.065,'steel')
    # Lattice communications mast, without surpassing existing aim max height.
    for x,y in ((-8,17),(-6,17),(-7,19)):
        rod('Mast leg',(x,y,21),(x,y,30),.08,'orange')
    for z in range(22,30,2):
        for (x,y),(xx,yy) in zip(((-8,17),(-6,17),(-7,19)),((-6,17),(-7,19),(-8,17))):
            rod('Mast cross brace',(x,y,z),(xx,yy,z+2),.035,'steel')
    for x in (-8,-6):cube('Antenna panel',(x,17,28),(.6,.5,2.4),'ivory',.08,asset='radio_mast')
    # Satellite paraboloid has an intentionally concave triangulated dish.
    vs=[(0,0,0)];fs=[];rings=5;segments=24
    for r in range(1,rings+1):
        rr=1.7*r/rings
        for j in range(segments):
            a=2*math.pi*j/segments;vs.append((rr*math.cos(a),rr*math.sin(a),.18*rr*rr))
    for j in range(segments):fs.append((0,1+j,1+(j+1)%segments))
    for r in range(1,rings):
        a=1+(r-1)*segments;b=1+r*segments
        for j in range(segments):k=(j+1)%segments;fs.append((a+j,b+j,b+k,a+k))
    dish=mesh('Satellite dish',vs,fs,'ivory');dish.location=(8,17,23.5);dish.rotation_euler=(.8,0,.6);dish['asset_category']='satellite_dish'
    rod('Dish pedestal',(8,17,21.2),(8,17,23.5),.12)
    rod('Dish feed arm',(8,16,23),(8,15,25),.07)
    cyl('Dish receiver',(8,15,25),.16,.5,'dark')
    for pos in ((-12,-29,0),(12,-29,0),(-20,15,0)):
        pallet('Outdoor pallet',pos)
        case('Outdoor sealed crate',(pos[0],pos[1],.4),(3.2,2.2,1.8))
        case('Outdoor crate stack',(pos[0],pos[1],2.2),(2.9,2,1.4))
    # Containment tank with visible protective cage.
    cube('Water tank',(-20,20,1.9),(3.5,3.5,3.3),'ivory',.2,asset='tank')
    for x in (-21.9,-18.1):
        for y in (18.1,21.9):rod('Tank cage',(x,y,.3),(x,y,3.8),.045)
    for z in (.6,1.6,2.6,3.6):
        for y in (18.1,21.9):rod('Tank rail',(-21.9,y,z),(-18.1,y,z),.04)
    for x,y in ((-20,-15),(20,27)):
        for dx in (-2,2):
            # Jersey-barrier trapezoidal profile, not a plain cube.
            points=[(-2,0),(-2,.5),(-.8,1.5),(-.65,2.7),(.65,2.7),(.8,1.5),(2,.5),(2,0)]
            o=slab_polygon('Concrete traffic barrier',points,1.2,'concrete');o.location=(x+dx,y,.125);o['asset_category']='barrier'
    for i in range(7):
        xx=-21+RNG.uniform(-1.5,1.5);yy=-20+RNG.uniform(-2,2)
        o=cube('Weathered concrete rubble',(xx,yy,.25),(RNG.uniform(.25,.7),RNG.uniform(.2,.6),.35),'concrete',.04,asset='rubble')
        o.rotation_euler[2]=RNG.uniform(0,math.pi)
    # Loading apron/road marks are presentation props inside surveyed envelope.
    for x in range(-14,-1,2):
        o=cube('Loading hazard stripe',(x,-25.9,.14),(.8,2,.02),'orange',0);o.rotation_euler[2]=-.5
    text('Outpost facade stencil','OUTPOST / 07',(-13,-24.68,8.4),.65)
    text('Personnel portal stencil','AUTHORIZED\nPERSONNEL',(5.5,-24.75,7.1),.24)


def build_workshop():
    global CURRENT
    CURRENT=collection('04_Floor_1_Workshop')
    for y in (-16,-8,0,8):rack('Workshop storage rack',(12.7,y,.125))
    # Preserve internal stairs west; workshop occupies southeast corner.
    workbench_before=set(CURRENT.objects)
    cube('Workbench top',(-1,-16,2.6),(6.4,2.1,.25),'wood',.06,asset='workbench')
    for x in (-3.5,1.5):
        cube('Workbench drawer cabinet',(x,-16,1.35),(1.4,2,2.4),'steel',.05)
        for z in (.6,1.25,1.9):
            cube('Workbench drawer',(x,-17.04,z),(1.25,.08,.5),'steel',.02)
            rod('Drawer handle',(x-.3,-17.12,z),(x+.3,-17.12,z),.025)
    cube('Pegboard',(-1,-14.8,4.6),(6.3,.16,3.4),'wood',.04,asset='tool_board')
    for x in np.linspace(-3.8,1.8,15):
        for z in np.linspace(3.3,6,8):cyl('Pegboard perforation',(x,-14.91,z),.025,.025,'dark',rotation=(math.pi/2,0,0),vertices=6)
    for i in range(9):
        x=-3.4+i*.6;z=4.4+.3*math.sin(i)
        rod('Hanging spanner',(x,-15,z-.5),(x,-15,z+.45),.055,'ivory')
        cyl('Wrench open head',(x,-15,z+.5),.14,.08,'steel',rotation=(math.pi/2,0,0),vertices=6)
    cube('Bench vise',(-2.5,-16.3,2.95),(.7,.6,.55),'steel',.05,asset='bench_vise')
    rod('Vise screw',(-3,-16.3,3),(-2,-16.3,3),.04)
    rod('Task lamp upright',(1,-15.8,2.8),(1,-15.5,4.2),.05)
    rod('Task lamp arm',(1,-15.5,4.2),(.3,-16,4.6),.05)
    cyl('Task lamp shade',(.3,-16,4.5),.35,.3,'dark',asset='task_lamp')
    chair('Workshop stool',(-1,-19,.125))
    for o in set(CURRENT.objects)-workbench_before:o['kit_family']='workbench';o['kit_instance']='workbench.001'
    for x,y in ((4,13),(10,20),(4,20)):
        pallet('Workshop pallet',(x,y,.125));case('Workshop transport case',(x,y,.5),(3.2,2.5,2.2))
    for x in (-3,5,13):
        for y in (-10,5,17):light('Workshop overhead',(x,y,8),power=130)
    service('Workshop utilities',7.7)
    # Clear central pedestrian aisle x=-3..7, y -24..14.
    for x in (-3,7):cube('Workshop aisle line',(x,-4,.145),(.12,38,.025),'orange',0,asset='floor_marking')
    for y in range(-22,15,4):cube('Aisle center dash',(2,y,.15),(.1,1.6,.02),'ivory',0)
    cube('Electrical switchboard',(-15.1,20,4),(1,3,2.5),'steel',.06,asset='electrical_panel')
    for y in (19.2,20,20.8):cube('Switchboard breaker',(-14.55,y,4),(.1,.35,.65),'dark',.02)
    text('Workshop location stencil','STORAGE / MAINTENANCE',(-4,-14.95,6.5),.35)


def build_command():
    global CURRENT
    CURRENT=collection('05_Floor_2_Command')
    z=10.125
    # Front-facing consoles look toward windows; center route and stair landing clear.
    desk('Window command console',(5,-20,z));chair('Forward operator chair',(5,-17,z))
    desk('West command console',(-.5,5,z));chair('West operator chair',(-.5,8,z))
    desk('Rear command console',(5,20,z),3)
    for x in (1,5):chair('Rear operator chair',(x,17,z))
    # Tactical display: actual original baked topographic graphic, no interaction.
    cube('Tactical table pedestal',(7,-3,z+1.3),(5,5,2.6),'steel',.12,asset='tactical_table')
    cube('Tactical table rim',(7,-3,z+2.8),(7.3,6.2,.55),'steel',.14)
    cube('Tactical graphic',(7,-3,z+3.1),(6.5,5.4,.04),'tactical',.02)
    for x in (3.6,10.4):
        for y in (-5.8,-.2):cube('Tactical safety bumper',(x,y,z+3.1),(.45,.45,.3),'orange',.07)
    for y in (-5.6,-.4):cube('Tactical task light',(7,y,z+3.15),(1.6,.16,.06),'lamp',.02)
    for y in (8,12):
        cube('Server cabinet',(13,y,z+3.5),(3.1,3.4,7),'dark',.08,asset='server_rack')
        for k in range(12):
            zz=z+.4+k*.52
            cube('Server module',(13,y-1.74,zz),(2.7,.12,.38),'steel',.02)
            for dx in (-1,-.7,.6):cube('Server status lamp',(13+dx,y-1.82,zz),(.07,.03,.07),'lamp',0)
            for dx in (-.3,0,.3):cube('Server vent',(13+dx,y-1.83,zz),(.1,.02,.23),'dark',0)
        for dx in (-.5,0,.5):rod('Server patch cable',(13+dx,y-1.9,z+1),(13+dx+.15,y-1.95,z+2.5),.035,'orange')
    rack('Command equipment shelving',(12.7,-14,z),levels=2,boxes=True)
    for x in (3,7):
        cube('Radio receiver',(x,20,z+4.3),(2.2,1.2,1.2),'olive',.08,asset='radio_equipment')
        for dx in (-.65,0,.65):cyl('Radio knob',(x+dx,19.34,z+4.3),.09,.1,'steel',rotation=(math.pi/2,0,0))
        rod('Radio antenna',(x+.8,20,z+4.9),(x+.8,20,z+6.6),.025)
    for x in (1,11):
        for y in (-10,4,17):light('Command pendant',(x,y,18),power=170)
    service('Command utilities',17.8)
    for x in (2.7,11.3):cube('Tactical floor boundary',(x,-3,z+.025),(.12,8,.025),'orange',0)
    for y in (-7,1):cube('Tactical floor boundary',(7,y,z+.025),(8.7,.12,.025),'orange',0)
    for pos in ((1,-12,z),(10,16,z)):
        case('Command storage case',pos,(2.5,1.8,1.4))
    cyl('Field lantern',(1,-12,z+1.9),.27,.9,'lamp',asset='field_lantern')
    for a in range(6):
        ang=a*math.pi/3;xx=1+.3*math.cos(ang);yy=-12+.3*math.sin(ang)
        rod('Lantern cage',(xx,yy,z+1.5),(xx,yy,z+2.4),.025,'steel')
    text('Command wall stencil','SIGNALS / OPERATIONS',(-3,23.3,z+6.8),.48,rotation=(math.pi/2,0,0))


def asset_group(kind, function):
    """Tag one reusable, multi-mesh asset instance without losing editable pieces."""
    def wrapped(name,*args,**kwargs):
        before=set(CURRENT.objects)
        GROUP_COUNTERS[kind]=GROUP_COUNTERS.get(kind,0)+1
        instance=f'{kind}.{GROUP_COUNTERS[kind]:03d}'
        result=function(name,*args,**kwargs)
        for o in set(CURRENT.objects)-before:
            o['kit_family']=kind;o['kit_instance']=instance
        return result
    return wrapped


def build_kit():
    global CURRENT
    source=list(bpy.context.scene.objects)
    groups={}
    for o in source:
        if o.get('kit_family'):
            groups.setdefault(o['kit_family'],{}).setdefault(o['kit_instance'],[]).append(o)
    CURRENT=collection('11_Reusable_Kit');CURRENT.hide_render=True;CURRENT.hide_viewport=True
    for i,(family,instances) in enumerate(groups.items()):
        members=next(iter(instances.values()))
        center=sum((o.location for o in members),Vector())/len(members)
        x=-100+(i%3)*13;y=-15+(i//3)*14
        minz=min((o.matrix_world@Vector(p)).z for o in members if o.type=='MESH' for p in o.bound_box)
        for o in members:
            cp=o.copy()
            if o.type=='MESH':cp.data=o.data
            CURRENT.objects.link(cp);cp.name='Kit.'+o.name
            cp.location=o.location+Vector((x-center.x,y-center.y,-minz+.5))
        cube('Kit display base',(x,y,.2),(11,11,.4),'concrete',.04)
        text('Kit asset label',family.upper(),(x-5,y-5,.5),.5)


def export_reusable_kit():
    """Export complete semantic props with floor-centered local pivots.

    Source keeps editable components; a disposable merged export mesh makes each
    family directly extractable without reconstructing its small detail pieces.
    """
    global CURRENT
    kit=bpy.data.collections['11_Reusable_Kit'];kit.hide_viewport=False
    families={}
    for o in kit.objects:
        if o.type=='MESH' and o.get('kit_family'):families.setdefault(o['kit_family'],[]).append(o)
    scratch=collection('P16_Export_Temporary');CURRENT=scratch;records=[]
    for family,members in families.items():
        bpy.context.view_layer.update()
        pts=[o.matrix_world@Vector(p) for o in members for p in o.bound_box]
        pivot=Vector(((min(p.x for p in pts)+max(p.x for p in pts))/2,
                      (min(p.y for p in pts)+max(p.y for p in pts))/2,min(p.z for p in pts)))
        copies=[]
        for o in members:
            cp=o.copy();cp.data=o.data.copy();scratch.objects.link(cp);cp.location=o.location-pivot;copies.append(cp)
        merged=join_meshes(copies,'Reusable.'+family)
        obj_export(EXPORT/f'kit-{family}.obj',[merged]);export_fbx(EXPORT/f'kit-{family}.fbx',[merged])
        dep=bpy.context.evaluated_depsgraph_get();me=merged.evaluated_get(dep).to_mesh();me.calc_loop_triangles()
        records.append(dict(family=family,source_collection=kit.name,source_components=[o.name for o in members],
          obj=f'kit-{family}.obj',fbx=f'kit-{family}.fbx',export_object=merged.name,pivot='center X/Y of evaluated bounds, bottom Z=0',
          triangles=len(me.loop_triangles),dimensions_studs=[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)]))
        merged.evaluated_get(dep).to_mesh_clear();bpy.data.objects.remove(merged,do_unlink=True)
    bpy.data.collections.remove(scratch);kit.hide_viewport=True
    (SOURCE/'reusable-kit.json').write_text(json.dumps(dict(schema_version=1,assets=records),indent=2)+'\n')


def setup_review():
    global CURRENT
    CURRENT=collection('09_Review_Cameras_Lights')
    # Scene ground is a studio pedestal, not map terrain or export content.
    cube('Review ground',(0,0,-1.1),(115,115,.5),'concrete',.1)
    def camera(name,loc,target,lens=42):
        data=bpy.data.cameras.new(name);data.lens=lens;data.clip_end=1000
        o=bpy.data.objects.new(name,data);CURRENT.objects.link(o);o.location=loc
        o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
    ext=camera('Exterior',(78,-95,50),(1,-2,11),48)
    camera('Floor_1',(4,-23,5.3),(4,15,4.2),20)
    camera('Floor_2',(3,-14,15.8),(6,15,13.4),20)
    camera('Cutaway',(60,-72,66),(0,0,9),44)
    camera('Damage_front',(30,-75,58),(30,53,5),38)
    camera('Damage_back',(30,175,58),(30,53,5),38)
    camera('Isolated_kit',(-65,-62,44),(-87,2,3),43)
    scene=bpy.context.scene;scene.camera=ext
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1280;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.world.color=(.2,.2,.2)
    world=bpy.data.worlds.new('Review studio daylight');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.38,.45,1);world.node_tree.nodes['Background'].inputs[1].default_value=.85;scene.world=world
    for name,loc,energy,size,color,target in [
        ('Warm key',(10,-30,55),50000,30,(1,.79,.58),(0,0,6)),
        ('Cool fill',(-35,-15,30),28000,35,(.6,.76,1),(0,0,8)),
        ('Roof rim',(5,30,45),35000,25,(1,.9,.72),(0,0,12)),
        ('Kit review',(-85,-10,35),28000,30,(1,.88,.72),(-87,0,3))]:
        d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;d.color=color
        o=bpy.data.objects.new(name,d);CURRENT.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    # Avatar guide is a clearly labelled neutral mannequin, not NPC content.
    CURRENT=collection('10_Scale_Guide')
    x,y,z=-3,-30,.125
    cube('5.5-stud avatar torso',(x,y,z+3),(1.8,.9,2),'ivory',.12)
    cyl('Avatar guide head',(x,y,z+4.6),.6,1.2,'orange',vertices=16)
    for dx in (-.5,.5):cube('Avatar guide leg',(x+dx,y,z+1),(.7,.8,2),'dark',.08)
    for dx in (-1.25,1.25):cube('Avatar guide arm',(x+dx,y,z+3),(.6,.8,1.9),'olive',.08)
    text('Scale caption','5.5 STUDS',(-5,-31,.2),.4)
    # Comfortable opening viewport; gallery disabled by default, library hidden.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_distance=80
                area.spaces.active.region_3d.view_location=(0,0,10)
                area.spaces.active.region_3d.view_rotation=ext.rotation_euler.to_quaternion()
                area.spaces.active.shading.type='MATERIAL'
    bpy.data.collections['06_Damage_Gallery'].hide_render=True
    bpy.data.collections['06_Damage_Gallery'].hide_viewport=True


def measured_inventory():
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get();by_collection={};counts={};objects=[]
    for col in bpy.context.scene.collection.children:
        tri=0;mesh_count=0
        for o in col.objects:
            if o.type!='MESH':continue
            eo=o.evaluated_get(deps);me=eo.to_mesh();me.calc_loop_triangles();t=len(me.loop_triangles);eo.to_mesh_clear()
            tri+=t;mesh_count+=1
            cat=o.get('asset_category')
            if cat:counts[cat]=counts.get(cat,0)+1
            objects.append(dict(name=o.name,collection=col.name,triangles=t,asset_category=cat))
        by_collection[col.name]=dict(mesh_objects=mesh_count,triangles=tri)
    assembly=[v for k,v in by_collection.items() if k[:2] in ('01','02','03','04','05')]
    assembly_tri=sum(v['triangles'] for v in assembly)
    library_tri=by_collection['07_Panel_Library']['triangles']+by_collection['08_Collision_Proxies']['triangles']
    required=['foundation','usable_upper_floor','support_column','stable_beam','internal_stair','parapet','balcony','external_stair','door_frame','fixed_open_door','awning','garage_frame','bollard','louver_vent','rooftop_duct','radio_mast','satellite_dish','sealed_case','tank','barrier','storage_rack','workbench','tool_board','bench_vise','task_lamp','floor_marking','electrical_panel','command_console','monitor','operator_chair','tactical_table','server_rack','radio_equipment','field_lantern','duct','utility_lamp']
    features={
      'foundations':['Foundation'], 'supporting frame':['Concrete pier','Perimeter long beam','Cross beam'],
      'usable floors':['Upper_Main','Upper_North_Landing','Upper_South_Rim'],
      'panel walls and roof':['Outpost_S01','Outpost_S02','Outpost_v2_Interior'],
      'garage frame':['Garage roller drum','Garage track'], 'personnel doors':['Fixed open personnel door','Entry portal'],
      'window frames':['Front window jamb','Front window rail','Front window mullion'],
      'stairs and balcony':['Internal stair tread','External open tread','Exterior balcony'],
      'railings':['Balcony railing','External stair handrail','Upper stairwell guardrail'],
      'awnings':['Entry awning'], 'wall vents':['Wall vent'], 'pipes and clamps':['Downpipe','Pipe clamp'],
      'conduits and wiring':['Roof conduit','Workshop utilities.conduit','Command utilities.conduit'],
      'lamps':['Entry luminaire','Facade lamp','Workshop overhead','Command pendant'],
      'rooftop HVAC and ducts':['Rooftop HVAC','HVAC duct','HVAC fan'], 'aerial mast':['Mast leg','Mast cross brace','Antenna panel'],
      'satellite dish':['Satellite dish','Dish pedestal','Dish feed arm'],
      'barriers and bollards':['Concrete traffic barrier','Safety bollard'], 'cases and pallets':['Outdoor sealed crate','Outdoor pallet'],
      'tank and rubble':['Water tank','Tank cage','Weathered concrete rubble'], 'loading markings':['Loading hazard stripe'],
      'storage racks':['Workshop storage rack'], 'workbench and drawers':['Workbench top','Workbench drawer'],
      'tools and vise':['Hanging spanner','Wrench open head','Bench vise'], 'tool board':['Pegboard'], 'stool':['Workshop stool'],
      'service ducts':['Workshop utilities.duct','Command utilities.duct'], 'floor details':['Workshop aisle line','Aisle center dash'],
      'command desks and monitors':['Window command console','West command console','Rear command console'],
      'keyboard and controls':['Window command console.key','Rear command console.switch'],
      'radios':['Radio receiver','Radio antenna','Radio knob'], 'server racks and cables':['Server cabinet','Server module','Server patch cable'],
      'chairs':['Forward operator chair','Rear operator chair'], 'tactical table':['Tactical table pedestal','Tactical graphic'],
      'upper storage and lantern':['Command equipment shelving','Command storage case','Field lantern'],
      'stencils':['Outpost facade stencil.export','Workshop location stencil.export','Command wall stencil.export']}
    feature_inventory=[]
    for feature,prefixes in features.items():
        matched=[o['name'] for o in objects if any(o['name'].startswith(prefix) for prefix in prefixes)]
        assert matched,feature
        feature_inventory.append(dict(feature=feature,object_prefixes=prefixes,matched_meshes=len(matched)))
    report=dict(schema_version=1,revision='p16-v1',blender_version=bpy.app.version_string,
       authoring_seed=1601,units=dict(blender_unit='1 stud',up='Z',front='-Y',fbx_forward='-Z',fbx_up='Y',roblox_local_transform=['X','Z','-Y']),
       budgets=BUDGETS,measured=dict(assembly_triangles=assembly_tri,package_triangles=assembly_tri+library_tri+sum(a['triangles'] for a in json.loads((SOURCE/'reusable-kit.json').read_text())['assets']),
       reusable_kit_triangles=sum(a['triangles'] for a in json.loads((SOURCE/'reusable-kit.json').read_text())['assets']),
       materials=len(MATS),textures=len(MATS),decoded_texture_bytes=len(MATS)*512*512*4,
       mipmapped_texture_bytes_estimate=math.ceil(len(MATS)*512*512*4*4/3)),
       reference_features=feature_inventory,required_categories=required,category_counts=counts,collections=by_collection,objects=objects,
       site=dict(footprint=[32,48],world_center_roblox=[144,0,164],envelope_blender=[-24,-32,24,30],
       floor_top_heights=[.125,10.125],roof_center_height=20.625,highest_utility=30,
       internal_stair=dict(x=-10,width=8,steps=16,rise=.625,run=2),
       external_stair=dict(x=19.5,width=5.6,steps=20,rise=.5,run=1),
       preserved_route='Legacy South entry x=8, y=-24; internal west stairs and north landing retained',
       impact='Exterior balcony/stair extends 6.4 studs east; surveyed site stays in combat disk and clear of map launcher approaches. P17 must validate native avatar and aim/thermal/collision behavior.'),
       interpretations=[
       '32x48 footprint and 10-stud stories compress reference room width; two functional furnished rooms retained.',
       'North/west rear elevations extrapolated from teal/concrete palette; fixed apertures require declared v2 migration.',
       'Existing south ground entry remains open; reference left garage becomes an additional open aperture.',
       'Doors fixed open; windows empty apertures with metal frames; no glass durability, NPCs, terrain or computer interaction.',
       'Pristine assembled scene is complete; reference wall breach appears only in material damage gallery.',
       'Original baked color textures supply fine wear; no external images, cloud IDs or procedural-only render materials.',
       'FBX axis conversion is local export preparation, not Roblox import or engine acceptance.'
       ])
    assert not (set(required)-set(counts)),set(required)-set(counts)
    for key,value in report['measured'].items():
        if key in BUDGETS:assert value<=BUDGETS[key],(key,value)
    (SOURCE/'asset-inventory.json').write_text(json.dumps(report,indent=2)+'\n')


def main():
    SOURCE.mkdir(parents=True,exist_ok=True);(EXPORT/'textures').mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):bpy.data.collections.remove(c)
    for m in list(bpy.data.materials):bpy.data.materials.remove(m)
    for im in list(bpy.data.images):bpy.data.images.remove(im)
    bpy.context.scene.unit_settings.system='NONE';bpy.context.scene.unit_settings.scale_length=1
    for args in [
      ('concrete',(.5,.45,.36),'concrete',0,.86,0),('teal',(.12,.3,.3),'metal',.35,.7,0),
      ('orange',(.6,.22,.075),'metal',.3,.7,0),('steel',(.24,.26,.25),'metal',.65,.5,0),
      ('dark',(.055,.066,.065),'plain',.2,.65,0),('ivory',(.61,.59,.51),'concrete',.1,.72,0),
      ('olive',(.22,.25,.14),'metal',.3,.65,0),('wood',(.32,.21,.11),'plain',0,.8,0),
      ('roof',(.24,.235,.21),'roof',0,.9,0),('screen',(.02,.15,.3),'screen',.1,.35,1.2),
      ('tactical',(.02,.15,.3),'tactical',.1,.35,.9),('lamp',(1,.65,.26),'plain',0,.4,3)
      ]:material(*args)
    templates=build_damage();build_structure(templates);build_exterior();build_workshop();build_command()
    assembly=[]
    for col in bpy.context.scene.collection.children:
        if col.name[:2] in ('01','02','03','04','05'):assembly.extend(col.objects)
    # Retain editable FONT objects and export real evaluated stencil geometry.
    bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get()
    for font in [o for o in assembly if o.type=='FONT']:
        data=bpy.data.meshes.new_from_object(font.evaluated_get(dep))
        lettering=bpy.data.objects.new(font.name+'.export',data)
        font.users_collection[0].objects.link(lettering);lettering.matrix_world=font.matrix_world.copy()
        lettering['export_only']=True;lettering.hide_render=True;lettering.hide_set(True);uv_box(lettering)
        assembly.append(lettering)
    mesh_assembly=[o for o in assembly if o.type=='MESH']
    export_fbx(EXPORT/'outpost-assembly-v1.fbx',mesh_assembly)
    obj_export(EXPORT/'outpost-assembly-v1.obj',mesh_assembly)
    mtl=[];mapping=[]
    for key,mat in MATS.items():
        mtl.extend([f'newmtl {key}','Kd 1 1 1',f'map_Kd textures/{key}.png'])
        p=mat.node_tree.nodes.get('Principled BSDF')
        mapping.append(dict(material=key,base_color=f'textures/{key}.png',roughness=p.inputs['Roughness'].default_value,
             metalness=p.inputs['Metallic'].default_value,emission_strength=p.inputs['Emission Strength'].default_value))
    (EXPORT/'materials.mtl').write_text('\n'.join(mtl)+'\n')
    (EXPORT/'material-map.json').write_text(json.dumps(dict(schema_version=1,materials=mapping,
      note='All base colors are original baked PNGs; constant roughness/metalness/emission listed explicitly. No Roblox upload performed.'),indent=2)+'\n')
    build_kit();export_reusable_kit();setup_review();measured_inventory()
    bpy.context.scene['P16Revision']='p16-v1'
    bpy.context.scene['P16Approval']='Pending explicit human approval'
    bpy.context.scene.render.image_settings.file_format='PNG'
    for im in bpy.data.images:
        if im.type=='IMAGE':im.filepath='//../../exports/military-outpost/textures/'+im.name+'.png'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'military-outpost.blend'),compress=True)
    print('P16 authored scene/export package saved')


# Grouping is source metadata, also used for the isolated review collection.
case=asset_group('sealed_case',case)
pallet=asset_group('pallet',pallet)
rack=asset_group('storage_rack',rack)
light=asset_group('utility_lamp',light)
louver=asset_group('louver_vent',louver)
desk=asset_group('command_console',desk)
chair=asset_group('operator_chair',chair)

if __name__=='__main__':main()
