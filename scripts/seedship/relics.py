"""The seedship's live specimens, optical spine, observatory and threshold furniture."""
import math
import random
from mathutils import Vector
from form import Mesh, UP, strip, lancet, illuminated_rib, collar, crystal, path

TAU=math.tau


def radial(x,y,z,r,a):
    return Vector((x+r*math.cos(a),y+r*math.sin(a),z))


def orbit(m,x,y,z,radius,tilt,azimuth,mat,width,start=0,end=TAU):
    # A plane tipped about its horizontal diameter makes an armillary gimbal.
    pts=[]
    for i in range(49):
        t=start+(end-start)*i/48
        u,v=radius*math.cos(t),radius*math.sin(t)
        pts.append((x+u*math.cos(azimuth)-v*math.cos(tilt)*math.sin(azimuth),
                    y+u*math.sin(azimuth)+v*math.cos(tilt)*math.cos(azimuth),z+v*math.sin(tilt)))
    path(m,pts,width,mat,6)


def glyph(m,origin,right,up,size,serial,mat='brass'):
    """A tiny inscription assembled from a seed, fork and one to four count marks."""
    p,r,v=Vector(origin),Vector(right)*size,Vector(up)*size
    def line(a,b):
        m.rod(p+r*a[0]+v*a[1],p+r*b[0]+v*b[1],size*.032,mat,4)
    for a,b in [((0,0),(.22,.28)),((.22,.28),(0,.62)),((0,.62),(-.2,.28)),((-.2,.28),(0,0)),
                ((0,.62),(0,1.15)),((0,.83),(.25,1.06))]:
        line(a,b)
    for i in range(1+serial%4):
        line((.34+i*.16,.05),(.34+i*.16,.18+(i%2)*.15))


def heart(stable,detail):
    x,y=0,12
    m=Mesh()
    collar(m,(x,y,0),[(6.8,.02),(7.4,.45),(6.95,.78),(6.65,.85),(5.8,1.58),(5.65,1.72),(4.35,1.78)],
           ['amethyst','edge','brass','amethyst','night','edge'],10)
    crystal(m,(x,y,1.6),2.65,34.6,.21,('mint','green','white','olive'))
    for k in range(6):
        a=k*TAU/6+math.pi/6
        n=Vector((math.cos(a),math.sin(a),0))
        pts=[radial(x,y,1.0,6.34,a),radial(x,y,4.9,3.84,a),radial(x,y,9.7,2.58,a),
             radial(x,y,17.6,3.1,a),radial(x,y,23,2.68,a),radial(x,y,29.6,3.3,a),
             radial(x,y,33,5.8,a),radial(x,y,35.6,9.1,a)]
        for j,(start,end) in enumerate(zip(pts,pts[1:])):
            illuminated_rib(m,start,end,1.45 if j!=3 else 1.18,.82,n, j in (0,3,5))
        for h,r in [(3.5,4.34),(16.8,3.1),(27.3,3.15)]:
            p=radial(x,y,h,r,a)
            m.rod(p-n*.17,p+n*.58,.60,'night',6,.46)
            m.rod(p+n*.56,p+n*.66,.34,'brass',6)
        glyph(m,radial(x,y,1.03,6.3,a),(-n.y,n.x,0),n*.49+UP*.87,.55,k)
    m.finish('Luminous spine • six petal load paths',stable,(0,12,0),Role='StableFrame')
    m=Mesh()
    for z,r in [(5,2.82),(12,2.91),(21,2.88),(31,3.12)]:
        orbit(m,x,y,z,r,.10,z*.21,'brass',.093)
    for k in range(3):
        pts=[radial(x,y,3+i*.55,2.22+.18*math.sin(i*.23),k*TAU/3+i*.096) for i in range(57)]
        path(m,pts,.080,'white')
    m.finish('Spine • trihelical capillaries',detail,(0,12,0),Role='OpticalDressing',ThermalNonCover=True)


def beacon(group,name,x,y,z,height,radius):
    m=Mesh()
    collar(m,(x,y,z),[(radius*1.55,0),(radius*1.68,.27),(radius*1.32,.83),(radius*1.23,.87),
                       (radius,1.22),(radius*.88,1.3)],['night','amethyst','brass','edge','night'],8)
    crystal(m,(x,y,z+1.15),radius*.71,height-1.15,.24,('olive','mint','green','white'))
    for k in range(4):
        a=k*TAU/4+.38
        p=radial(x,y,z+.83,radius*1.15,a)
        q=radial(x,y,z+height*.60,radius*.60,a)
        strip(m,p,q,radius*.45,.38,(math.cos(a),math.sin(a),0),'amethyst','edge',.18)
    m.finish(name,group,(x,y,z),Role='IndependentDressing',ThermalNonCover=True)


def seedbank(group):
    for i,(x,y) in enumerate([(65,28),(70,14),(73,-1)]):
        # The three standing reliquaries live on the ground deck below the
        # observation gallery. Leave the adjacent side exit aisle clear.
        if i==2:
            x,y=64,-13
        m=Mesh()
        collar(m,(x,y,0),[(3.22,.02),(3.4,.33),(2.95,.59),(2.81,.73),(2.39,1.23),(2.4,1.36),(2.09,1.5)],
               ['amethyst','edge','brass','amethyst','mint','night'],10)
        # A lightly tinted faceted ampoule reveals the testa and its two
        # rolled cotyledons behind the external metal capture cage.
        glassrings=[]
        for radius,h in [(1.45,1.54),(2.02,2.78),(2.02,7.29),(1.25,8.85),(.32,9.55)]:
            glassrings.append([radial(x,y,h,radius,k*TAU/10+.17) for k in range(10)])
        for lo,hi in zip(glassrings,glassrings[1:]):
            for k in range(10):
                n=(k+1)%10
                m.plate([lo[k],lo[n],hi[n],hi[k]],'glass')
        for j in (-1,1):
            rot=.52+i*.75+(math.pi if j==-1 else 0)
            side=Vector((-math.sin(rot),math.cos(rot),0))
            outline=[radial(x,y,z,r,rot+turn) for z,r,turn in [(3.53,.16,0),(4.49,.74,.18),(5.84,1.11,.44),(7.53,.64,.60)]]
            for n,(a,b) in enumerate(zip(outline,outline[1:])):
                vein=side*(.20,.43,.31)[n]
                mid=a.lerp(b,.5)+vein*.12
                shell=[a,mid+vein,b,mid-vein]
                m.loft([p-Vector((0,0,.055)) for p in shell],shell,'olive' if n==0 else 'green')
                strip(m,a,b,.071,.063,(math.cos(rot),math.sin(rot),0),'brass')
        # Inner embryo is suspended inside an open, plantlike braided cage.
        crystal(m,(x,y,4.10),.78,2.62+i*.21,.42,('amber','brass','green','amber'))
        for j in range(5):
            a=j*TAU/5
            radialpts=[radial(x,y,1.3,1.89,a),radial(x,y,3.1,2.30,a+.16),
                       radial(x,y,7.1,2.13,a+.42),radial(x,y,9.65,.87,a+.72),
                       radial(x,y,10.13,.24,a+.63)]
            for k,(p,q) in enumerate(zip(radialpts,radialpts[1:])):
                strip(m,p,q,.36 if k!=1 else .20,.27,(math.cos(a),math.sin(a),0),'edge' if j%2 else 'brass')
            curve=[radial(x,y,1.6+k*.16,1.68*math.sin(math.pi*(k+5)/58)+.12,a+k*.055) for k in range(48)]
            path(m,curve,.060,'mint')
        for h,r in [(2.2,2),(7.8,1.99),(9.6,.75)]:
            orbit(m,x,y,h,r,.11,i*.5,'brass',.105)
        m.finish(f'Seed vault {i+1:02d} • suspended cultivar',group,(x,y,0),Role='IndependentDressing',ThermalNonCover=True)


def orrery(group):
    x,y=-64,22
    m=Mesh()
    collar(m,(x,y,0),[(3.75,.02),(4.1,.25),(3.73,.57),(2.82,.64),(1.43,1.35),
                       (1.0,2.42),(1.75,2.80),(2,3.05)],['amethyst','edge','brass','deck','amethyst','edge','night'],10)
    crystal(m,(x,y,4.80),.75,2.64,.20,('white','green','mint'))
    for i,(r,tilt,az) in enumerate([(4.35,.97,.12),(3.78,1.47,1.2),(3.16,.53,1.9),(2.52,1.4,2.9)]):
        orbit(m,x,y,6.2,r,tilt,az,'edge' if i==0 else 'brass',.16 if i==0 else .10)
        for j in range(5):
            t=j*TAU/5+i*.35
            u,v=r*math.cos(t),r*math.sin(t)
            p=(x+u*math.cos(az)-v*math.cos(tilt)*math.sin(az),y+u*math.sin(az)+v*math.cos(tilt)*math.cos(az),6.2+v*math.sin(tilt))
            crystal(m,p,.17,.52,0,('amber','white'))
    m.finish('West concourse • four-axis ephemeris',group,(x,y,0),Role='IndependentDressing',ThermalNonCover=True)


def reader(group,x,y,z,sign,index):
    """Recessed navigation instrument with concentric tracks and an encoded key."""
    m=Mesh()
    collar(m,(x,y,z),[(1.3,0),(1.43,.18),(.84,.45),(.48,2.65),(1.07,3.1)],
           ['amethyst','edge','amethyst','brass'],8)
    m.block(x-2.3,x+2.3,y-1.44,y+1.44,z+3.02,z+3.34,'amethyst',.58)
    m.block(x-2.13,x+2.13,y-1.28,y+1.28,z+3.34,z+3.42,'night',.55)
    for r in (.32,.60,.86):
        orbit(m,x-.48,y,z+3.456,r,0,0,'mint' if r==.60 else 'brass',.044,0,TAU*.89)
    for j in range(5):
        p=Vector((x+.72,y-.83+j*.33,z+3.46))
        strip(m,p,p+Vector((.28+.13*(j%3),0,0)),.066,.04,UP,'amber' if j==index%5 else 'mint')
    glyph(m,(x-1.94,y-.55,z+3.46),(1,0,0),(0,1,0),.70,index)
    m.finish(f'{sign} reader {index:02d} • optical dial',group,(x,y,z),Role='IndependentDressing',ThermalNonCover=True)


def furnish(stable,detail):
    heart(stable,detail)
    seedbank(detail)
    orrery(detail)
    for i,(x,y,z,side) in enumerate([(64,18,16,'Vault'),(-62,16,16,'Concourse'),(27,37.8,16,'Crossover'),
                                     (-69,15,0,'Ephemeris'),(61,22,0,'Embryology')]):
        reader(detail,x,y,z,side,i+1)
    chart_table(detail)
    forecourt(stable)
    for sign in (-1,1):
        beacon(detail,('West' if sign<0 else 'East')+' threshold sentinel',sign*22.8,-65.2,-.28,8.35,2.26)
        for j,(x,y) in enumerate([(22,-31),(29,-8),(32,12)]):
            beacon(detail,f'Nave lantern {sign:+d} / {j+1}',sign*x,y,0,4.3 if j!=1 else 3.65,1.41)
    # Cleaved fragments sit to either side of the impact walk-through.
    m=Mesh()
    rng=random.Random(124)
    for j in range(32):
        x=rng.choice((52,72))+rng.uniform(-2.8,2.8)
        y=rng.uniform(-57,-46)
        floor=0 if y>-50 else -2.33
        a=rng.uniform(0,TAU)
        r=rng.uniform(.25,1.35)
        pts=[(x+r*math.cos(a+k*TAU/5)*rng.uniform(.69,1.22),y+r*.62*math.sin(a+k*TAU/5)) for k in range(5)]
        m.loft([(u,v,floor) for u,v in pts],[(u+.15,v+.17,floor+r*rng.uniform(.28,.91)) for u,v in pts],'pearl')
    m.finish('Forward impact • spalled nacre',detail,(62,-52,0),Role='Debris',ThermalNonCover=True)


def forecourt(group):
    """Heavy flared staircase cheeks, beveled socket beds and tiered light slots."""
    for sign in (-1,1):
        m=Mesh()
        xy=[(sign*x,y) for x,y in [(17.4,-71.7),(23.1,-71.7),(28.6,-68.7),(29.7,-63.4),
                                    (25.4,-59.0),(18.7,-58.9),(18.3,-62.4),(20.2,-65.3)]]
        cx,cy=sign*23.1,-64.8
        def ring(f,z):
            return [(cx+(x-cx)*f,cy+(y-cy)*f,z) for x,y in xy]
        for low,high,r0,r1,mat in [(-2.42,-1.98,1.0,1.0,'night'),(-1.98,-.56,1,.86,'amethyst'),
                                    (-.56,-.42,.86,.86,'brass'),(-.42,-.28,.86,.82,'deck')]:
            m.loft(ring(r0,low),ring(r1,high),mat)
        for j in range(3):
            a=(sign*(21.1+j*1.13),-70.82+j*.1,-1.3)
            b=(sign*(21.9+j*1.13),-70.82+j*.1,-1.3)
            strip(m,a,b,.28,.15,(0,-1,0),'mint')
        m.finish(f'Portal stylobate {sign:+d} • sentinel socket',group,(cx,cy,-2.4),Role='StableFrame')


def chart_table(group):
    """Two inclined plates with an original polar chart, leaf readers and etched coordinates."""
    for sign in (-1,1):
        x,y=sign*65,3
        m=Mesh()
        collar(m,(x,y,16),[(3.10,0),(3.3,.23),(2.92,.48),(1.43,.71),(1.14,1.86),
                             (2.42,2.44),(3.66,2.71),(3.62,2.94),(3.38,3.01)],
               ['amethyst','edge','brass','deck','amethyst','night','edge','brass'],12)
        collar(m,(x,y,19),[(3.22,0),(3.22,.08)],['night'],16)
        for k,r in enumerate([.54,1.16,1.8,2.38,2.93]):
            orbit(m,x,y,19.116,r,0,0,'brass' if k%2==0 else 'mint',.032,.11+k*.64,5.92+k*.64)
        for j in range(32):
            a=j*TAU/32
            m.rod(radial(x,y,19.12,2.78 if j%4 else 2.60,a),radial(x,y,19.12,2.99,a),.030,'brass',4)
        pts=[(-2.31,.08),(-1.64,.47),(-1.33,1.16),(-.89,.87),(-.35,.15),(.57,-.11),(.90,-.83),(1.80,-1.43)]
        for (u,v),(uu,vv) in zip(pts,pts[1:]):
            m.rod((x+u,y+v,19.15),(x+uu,y+vv,19.15),.044,'green',5)
            crystal(m,(x+u,y+v,19.14),.12,.18,0,('white','amber'))
        for j in range(4):
            a=j*TAU/4+.34
            p=radial(x,y,18.1,2.97,a)
            glyph(m,p,(-math.sin(a),math.cos(a),0),(0,0,1),.60,j)
        m.finish(f'Celestial index {sign:+d} • engraving and gnomon',group,(x,y,16),Role='IndependentDressing',ThermalNonCover=True)
