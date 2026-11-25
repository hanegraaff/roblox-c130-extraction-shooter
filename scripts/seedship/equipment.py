"""Recovery furniture and freestanding alien machines, authored in floor-local studs."""
import math
from mathutils import Vector
from diagnostics import display
from form import Mesh, UP, collar, crystal, illuminated_rib, path, strip
from relics import glyph
from specimen import BAY, BERTH

TAU = math.tau


def install(mesh, group, name, origin, kind):
    obj = mesh.finish(name, group, Role='IndependentDressing', ThermalNonCover=True, Equipment=kind)
    obj.location = origin
    return obj


def loop(mesh, center, u, v, inner, outer, depth, material, count=32, start=0, end=TAU):
    """Annular casting, optionally an isolated contact segment."""
    center, u, v = Vector(center), Vector(u).normalized(), Vector(v).normalized()
    axis = u.cross(v).normalized()
    points = []
    for i in range(count+1):
        angle = start+(end-start)*i/count
        direction = u*math.cos(angle)+v*math.sin(angle)
        points.extend([center+direction*r+axis*h for r,h in
                       [(inner,-depth/2),(outer,-depth/2),(outer,depth/2),(inner,depth/2)]])
    faces = []
    for i in range(count):
        first = i*4
        for j in range(4):
            k=(j+1)%4
            face=(first+j,first+k,first+4+k,first+4+j)
            # Wind each side according to its radial or axial role.
            faces.append(face[::-1])
    if end-start < TAU-.0001:
        faces.extend([(0,1,2,3),(count*4+3,count*4+2,count*4+1,count*4)])
    # Each wall has its own normal. Using the shape centroid to orient the
    # concave inner surface of a ring would turn that surface inside out.
    for face in faces:
        mesh.plate([points[i] for i in face],material,[(0,0),(1,0),(1,1),(0,1)])


def joint(mesh, center, radius, axis=(1,0,0)):
    p,axis=Vector(center),Vector(axis).normalized()
    for depth,r,material in [(.46,1,'night'),(.51,.84,'silver'),(.56,.60,'brass'),(.59,.31,'night')]:
        mesh.rod(p-axis*depth*.52,p+axis*depth*.52,radius*r,material,12)


def recovery_bed(group):
    m=Mesh()
    # A split pedestal leaves the two return hoses and isolation bellows exposed.
    for y in (-3.0,3.0):
        m.block(-1.59,1.59,y-.77,y+.77,.02,.27,'night',.34)
        m.loft([(x,y+v,.27) for x,v in [(-1.44,-.59),(1.44,-.59),(1.44,.59),(-1.44,.59)]],
               [(x,y+v,1.78) for x,v in [(-.90,-.38),(.90,-.38),(.90,.38),(-.90,.38)]],'edge')
        m.block(-1.01,1.01,y-.48,y+.48,1.70,1.98,'brass',.17)
    for sign in (-1,1):
        path(m,[(sign*.68,-3,1.00),(sign*.91,-2.35,.82),(sign*.91,2.33,.82),(sign*.68,3,1.0)],.13,'pad',8)
        for j in range(14):
            y=-1.95+j*.3
            m.rod((sign*.91,y,.82),(sign*.91,y+.06,.82),.165,'edge',8)
    m.block(-2.14,2.14,-4.97,4.96,1.92,2.37,'night',.83)
    m.block(-2.22,2.22,-5.06,5.05,2.34,2.49,'brass',.76)
    m.block(-2.25,2.25,-5.09,5.08,2.49,2.77,'silver',.73)
    m.block(-2.12,2.12,-4.96,4.95,2.77,2.89,'night',.69)
    # Four separate pads physically support the head, torso, hips and lower legs.
    for a,b in [(-4.80,-2.48),(-2.46,-.92),(-.90,1.31),(1.33,4.81)]:
        m.block(-1.96,1.96,a,b,2.88,BERTH,'pad',.22)
    for sign in (-1,1):
        for j in range(15):
            y=-4.19+j*.59
            m.block(sign*2.06-.07,sign*2.06+.07,y,y+.26,2.77,2.805,'mint' if j%5==0 else 'edge')
        # The rail lies below the top of the cushion to expose the specimen in profile.
        m.rod((sign*2.25,-3.92,2.30),(sign*2.25,3.92,2.30),.065,'silver',8)
        for y in (-3.8,-1.8,1.8,3.8):
            m.rod((sign*2.08,y,2.18),(sign*2.27,y,2.30),.09,'edge',6)
    m.block(-1.45,1.45,-5.075,-4.89,2.04,2.63,'night',.06)
    display(m,(0,-5.087,2.34),(2.62,0,0),(0,0,.44),'caseplate')
    m.block(-2.30,-2.17,-1.41,1.41,1.99,2.70,'night',.055)
    display(m,(-2.312,0,2.36),(0,-2.62,0),(0,0,.48),'caseplate')
    install(m,group,'S-4 • isolated examination slab',BAY,'ExaminationSlab')

    m=Mesh()
    # A sterile graphite wrap follows the iliac crest, above the bed and hips.
    xs=[-.77,-.59,-.41,-.20,0,.20,.41,.59,.77]
    rows=[]
    for j in range(6):
        t=j/5
        row=[]
        for x in xs:
            y=-1.62+.77*t+.055*math.sin(4*x+1.3*t)
            crown=.20+.59*max(0,1-(abs(x)/.77)**2)**.65
            if abs(x)>.70:
                crown=.065
            row.append(Vector((x,y,BERTH+crown+.016*math.sin(x*14+t*3))))
        rows.append(row)
    for a,b in zip(rows,rows[1:]):
        for i in range(len(xs)-1):
            m.plate([a[i],a[i+1],b[i+1],b[i]],'pad')
    for row in (rows[0],rows[-1]):
        path(m,row,.021,'silver',5)
    # Three separate biopotential contacts lead back to a keyed socket on the far rail.
    for j,(x,y,z) in enumerate([(.41,.59,.89),(.39,.16,.78),(.57,-2.44,.588)]):
        p=Vector((x,y,BERTH+z))
        m.rod(p-UP*.055,p+UP*.029,.095,'silver',12,.085)
        m.rod(p+UP*.028,p+UP*.050,.049,'amber' if j==1 else 'mint',10)
        a=p+UP*.043
        b=Vector((x+.46,y+.68,p.z+.13))
        c=Vector((1.77,y+.79,BERTH-.01))
        d=Vector((2.07,y+.34,BERTH+.036))
        curve=[]
        for index in range(17):
            t=index/16
            curve.append(a*(1-t)**3 + b*3*t*(1-t)**2 + c*3*t*t*(1-t) + d*t**3)
        curve.extend([Vector((2.17,y+.30,BERTH+.011)),Vector((2.22,y+.29,2.76))])
        path(m,curve,.021,'pad',6)
    install(m,group,'S-4 • pelvic wrap and telemetry leads',BAY,'Telemetry')


def scanner(group):
    m=Mesh()
    x,y=2.73,2.94
    collar(m,(x,y,0),[(.96,.02),(1.08,.17),(.84,.35),(.51,.46),(.44,3.89),(.58,4.03),(.47,4.23)],
           ['night','edge','brass','silver','night','edge'],12)
    arm=[Vector((x,y,4.13)),Vector((x+.48,y+.34,5.99)),Vector((x-.51,y+.75,7.05)),
         Vector((x-1.87,y+.18,7.26))]
    for i,(a,b) in enumerate(zip(arm,arm[1:])):
        strip(m,a,b,.44 if i==0 else .33,.32,(0,-1,0),'silver','edge')
        path(m,[a+Vector((0,.25,0)),b+Vector((0,.25,0))],.067,'pad',8)
        joint(m,a,.30,(0,1,0))
    hub=arm[-1]
    joint(m,hub,.24,(0,1,0))
    for k in range(3):
        a=k*TAU/3+.2
        p=hub+Vector((math.cos(a)*.76,math.sin(a)*.76,-.34))
        strip(m,hub,p,.22,.21,UP,'edge')
        m.rod(p-UP*.22,p+UP*.12,.49,'night',12,.34)
        loop(m,p-UP*.237,(1,0,0),(0,1,0),.28,.46,.07,'silver',16)
        for i in range(7):
            dx=0 if i==6 else .215*math.cos(i*TAU/6)
            dy=0 if i==6 else .215*math.sin(i*TAU/6)
            q=p+Vector((dx,dy,-.245))
            m.rod(q-UP*.025,q,.095,'white',8)
    install(m,group,'S-4 • articulated three-lens scanner',BAY,'Scanner')

    m=Mesh()
    origin=BAY+Vector((3.60,-.83,0))
    collar(m,(0,0,0),[(1.04,.02),(1.16,.19),(.86,.39),(.46,.46),(.37,3.23),(.56,3.47)],['night','edge','brass','silver','night'],12)
    right=Vector((.17,-.985,0)).normalized()
    up=Vector((.155,.027,.988)).normalized()
    normal=right.cross(up).normalized()
    center=Vector((0,0,4.47))
    border=[center+right*u+up*v for u,v in [(-1.92,-1.09),(1.92,-1.09),(2.05,-.96),(2.05,.96),
                                            (1.92,1.09),(-1.92,1.09),(-2.05,.96),(-2.05,-.96)]]
    m.loft([p-normal*.36 for p in border],border,'edge')
    display(m,center+normal*.012,right*3.77,up*1.92,'readout')
    for k in range(5):
        p=center+up*(-1.06)+right*(-1.52+k*.15)+normal*.03
        m.rod(p,p+normal*.04,.045,'amber' if k==0 else 'mint',8)
    for j in range(7):
        start=center+up*.59-right*(1.6-j*.48)-normal*.38
        strip(m,start,start-up*1.30,.14,.13,normal,'night')
    path(m,[(0,0,2.92),(-.52,.22,2.6),(-.84,.3,1.15),(-1.64,.6,1.0),(-2.03,.8,2.11)],.09,'pad',7)
    install(m,group,'S-4 • cortical scan terminal',origin,'DiagnosticTerminal')


def induction_drive(group):
    """A cutaway drive shows the separate stator shoes, turbine petals and shaft."""
    m=Mesh()
    center=Vector((0,0,4.90))
    xaxis=Vector((1,0,0))
    for sign in (-1,1):
        m.block(sign*3.40-.94,sign*3.40+.94,-1.75,2.23,.02,.29,'night',.32)
        illuminated_rib(m,(sign*3.58,.34,.25),(sign*2.90,.52,3.78),1.05,.74,(0,-1,0))
        strip(m,(sign*3.44,1.68,.25),(sign*2.83,.75,4.02),.62,.56,(0,-1,0),'edge')
    loop(m,center,xaxis,UP,2.94,3.61,1.56,'amethyst',40)
    loop(m,center+Vector((0,-.76,0)),xaxis,UP,2.88,3.51,.14,'edge',40)
    loop(m,center+Vector((0,.77,0)),xaxis,UP,2.91,3.48,.15,'brass',40)
    for k in range(15):
        a=k*TAU/15
        for h,ri,ro,dy,mat in [(.42,3.30,3.86,.02,'night'),(.10,3.11,3.62,-.89,'brass'),(.055,3.21,3.49,-.959,'mint')]:
            loop(m,center+Vector((0,dy,0)),xaxis,UP,ri,ro,h,mat,4,a+.033,a+.33)
        direction=Vector((math.cos(a),0,math.sin(a)))
        p=center+direction*3.67
        m.rod(p+Vector((0,-.31,0)),p+Vector((0,.61,0)),.082,'silver',8)
        # Twisted scimitar vanes tuck behind the fixed outer stator.
        def vane(r,theta,ax):
            return center+Vector((r*math.cos(theta),ax,r*math.sin(theta)))
        ring=[vane(.66,a,-.69),vane(1.67,a+.15,-.55),vane(2.72,a+.47,-.19),
              vane(2.60,a+.66,-.04),vane(1.44,a+.39,-.32),vane(.67,a+.25,-.48)]
        m.loft([p+Vector((0,.09,0)) for p in ring],ring,'silver' if k%3 else 'edge')
        strip(m,ring[0],ring[1],.081,.051,(0,-1,0),'brass')
    for dy,r,r2,mat in [(.58,1.40,1.25,'night'),(.28,1.12,.92,'edge'),(-.27,.94,.77,'brass'),(-.66,.78,.46,'amethyst'),(-1.01,.43,.22,'mint')]:
        p=center+Vector((0,dy,0))
        m.rod(p,p+Vector((0,-.40,0)),r,mat,16,r2)
    # A back manifold feeds several parallel fluted return pipes.
    for j in range(4):
        path(m,[(-3.1,1.27,2.54+j*.30),(-4.12,1.56,2.54+j*.30),
                (-4.45,2.24,1.72+j*.27),(-2.49,3.85,.51+j*.24),(.60,3.85,.51+j*.24)],
             .11,'brass' if j==1 else 'edge',7)
    install(m,group,'Induction drive • exposed counterflow impeller',(-24,-16,0),'InductionDrive')


def manifold(group):
    """Three suspended resonators share a floor manifold and an arched feed rail."""
    m=Mesh()
    m.block(-4.4,4.4,-1.58,1.58,.02,.31,'night',.59)
    m.block(-4.12,4.12,-1.44,1.44,.31,.67,'amethyst',.52)
    for j,x in enumerate((-2.64,0,2.64)):
        collar(m,(x,0,.65),[(.96,0),(1.05,.22),(.77,.49),(.63,.52)],['edge','brass','night'],10)
        for side in (-1,1):
            illuminated_rib(m,(x+side*.91,0,.95),(x+side*.66,.18,4.90+j*.25),.31,.30,(0,-1,0),False)
        crystal(m,(x,0,1.35),.48,2.62+j*.23,.28,('olive','green','amber'))
        for k in range(7):
            z=1.53+k*.45
            loop(m,(x,0,z),(1,0,0),(0,1,0),.57,.76,.105,'brass' if k in (0,6) else 'edge',12)
        m.rod((x,.12,4.69+j*.25),(x,.12,5.14+j*.25),.78,'amethyst',10,.47)
        path(m,[(x,.12,5.1+j*.25),(x,.41,5.6+j*.25),(x,1.32,5.85),(x,1.36,6.34)],.16,'edge',8)
        glyph(m,(x-.30,-1,.71),(1,0,0),(0,0,1),.58,j)
    for sign in (-1,1):
        strip(m,(sign*4.12,1.03,.46),(sign*3.83,1.20,5.87),.52,.50,(0,-1,0),'edge','brass')
        strip(m,(sign*3.83,1.2,5.87),(sign*3.03,1.30,6.42),.52,.50,(0,-1,0),'amethyst','edge')
    strip(m,(-3.13,1.30,6.4),(3.13,1.30,6.4),.48,.49,(0,-1,0),'amethyst','edge')
    install(m,group,'Phase manifold • three suspended resonators',(24,-16,0),'PhaseManifold')


def cartridge_rack(group):
    m=Mesh()
    m.block(-2.64,2.64,-.95,.95,.02,.23,'night',.22)
    for sign in (-1,1):
        strip(m,(sign*2.4,.2,.20),(sign*2.14,.66,4.38),.41,.36,(0,-1,0),'amethyst','brass')
    for z in (1.35,3.84):
        strip(m,(-2.2,.26,z),(2.2,.26,z),.32,.34,(0,-1,0),'edge')
    for j in range(6):
        x=-1.69+j*.677
        for low,high,r,material in [(1.37,1.66,.23,'night'),(1.66,1.85,.27,'brass'),
                                    (1.85,3.31,.19,'green'),(3.31,3.54,.26,'edge'),(3.54,3.79,.20,'amethyst')]:
            m.rod((x,0,low),(x,0,high),r,material,8)
        for k in range(j%3+1):
            m.rod((x,0,2.18+k*.15),(x,0,2.24+k*.15),.20,'amber',8)
    install(m,group,'Spectral archive • keyed memory rods',(-65,-9,16),'MemoryRack')


def build(group):
    recovery_bed(group)
    scanner(group)
    induction_drive(group)
    manifold(group)
    cartridge_rack(group)
    inspection_tray(group)
    fold_navigator(group)


def inspection_tray(group):
    """Recovery cart with two original handheld implements and an indexed sample cassette."""
    m=Mesh()
    for sign in (-1,1):
        for side in (-1,1):
            x,y=sign*1.04,side*.60
            m.rod((x-.10,y,.25),(x+.10,y,.25),.20,'pad',10)
            strip(m,(x,y,.39),(x*.89,y*.89,2.78),.12,.12,(0,-1,0),'silver')
    m.block(-1.24,1.24,-.76,.76,.72,.83,'edge',.14)
    m.block(-1.40,1.40,-.88,.88,2.76,2.88,'silver',.14)
    m.block(-1.31,1.31,-.80,.80,2.88,2.92,'pad',.11)
    for y in (-.84,.84):
        strip(m,(-1.24,y,2.94),(1.24,y,2.94),.10,.12,(0,0,1),'silver')
    # A caliper-like contact fork and a hand spectroscope in fitted rests.
    for y in (-.30,.29):
        m.rod((-.74,y,3.015),(-.08,y,3.015),.105,'edge',10,.083)
        for i in range(4):
            x=-.66+i*.13
            m.rod((x,y,3.015),(x+.045,y,3.015),.112,'brass',10)
    for sign in (-1,1):
        path(m,[(-.08,-.30,3.015),(.14,-.30+sign*.14,3.02),
                (.52,-.30+sign*.19,3.04),(.65,-.30+sign*.11,3.08)],.036,'silver',6)
    m.rod((-.08,.29,3.015),(.32,.29,3.015),.125,'brass',10,.19)
    m.rod((.32,.29,3.015),(.366,.29,3.015),.135,'green',12)
    for i in range(3):
        x=.86+i*.14
        m.rod((x,-.40,3.005),(x,.42,3.005),.051,'silver',8)
        m.rod((x,.28,3.005),(x,.43,3.005),.058,'amber',8)
    m.block(-.86,.86,-.42,.42,.84,1.40,'amethyst',.09)
    for x in (-.66,.66):
        m.block(x-.06,x+.06,-.43,.43,1.40,1.43,'brass')
    install(m,group,'S-4 • mobile spectral instrument tray',BAY+Vector((3.51,-4.12,0)),'InstrumentTray')


def fold_navigator(group):
    """Three open induction forks enclose a sliced niobium navigation core."""
    m=Mesh()
    collar(m,(0,0,0),[(2.62,.02),(2.85,.25),(2.48,.54),(2.30,.59),(1.88,.98),
                       (1.67,1.18),(1.52,1.23)],['night','amethyst','brass','edge','night','mint'],9)
    for k in range(3):
        a=TAU*k/3+.44
        direction=Vector((math.cos(a),math.sin(a),0))
        tangent=Vector((-direction.y,direction.x,0))
        points=[direction*r+UP*z+tangent*lean for r,z,lean in
                [(1.80,.60,0),(2.15,1.92,.12),(2.09,3.48,.42),(1.46,4.48,.73),(1.18,4.65,.76)]]
        for j,(p,q) in enumerate(zip(points,points[1:])):
            strip(m,p,q,.65-j*.11,.42,direction,'amethyst','edge')
            strip(m,p-direction*.18,q-direction*.18,.13,.16,-direction,'mint')
        for j in range(5):
            p=direction*(1.25+j*.108)+tangent*.62+UP*(3.17+j*.085)
            m.rod(p,p+direction*.24,.069,'brass',7)
    for j,(r,z) in enumerate([(.40,1.86),(.84,2.12),(1.09,2.43),(.98,2.77),(.69,3.10),(.30,3.37)]):
        phase=.18+j*.22
        xy=[(r*math.cos(phase+k*TAU/6),r*math.sin(phase+k*TAU/6)) for k in range(6)]
        m.loft([(x*.91,y*.91,z) for x,y in xy],[(x,y,z+.18) for x,y in xy],'edge' if j%2 else 'green')
        m.loft([(x,y,z+.18) for x,y in xy],[(x*.88,y*.88,z+.217) for x,y in xy],'brass')
    crystal(m,(0,0,1.34),.17,2.29,.12,('green','white','mint'))
    install(m,group,'Fold navigator • suspended helical index',(-48,12,16),'FoldNavigator')
