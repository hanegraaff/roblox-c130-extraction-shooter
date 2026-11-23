"""Playable floors, double-height hall, balcony colonnade and twin gallery stairs."""
from math import ceil, cos, sin, tau
from mathutils import Vector
from form import Mesh, UP, collar, illuminated_rib, lancet, strip
from hull import RIM


def deckpoly(m,xy,base,top):
    m.prism(xy,base,top,'amethyst')
    # Split finishing course from the underside so the fascia has real depth.
    m.surfaces[-len(xy)-1]='deck'


def railing(m,a,b,ornate=True):
    a,b=Vector(a),Vector(b)
    rise=Vector((0,0,2.85))
    diff=b-a
    count=max(1,round(diff.length/4.1))
    strip(m,a+rise,b+rise,.37,.36,UP,'edge','brass')
    strip(m,a+rise+UP*.19,b+rise+UP*.19,.18,.08,UP,'brass')
    strip(m,a+UP*.46,b+UP*.46,.20,.17,UP,'amethyst')
    for k in range(count+1):
        p=a+diff*k/count
        strip(m,p,p+rise,.30,.27,(0,-1,0) if abs(diff.x)>abs(diff.y) else (1,0,0),'amethyst','edge')
        if k<count and ornate:
            q=p+diff/count
            mid=p.lerp(q,.5)
            for start,end in [(p+UP*1.46,mid+UP*.58),(mid+UP*.58,q+UP*1.46),
                              (q+UP*1.46,mid+UP*2.58),(mid+UP*2.58,p+UP*1.46)]:
                m.rod(start,end,.085,'brass',4)


def decks(stable,trim):
    m=Mesh()
    # The shell has a shallow front notch. Triangular floor fans guarantee
    # correct normals and support, including along that non-convex lip.
    boundary=[(99*(1 if x>0 else -1) if abs(y)==12.8 else x,-60 if y< -56 and abs(x)<=23 else y) for x,y,_ in RIM]
    for i,(x,y) in enumerate(boundary):
        xx,yy=boundary[(i+1)%len(boundary)]
        deckpoly(m,[(0,12),(x,y),(xx,yy)],-2.38,0)
    m.finish('Landing raft • polygonal ground deck',stable,Role='WalkableFloor')

    m=Mesh()
    for j in range(6):
        # Six wide threshold steps span the recessed apron, ending at deck zero.
        y=-72+j*2
        z=-2.4+(j+1)*.4
        m.block(-17.0-j*.36,17.0+j*.36,y,y+2,-2.44,z,'deck',.12)
        for sign in (-1,1):
            m.block(sign*13.0-.13,sign*13.0+.13,y+.18,y+1.88,z+.008,z+.035,'mint')
        m.block(-13,13,y+.08,y+.17,z+.008,z+.029,'brass')
    m.finish('South threshold • six fan steps',stable,(0,-66,-2.4),Role='WalkableEntry')
    for sign,label in [(-1,'Port'),(1,'Starboard')]:
        # The side portals meet the surrounding grade with a descending sill.
        m=Mesh()
        m.loft([(sign*99,-10.3,-2.43),(sign*104,-10.3,-2.43),(sign*104,10.3,-2.43),(sign*99,10.3,-2.43)],
               [(sign*99,-10.3,.012),(sign*104,-10.3,-2.29),(sign*104,10.3,-2.29),(sign*99,10.3,.012)],'deck')
        m.finish(label+' • side exit wedge',stable,(sign*101.5,0,-1),Role='WalkableEntry')
        m=Mesh()
        # Leave a ten-stud-wide stairwell. The inner gallery starts at the
        # landing and the outer tongue extends toward the foot of the stairs.
        pts=[(51,-15),(61,-15),(61,-39),(64,-39),(73,-25),(77,-9),
             (77,13),(66,32),(54,40),(42,40),(42,-15)]
        deckpoly(m,[(sign*x,y) for x,y in pts],14.6,16)
        m.finish(label+' • gallery and twelve-stud landing',stable,(sign*58,3,16),Role='WalkableGallery')
        stair=Mesh()
        for j in range(24):
            y,z=-39+j,16*(j+1)/24
            stair.block(sign*56-5,sign*56+5,y,y+1,z-.85,z,'deck')
            stair.block(sign*56-4.92,sign*56+4.92,y+.07,y+.14,z+.004,z+.024,'brass')
        for dx in (-5.17,5.17):
            a,b=Vector((sign*56+dx,-39,.22)),Vector((sign*56+dx,-15,16))
            strip(stair,a-UP*.28,b-UP*.28,.70,1.42,UP,'amethyst','edge')
            railing(stair,a,b)
        stair.finish(label+' • ascending flight, 24 treads',stable,(sign*56,-27,8),Role='WalkableStair')
        m=Mesh()
        for a,b in [((42,-15),(50.8,-15)),((42,-15),(42,25)),((61.2,-15),(61.2,-39)),
                    ((61.2,-39),(64,-39)),((64,-39),(73,-25)),((73,-25),(77,-9)),((77,-9),(77,13)),
                    ((77,13),(66,32)),((66,32),(54,40)),((54,40),(42,40))]:
            p,q=Vector((sign*a[0],a[1],16)),Vector((sign*b[0],b[1],16))
            railing(m,p,q)
            stripe=UP*1.01
            strip(m,p-stripe,q-stripe,.35,.24,UP,'edge')
        m.finish(label+' • diamond gallery balustrade',stable,(sign*59,4,16),Role='StableFrame')
        for k,(x,y) in enumerate([(46,-9),(70,-19),(47,17),(68,17),(50,34)]):
            column(stable,sign*x,y,k,label)
    m=Mesh()
    deckpoly(m,[(-42,25),(42,25),(42,40),(-42,40)],14.6,16)
    for y in (25.0,40.0):
        railing(m,(-42,y,16),(42,y,16))
        strip(m,(-42,y,15.05),(42,y,15.05),.47,.4,UP,'brass')
        for i in range(12):
            a,b=Vector((-41+i*6.9,y-.06,15.3)),Vector((-35.4+i*6.9,y-.06,15.3))
            lancet(m,a,b,.29,(0,-1,0),'mint')
    m.finish('North crossover • fifteen-stud deck',stable,(0,32.5,16),Role='WalkableGallery')
    for i,x in enumerate((-28,0,28)):
        column(stable,x,32.5,i,'Crossover')
    # A fallen hull flake bridges the raised raft at the original impact.
    m=Mesh()
    pts=[(57.3,-60.1),(65.9,-59.7),(67.3,-57.8),(67.0,-50.46),(56.8,-52.56),(56.1,-57.3)]
    m.loft([(x,y,-2.42) for x,y in pts],[(x,y,min(.035,-2.26+(y+60.1-(x-57.3)*.18)*.322)) for x,y in pts],'pearl')
    m.finish('Impact • fallen sill plate',stable,(61.7,-55.3,-1.1),Role='WalkableEntry')
    floor_inlay(trim)


def column(group,x,y,k,label):
    m=Mesh()
    collar(m,(x,y,0),[(2.35,.01),(2.45,.35),(1.89,.78),(1.54,.91)],['amethyst','edge','brass'],8)
    for dx in (-1,1):
        pts=[Vector((x+dx*1.12,y,.73)),Vector((x+dx*.65,y,5.8)),Vector((x+dx*1.48,y,11.5)),Vector((x+dx*3.55,y,14.65))]
        for a,b,w in zip(pts,pts[1:],(1.58,1.2,1.12)):
            illuminated_rib(m,a,b,w,.88,(0,-1,0))
    m.finish(f'{label} • bifurcating pier {k+1:02d}',group,(x,y,0),Role='StableFrame')


def floor_inlay(group):
    m=Mesh()
    # Interlocking field plates and axial runway paths keep the deck legible at
    # eye height. Trace the lines on the surface with shallow strips.
    for sign in (-1,1):
        for off,mat,width in [(0,'brass',.16),(.52,'night',.5),(.52,'mint',.13)]:
            pts=[(sign*(10+off),-58,.035+(mat=='mint')*.035),(sign*(10+off),-23,.035+(mat=='mint')*.035),
                 (sign*(14.5+off),-13,.035+(mat=='mint')*.035),(sign*(14.5+off),9,.035+(mat=='mint')*.035),
                 (sign*(9.9+off),17,.035+(mat=='mint')*.035),(sign*(9.9+off),43,.035+(mat=='mint')*.035)]
            for a,b in zip(pts,pts[1:]):
                strip(m,a,b,width,.045,UP,mat)
        for k in range(22):
            y=-56+k*2.7
            strip(m,(sign*9.1,y,.035),(sign*(8.42 if k%4==0 else 8.8),y+.14,.035),.085,.04,UP,'brass')
    for x in range(-80,81,10):
        for y in range(-40,46,10):
            if abs(x)>66 and abs(y)>27:
                continue
            # Gold witness diamonds pick out the dark expansion seams.
            a,b=Vector((x,y,.020)),Vector((x+8.6,y,.020))
            strip(m,a,b,.075,.025,UP,'night')
            strip(m,a,a+Vector((0,8.6,0)),.075,.025,UP,'night')
            lancet(m,a-UP*.005,a+Vector((.92,0,0)),.18,UP,'brass',.034)
    for r in (8.4,9.1,11.8):
        for k in range(48):
            a,b=k*tau/48,(k+.87)*tau/48
            strip(m,(r*cos(a),12+r*sin(a),.065),(r*cos(b),12+r*sin(b),.065),.13,.04,UP,'brass' if r!=9.1 else 'mint')
    m.finish('Deck • navigation filaments and survey inlays',group,Role='SurfaceDressing',ThermalNonCover=True)


def vaulting(group,skins,frame):
    """Set the arch crowns against the actual inner face of the sloping roof."""
    from mathutils.bvhtree import BVHTree
    verts,polys=[],[]
    for o in [*skins.objects,*frame.objects]:
        start=len(verts)
        verts.extend(v.co+o.location for v in o.data.vertices)
        polys.extend([start+i for i in f.vertices] for f in o.data.polygons)
    tree=BVHTree.FromPolygons(verts,polys)
    def underside(x,y):
        p=tree.ray_cast((x,y,4),(0,0,1),42)[0]
        assert p is not None,(x,y)
        return p.z-.73
    for rank,(y,half) in enumerate([(-42,35),(-21,41),(7,41),(42,40)]):
        for sign in (-1,1):
            m=Mesh()
            floor=0
            if y==42:
                half=32
            xy=[(sign*half,y),(sign*(half-2.1),y+.45),(sign*(half-5.2),y+1.45),
                (sign*(half-11),y+2.8),(sign*(half*.38),y+4.1),(sign*.38,y+5.3)]
            # The central two bases sit just inside the gallery. The arch splits
            # into two blades beneath the ceiling, like the central spine.
            heights=[floor+.22,6.25,13.0]+[underside(x,yy)-.40 for x,yy in xy[3:]]
            pts=[Vector((x,yy,z)) for (x,yy),z in zip(xy,heights)]
            collar(m,(*xy[0],0),[(2.95,.015),(3.14,.31),(2.8,.57),(2.47,.74)],
                   ['amethyst','edge','brass'],8)
            for j,(a,b) in enumerate(zip(pts,pts[1:])):
                u=(b-a).normalized()
                inward=Vector((-sign*.64,-.2,-.75)) if j>=2 else Vector((-sign,-.38,.14))
                illuminated_rib(m,a,b,[3.5,2.92,2.66,2.22,1.84][j],1.54 if j<3 else 1.06,inward,True)
                secondary=Vector((sign*.81,1.31,0))
                strip(m,a+secondary,b+secondary,1.02,.76,inward,'amethyst','edge')
                if j in (1,2):
                    for k in range(3):
                        t=.2+k*.24
                        start=a.lerp(b,t)
                        strip(m,start,start+secondary, .27,.27,inward,'brass')
            # Openwork spur branches away at the spring of the main arch.
            fork=pts[2]
            end=Vector((sign*(half-10),y+8.4,underside(sign*(half-10),y+8.4)-.38))
            mid=fork.lerp(end,.55)+Vector((sign*.8,1,.27))
            strip(m,fork,mid,1.25,.82,(0,-1,-.2),'edge','amethyst')
            illuminated_rib(m,mid,end,.88,.65,(0,-1,-.2))
            m.finish(f'Nave vault {rank+1} / {sign:+d} • forked arch',group,pts[0],Role='StableFrame')
