"""Model the supine S-07 specimen. Coordinates are local to the top of its berth."""
import math

import bpy
import numpy as np
from mathutils import Vector
from meshwork import MATERIALS, Mesh
from surfaces import write_png

BAY = Vector((55.0, 11.2, 0.0))
BERTH = 3.04
UP = Vector((0, 0, 1))

# Longitudinal stations, measured from the bed surface. The widening crown,
# short mandible and eye placement are built into one continuous skin.
# Each section gives y, width, center height and vertical radius.
HEAD = [
    (1.49, .16, .55, .13), (1.62, .30, .61, .22),
    (1.85, .45, .69, .34), (2.05, .59, .73, .43),
    (2.29, .82, .76, .52), (2.55, .99, .78, .65),
    (2.87, 1.05, .78, .75), (3.20, 1.04, .76, .76),
    (3.50, .94, .72, .68), (3.76, .70, .68, .50),
    (3.93, .37, .63, .28), (4.00, .045, .61, .047),
]
TORSO = [
    (-1.45, .22, .37, .16), (-1.27, .48, .39, .30),
    (-1.04, .58, .42, .34), (-.78, .57, .43, .33),
    (-.46, .44, .43, .29), (-.17, .46, .46, .31),
    (.13, .60, .49, .37), (.43, .73, .53, .44),
    (.72, .78, .53, .43), (.94, .70, .51, .35),
    (1.09, .48, .48, .26), (1.19, .24, .46, .20),
]


def longitudinal(mesh, stations, material, count=24):
    points = []
    for y, width, center, height in stations:
        for index in range(count):
            angle = math.tau * index / count
            points.append((width * math.cos(angle), y, center + height * math.sin(angle)))
    last = (len(stations) - 1) * count
    faces = [tuple(range(count)), tuple(range(last, last + count))]
    for start in range(0, last, count):
        for index in range(count):
            nxt = (index + 1) % count
            faces.append((start + index, start + nxt, start + count + nxt, start + count + index))
    mesh.solid(points, faces, material)


def tube(mesh, points, radii, material, sides=10):
    """Loft elliptical cross sections on a continuous centerline."""
    centers = [Vector(p) for p in points]
    reference = Vector((1, 0, 0))
    if abs((centers[-1] - centers[0]).normalized().x) > .87:
        reference = Vector((0, 1, 0))
    vertices = []
    for i, center in enumerate(centers):
        tangent = (centers[min(i+1, len(centers)-1)] - centers[max(0, i-1)]).normalized()
        v = tangent.cross(reference).normalized()
        u = v.cross(tangent).normalized()
        ru, rv = radii[i] if isinstance(radii[i], tuple) else (radii[i], radii[i])
        for k in range(sides):
            a = math.tau*k/sides
            vertices.append(center + u*ru*math.cos(a) + v*rv*math.sin(a))
    last = len(vertices)-sides
    faces = [tuple(range(sides)), tuple(range(last, last+sides))]
    for base in range(0, last, sides):
        for k in range(sides):
            nxt = (k+1) % sides
            faces.append((base+k, base+nxt, base+sides+nxt, base+sides+k))
    mesh.solid(vertices, faces, material)


def crown_height(x, y):
    for a, b in zip(HEAD, HEAD[1:]):
        if y <= b[0]:
            t = max(0, (y-a[0])/(b[0]-a[0]))
            width, center, height = (a[j]+t*(b[j]-a[j]) for j in (1, 2, 3))
            return center + height*math.sqrt(max(.012, 1-(x/width)**2))
    return HEAD[-1][2]


def body_sculpt(group):
    mesh = Mesh()
    longitudinal(mesh, HEAD, 'dermis', 40)
    longitudinal(mesh, TORSO, 'dermis', 32)
    tube(mesh, [(0,.88,.45),(0,1.14,.43),(0,1.48,.44),(0,1.84,.57),(0,2.14,.59)],
         [.32,.25,.20,.23,.32], 'dermis')
    for sign in (-1, 1):
        def mirrored(coords):
            def point(x,y,z):
                bend = max(0,min(1,(-y-1.65)/1.8)) if sign<0 and x<1.17 else 0
                return (sign*(x+.21*bend), y+.19*bend, z)
            return [point(x,y,z) for x,y,z in coords]

        tube(mesh, mirrored([(.52,.84,.56),(.78,.82,.52),(.93,.61,.43),(1.05,.23,.34),
                             (1.25,-.23,.28),(1.30,-.42,.27),(1.35,-.61,.29),
                             (1.42,-.98,.25),(1.54,-1.43,.21)]),
             [.23,.255,.198,.163,.135,.152,.157,.14,.102], 'dermis')
        # Two radial tendons sit above each long, flattened four-digit palm.
        tube(mesh, mirrored([(1.53,-1.34,.21),(1.56,-1.49,.20),(1.61,-1.67,.17),(1.64,-1.79,.15)]),
             [(.11,.092),(.17,.105),(.205,.11),(.17,.079)], 'dermis')
        for k, (off, length, fan) in enumerate([(-.16,.49,-.18),(-.056,.69,-.055),(.063,.73,.072),(.163,.57,.20)]):
            x, y = 1.63+off, -1.74+.07*(k in (0,3))
            bend = .035 if sign == 1 else -.035
            tube(mesh, mirrored([(x,y,.16),(x+fan*.34,y-length*.30,.16),
                                 (x+fan*.77+bend,y-length*.65,.115),(x+fan,y-length*.88,.093),
                                 (x+fan+.023,y-length,.101)]),
                 [.070,.067,.060,.061,.034], 'dermis', 9)
        tube(mesh, mirrored([(.38,-1.05,.44),(.45,-1.30,.42),(.49,-1.58,.41),
                             (.52,-1.97,.38),(.55,-2.26,.40),(.56,-2.43,.415),
                             (.55,-2.58,.35),(.53,-2.82,.305),(.50,-3.06,.26),
                             (.52,-3.46,.20),(.56,-3.77,.18)]),
             [.251,.284,.25,.205,.161,.18,.157,.18,.154,.103,.098], 'dermis', 16)
        tube(mesh, mirrored([(.55,-3.69,.18),(.58,-3.85,.143),(.67,-4.03,.13),(.75,-4.15,.13)]),
             [.115,(.155,.132),(.19,.12),(.155,.095)], 'dermis')
        for k in range(3):
            off=(k-1)*.11
            tube(mesh, mirrored([(.70+off,-4.05,.13),(.79+off*1.30,-4.20,.105),
                                 (.86+off*1.45,-4.34+abs(off)*.65,.09)]), [.085,.072,.044], 'dermis')
        # The collar, rib arches and temple lines are fused beneath the skin.
        tube(mesh, mirrored([(.075,.78,.90),(.31,.86,.89),(.56,.91,.79),(.72,.84,.69)]),
             [.062,.086,.067,.048], 'dermis')
        for row in range(4):
            y=.58-row*.192
            tube(mesh, mirrored([(.09,y-.11,.87-row*.04),(.28,y,.907-row*.044),
                                 (.46,y+.05,.81-row*.049),(.595-row*.018,y+.06,.69-row*.043)]),
                 [.042,.053,.045,.031], 'dermis')
        for k in range(2):
            coords=[(.16+k*.13,2.86),(.23+k*.17,3.12),(.32+k*.16,3.41),(.31+k*.11,3.67)]
            tube(mesh, mirrored([(x,y,crown_height(x,y)-.014) for x,y in coords]),
                 [.035,.053,.050,.022], 'dermis')
    # A low nasal bridge without an external human nose.
    longitudinal(mesh, [(1.997,.071,1.105,.088),(2.055,.147,1.16,.14),
                        (2.12,.155,1.20,.161),(2.21,.108,1.254,.146),
                        (2.34,.084,1.304,.140),(2.49,.077,1.345,.092),
                        (2.60,.041,1.377,.043)], 'dermis', 24)
    for sign in (-1,1):
        # Subtle malar shelves give the broad orbit a tapered cheek below it.
        coords=[(.28,2.15),(.40,2.15),(.55,2.20),(.71,2.30),(.80,2.44)]
        tube(mesh,[(sign*x,y,crown_height(x,y)-.007) for x,y in coords],
             [.036,.052,.071,.066,.035],'dermis',12)
    obj = mesh.finish('S-07 • dermal sculpt', group, Role='PreservedSpecimen', ThermalNonCover=True)
    # Fuse the sculpting volumes into a watertight, editable silhouette. Retain
    # close face detail but limit the single skinned mesh's exported triangle count.
    bpy.context.view_layer.objects.active = obj
    remesh = obj.modifiers.new('Continuous skin', 'REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = .030
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    relax = obj.modifiers.new('Soften tissue junctions', 'SMOOTH')
    relax.factor, relax.iterations = .59, 3
    bpy.ops.object.modifier_apply(modifier=relax.name)
    obj.data.calc_loop_triangles()
    reducer = obj.modifiers.new('Retain anatomical contours', 'DECIMATE')
    reducer.ratio = min(1, 13400 / len(obj.data.loop_triangles))
    bpy.ops.object.modifier_apply(modifier=reducer.name)
    obj.data.materials.clear()
    obj.data.materials.append(MATERIALS['dermis'])
    for face in obj.data.polygons:
        face.use_smooth = True
    uv = obj.data.uv_layers.get('SkinUV') or obj.data.uv_layers.new(name='SkinUV')
    for loop in obj.data.loops:
        x,y,z=obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=((x+2.2)/4.4,(y+4.5)/8.7)
    obj.location = BAY + Vector((0, 0, BERTH))
    return obj


def ocular_details(group, skin):
    mesh = Mesh()

    def surface(x, y):
        hit, position, _, _ = skin.ray_cast((x,y,3.0),(0,0,-1),distance=5)
        assert hit, ('facial detail outside the sculpt',x,y)
        return position.z

    for sign in (-1, 1):
        def lid(theta, radius=1):
            c,s=math.cos(theta),math.sin(theta)
            x=.495+.395*c*radius
            y=2.45+(.198*c + .205*s*(.68+.32*abs(s)))*radius
            return Vector((sign*x,y,surface(sign*x,y)+.012))

        # A swept almond with a convex, ink-black cornea and a separate fleshy lid.
        count=30
        loops=[]
        for radius,lift in [(1,.007),(.86,.062),(.63,.108),(.36,.140),(.065,.154)]:
            loops.append([lid(math.tau*k/count,radius)+UP*lift for k in range(count)])
        face_list=[]
        for j in range(len(loops)-1):
            for k in range(count):
                nxt=(k+1)%count
                face_list.append((j*count+k,j*count+nxt,(j+1)*count+nxt,(j+1)*count+k))
        face_list.append(tuple(range((len(loops)-1)*count,len(loops)*count)))
        points=[p for ring in loops for p in ring]
        for f in face_list:
            seq=[points[i] for i in f]
            if (seq[1]-seq[0]).cross(seq[2]-seq[0]).z<0:
                seq.reverse()
            mesh.plate(seq,'cornea',[(p.x,p.y) for p in seq])
        for start,end,rad in [(0,math.pi,.044),(math.pi,math.tau,.031)]:
            eyelid = [lid(start+(end-start)*i/18,1.035)+UP*.024 for i in range(19)]
            tube(mesh,eyelid,[rad*(.65+.35*math.sin(math.pi*i/18)) for i in range(19)],'lid',8)
        fold=[lid(.12+(math.pi-.29)*i/16,1.21)+UP*.003 for i in range(17)]
        tube(mesh,fold,[.012+.014*math.sin(i*math.pi/16) for i in range(17)],'lid',7)
        # A second fine crease and sensory pores define the cheek and temple.
        for k in range(3):
            x=.69+k*.067
            y=2.77+k*.07
            z=crown_height(x,y)
            tube(mesh,[(sign*(x-.025),y-.020,z+.003),(sign*x,y,z+.013),(sign*(x+.034),y+.026,z+.004)],
                 [.006,.024,.005],'clay',7)
        # A pair of comma-shaped breathing slots tucked into a low nasal saddle.
        nostril=[]
        for x,y in [(.041,2.078),(.066,2.070),(.094,2.079),(.108,2.102)]:
            nostril.append(Vector((sign*x,y,surface(sign*x,y)+.003)))
        tube(mesh,nostril,[.004,.016,.013,.004],'sulcus',10)
        rim=[p+Vector((sign*.012,.013,.008)) for p in nostril]
        tube(mesh,rim,[.004,.010,.010,.003],'lid',8)
    mouth=[]
    for i in range(15):
        x=(i-7)*.033
        y=1.934+.034*(abs(x)/.231)**1.7+.003*math.sin(17*x)
        mouth.append(Vector((x,y,surface(x,y)+.005)))
    tube(mesh,mouth,[.005+.011*math.sin(i*math.pi/14) for i in range(15)],'clay',7)
    tube(mesh,[p+Vector((0,-.027,-.006)) for p in mouth],
         [.004+.014*math.sin(i*math.pi/14) for i in range(15)],'lid',8)
    obj=mesh.finish('S-07 • corneas, lids and facial folds',group,Role='SpecimenDetail',ThermalNonCover=True)
    for face in obj.data.polygons:
        face.use_smooth=True
    obj.location=BAY+Vector((0,0,BERTH))


def build(group):
    skin = body_sculpt(group)
    ocular_details(group, skin)
    hearing_fans(group)


def prepare_skin(folder):
    """Bake the creature's bilateral crest markings, shoulder whorls and skin grain."""
    rng = np.random.default_rng(7151)
    height,width=768,448
    row,col=np.mgrid[:height,:width]
    x=(col+.5)/width*4.4-2.2
    y=(1-(row+.5)/height)*8.7-4.5
    ax=np.abs(x)
    def field(step):
        lattice=rng.uniform(-1,1,(height//step+2,width//step+2))
        ix,iy=col//step,row//step
        fx,fy=(col%step)/step,(row%step)/step
        fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
        return ((lattice[iy,ix]*(1-fx)+lattice[iy,ix+1]*fx)*(1-fy)+
                (lattice[iy+1,ix]*(1-fx)+lattice[iy+1,ix+1]*fx)*fy)
    cloud, fine, grain=field(35),field(8),rng.uniform(-1,1,(height,width))
    socket=np.exp(-((ax-.53)/.38)**2-((y-2.48-.17*(ax-.53))/.32)**2)
    neck=np.exp(-((y-1.4)/.28)**2)
    perimeter=np.clip((ax-.36)/.61,0,1)
    crown=np.exp(-((y-3.07)/.78)**4)*perimeter
    gray=np.array([152,164,154])[None,None,:]
    color=gray+(cloud*9+fine*4+grain*2.8)[:,:,None]
    color-=socket[:,:,None]*[41,44,31]
    color-=crown[:,:,None]*[19,16,12]
    color-=neck[:,:,None]*[11,6,5]
    relief=fine*.15+grain*.16
    # Paired broken crescents follow the skull over the temples. The bands
    # taper into the crown, where pinprick cream chromatophores replace them.
    for i in range(5):
        center=2.64+i*.235+.57*(ax-.6)-.95*(ax-.67)**2
        dist=y-center+.018*fine+.035*cloud
        spread=np.exp(-((ax-(.76-i*.035))/.23)**2)
        stripe=np.exp(-(dist/(.026+.006*i))**2)*spread
        color-=stripe[:,:,None]*[40,43,32]
        ridge=np.exp(-((dist-.052)/.024)**2)*spread
        color+=ridge[:,:,None]*[13,10,4]
        relief+=ridge*.28-stripe*.29
    for i in range(4):
        center=.78-i*.22+.17*np.sin(ax*4.4)
        rib=np.exp(-((y-center)/.037)**2)*np.exp(-((ax-.39)/.22)**2)
        color-=rib[:,:,None]*[17,18,16]
        relief-=rib*.19
    # Vary freckle size and color while keeping the interior of the face pale.
    for sign in (-1,1):
        for k in range(158):
            cx=sign*rng.uniform(.36,1.01)
            cy=rng.uniform(2.53,3.75)
            radius=rng.uniform(1,2.6)
            px,py=int((cx+2.2)/4.4*width),int((1-(cy+4.5)/8.7)*height)
            reach=7
            rr,cc=np.mgrid[-reach:reach+1,-reach:reach+1]
            spot=np.exp(-(rr*rr+cc*cc)/radius**2)
            region=np.s_[py-reach:py+reach+1,px-reach:px+reach+1]
            pigment=rng.choice([-.95,-.72,.75])
            color[region]+=spot[:,:,None]*pigment*np.array([33,29,22])
            relief[region]+=spot*.11
    dy,dx=np.gradient(relief)
    normal=np.stack((-dx,-dy,np.ones_like(x)),axis=-1)
    normal/=np.linalg.norm(normal,axis=-1)[:,:,None]
    mat=MATERIALS['dermis']
    nodes,links=mat.node_tree.nodes,mat.node_tree.links
    shader=nodes.get('Principled BSDF')
    for suffix,pixels in [('pigment',color),('pores',(normal*.5+.5)*255)]:
        filename=folder/f'S07 integument {suffix}.png'
        write_png(filename,np.clip(pixels,0,255))
        img=bpy.data.images.load(str(filename))
        tex=nodes.new('ShaderNodeTexImage')
        tex.image=img
        if suffix=='pigment':
            links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        else:
            img.colorspace_settings.name='Non-Color'
            n=nodes.new('ShaderNodeNormalMap')
            n.inputs['Strength'].default_value=.35
            links.new(tex.outputs['Color'],n.inputs['Color'])
            links.new(n.outputs['Normal'],shader.inputs['Normal'])
        img.pack()


def hearing_fans(group):
    """Folded external sensory membranes with three ribs and a recessed concha."""
    mesh=Mesh()
    for sign in (-1,1):
        # Raised, swept back from each side of the cranium, free at the tips.
        root=Vector((sign*.89,2.73,.71))
        border=[(.88,2.54,.74),(1.04,2.68,.95),(1.23,3.02,1.02),(1.32,3.46,.98),
                (1.16,3.31,.82),(1.26,3.65,.81),(1.08,3.45,.71),(1.11,3.79,.65),
                (.91,3.52,.55),(.82,3.03,.53)]
        ring=[Vector((sign*x,y,z)) for x,y,z in border]
        hub=Vector((sign*1.09,2.99,.77))
        for i,a in enumerate(ring):
            b=ring[(i+1)%len(ring)]
            triangle=[a,b,hub]
            mesh.loft([p-UP*.055 for p in triangle],triangle,'membrane')
        for j,tip in enumerate((3,5,7)):
            end=ring[tip]
            mid=hub.lerp(end,.47)+Vector((sign*.015,0,.032))
            tube(mesh,[root,hub,mid,end],[.04,.045-j*.004,.028,.008],'lid',9)
        for j in range(3):
            t=j*.085
            points=[(sign*(.96+t),2.70+t,.837),(sign*(1.09+t*.56),2.84+t,.91),
                    (sign*(1.12+t*.23),2.96+t,.90)]
            tube(mesh,points,[.009,.023,.008],'sulcus',7)
    obj=mesh.finish('S-07 • paired sensory fans',group,Role='SpecimenDetail',ThermalNonCover=True)
    for f in obj.data.polygons:
        f.use_smooth=True
    obj.location=BAY+Vector((0,0,BERTH))
