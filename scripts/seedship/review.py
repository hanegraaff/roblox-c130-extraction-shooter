"""Daylight badlands, interior bounce lighting and review cameras. Review only."""
import math
import random
import bpy
from mathutils import Vector
from form import Mesh
from meshwork import MATERIALS

VIEWS = {
    'Recovery bay': ((44.0,4.5,10.8),(55.4,11.1,3.60),33),
    'Specimen 07': ((52.9,8.0,8.48),(55,13.51,4.05),55),
    'Resonator bank': ((16,-31,6.75),(24,-15.8,3.75),41),
    'Field machinery': ((-39,-42,7.6),(-26,-15,4.85),43),
    'Exterior': ((17,-205,68),(0,-5,11),30.4),
    'Flank': ((150,-181,37),(7,-7,13),33),
    'Arrival hall': ((1,-58.5,5.4),(0,13,11.0),15),
    'Observation deck': ((55,-10,22.4),(-13,17,13.3),25),
    'Seed vault': ((48,8,5.5),(66,22,5.0),28),
    'Starboard breach': ((83,-93,11),(54,-24,11.2),28),
    'Open decks': ((18,-159,224),(0,0,4),40),
}


def material(key,color,rough):
    m=bpy.data.materials.new('Review • '+key)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough
    MATERIALS[key]=m
    return m


def badlands(g):
    sand=material('ochre dust',(.44,.29,.19),.87)
    n,link=sand.node_tree.nodes,sand.node_tree.links
    uv=n.new('ShaderNodeTexCoord')
    scale=n.new('ShaderNodeTexNoise')
    scale.inputs['Scale'].default_value=.052
    scale.inputs['Detail'].default_value=5.0
    link.new(uv.outputs['Object'],scale.inputs[0])
    r=n.new('ShaderNodeValToRGB')
    r.color_ramp.elements[0].color=(.28,.173,.112,1)
    r.color_ramp.elements[1].color=(.74,.54,.38,1)
    link.new(scale.outputs['Fac'],r.inputs[0])
    p=n.get('Principled BSDF')
    link.new(r.outputs[0],p.inputs['Base Color'])
    bump=n.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value=.26
    bump.inputs['Distance'].default_value=.11
    grain=n.new('ShaderNodeTexNoise')
    grain.inputs['Scale'].default_value=1.8
    grain.inputs['Detail'].default_value=3.5
    link.new(uv.outputs['Object'],grain.inputs[0])
    link.new(grain.outputs['Fac'],bump.inputs['Height'])
    link.new(bump.outputs[0],p.inputs['Normal'])
    material('stratum',(.32,.196,.134),.92)
    material('caliche',(.51,.343,.215),.88)
    material('purple shale',(.32,.205,.18),.86)
    m=Mesh()
    m.block(-1400,1400,-1400,1400,-5,-2.43,'ochre dust')
    m.finish('Set • dry lake bed',g)
    m=Mesh()
    rng=random.Random(597)
    # Weather the rim at three spatial scales. Neighboring rock towers share
    # a talus fan, with incised faces and narrow, discontinuous pale strata.
    for j in range(93):
        ang=j*math.tau/93+rng.uniform(-.05,.05)
        distance=rng.uniform(335,750)
        x,y=distance*math.cos(ang),distance*math.sin(ang)
        width,depth,height=rng.uniform(14,57),rng.uniform(10,35),rng.uniform(5,25)
        if j%13 in (2,3,4):
            height*=1.65
        count=rng.randint(1,4)
        for sub in range(count):
            bx=x+sub*width*.54
            by=y+rng.uniform(-.22,.22)*depth
            w=width*rng.uniform(.33,.81)
            h=height*rng.uniform(.6,1.3)
            pts=[]
            waves=[rng.uniform(0,math.tau) for _ in range(3)]
            for k in range(26):
                a=k*math.tau/26
                radial=1+.16*math.cos(3*a+waves[0])+.11*math.sin(5*a+waves[1])+rng.uniform(-.08,.08)
                chip=rng.uniform(-.13,.05)
                pts.append((radial*math.cos(a),radial*math.sin(a),chip))
            levels=[(0,1.78),(.22,1.19),(.38,.92),(.48,.82),(.55,.80),
                    (.60,.74),(.72,.70),(.77,.69),(.90,.61),(.955,.62),(1,.54)]
            def ring(z,r):
                return [(bx+u*w*r+z*w*.13,by+v*depth*r,-2.52+h*(z+chip*min(1,2*z)))
                        for u,v,chip in pts]
            for k,((z0,r0),(z1,r1)) in enumerate(zip(levels,levels[1:])):
                low,high=ring(z0,r0),ring(z1,r1)
                for n in range(26):
                    nxt=(n+1)%26
                    mat=('ochre dust' if k<2 else 'purple shale' if k in (4,6) else
                         'caliche' if k in (3,8) and (n+sub)%7 else 'stratum')
                    m.plate([low[n],low[nxt],high[nxt],high[n]],mat)
            top=ring(1,.54)
            for n in range(26):
                m.plate([top[n],top[(n+1)%26],(bx+w*.13,by,-2.42+h)],'caliche',[(0,0),(1,0),(0,1)])
    for j in range(310):
        cx,cy=rng.uniform(-195,195),rng.uniform(-145,150)
        if abs(cx)<106 and -76<cy<76 or abs(cx)<30 and cy<-69:
            continue
        for sub in range(rng.randrange(2,8)):
            x,y=cx+rng.uniform(-3.4,3.4),cy+rng.uniform(-2.1,2.1)
            size=rng.uniform(.12,1.42)*(1.83 if sub==0 else .66)
            pts=[(x+size*math.cos(i*math.tau/7)*rng.uniform(.64,1.6),
                  y+size*math.sin(i*math.tau/7)*rng.uniform(.61,1.1)) for i in range(7)]
            m.loft([(u,v,-2.58) for u,v in pts],
                   [(x+(u-x)*.64+size*.15,y+(v-y)*.5,-2.39+size*rng.uniform(.34,.87)) for u,v in pts],
                   'caliche' if sub%2 else 'stratum')
    m.finish('Set • eroded mesas and talus',g)


def setup(g):
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=22
    scene.cycles.use_denoising=True
    scene.cycles.max_bounces=5
    scene.render.resolution_x,scene.render.resolution_y=1440,840
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='JPEG'
    scene.render.image_settings.quality=93
    scene.view_settings.view_transform='AgX'
    scene.world=bpy.data.worlds.new('Dry equatorial sky')
    scene.world.use_nodes=True
    nodes,links=scene.world.node_tree.nodes,scene.world.node_tree.links
    coord=nodes.new('ShaderNodeTexCoord')
    split=nodes.new('ShaderNodeSeparateXYZ')
    links.new(coord.outputs['Generated'],split.inputs[0])
    absolute=nodes.new('ShaderNodeMath')
    absolute.operation='ABSOLUTE'
    links.new(split.outputs['Z'],absolute.inputs[0])
    ramp=nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(.98,.78,.66,1)
    ramp.color_ramp.elements[1].position=.65
    ramp.color_ramp.elements[1].color=(.30,.54,.91,1)
    links.new(absolute.outputs[0],ramp.inputs[0])
    bg=nodes.get('Background')
    links.new(ramp.outputs[0],bg.inputs[0])
    bg.inputs[1].default_value=.60
    def light(name,kind,loc,target,power,tint,size):
        d=bpy.data.lights.new(name,kind)
        o=bpy.data.objects.new(name,d)
        g.objects.link(o)
        o.location=loc
        o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
        d.energy=power
        d.color=tint
        if kind=='SUN':
            d.angle=size
        else:
            d.shape='DISK'
            d.size=size
            d.specular_factor=.24
    light('Sun • raking left', 'SUN',(-90,-100,115),(0,0,0),3.1,(1,.865,.71),.078)
    for j,(x,y) in enumerate([(-34,-22),(33,-24),(-28,12),(28,12),(0,-39),(0,37),(-55,9),(55,9),(-54,-24),(54,-24)]):
        light(f'Nave bounce {j:02d}','AREA',(x,y,24 if abs(x)<50 else 21),
              (x*.77,y+4,1),6800 if abs(x)<50 else 3700,(.82,1,.84) if j%3 else (1,.82,.70),13)
    for j,(x,y) in enumerate([(68,23),(71,-5),(-65,18),(-59,-12),(-23,32),(22,33)]):
        light(f'Gallery bounce {j:02d}','AREA',(x,y,13.6),(x-3,y-2,2),1800,(.91,.95,.73),7)
    light('Recovery • vaulted lamp','AREA',(56.6,14.7,8.4),(55,12.4,3.8),445,(.72,.93,1),3.1)
    light('Recovery • amber service bounce','AREA',(58.9,10.9,5.6),(55,12.2,3.9),180,(1,.58,.32),2)
    light('Recovery • corneal reflection','AREA',(52.2,11.8,7.4),(55,13.6,4.1),115,(.82,.97,1),1.5)
    badlands(g)
    for name,(pos,target,lens) in VIEWS.items():
        d=bpy.data.cameras.new(name)
        o=bpy.data.objects.new(name,d)
        g.objects.link(o)
        o.location=pos
        o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
        d.lens=lens
        d.clip_end=2200
        if name=='Recovery bay':
            scene.camera=o
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active
            s.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion()
            s.region_3d.view_location=(55.4,11.1,3.6)
            s.region_3d.view_distance=15
            s.region_3d.view_perspective='CAMERA'
            s.overlay.show_overlays=False
            s.shading.type='MATERIAL'
            s.shading.use_scene_lights=True
            s.shading.use_scene_world=True
