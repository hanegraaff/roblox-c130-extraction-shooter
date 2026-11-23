"""Surveyed shell, radial frame, and pivot-aligned destructible nacre cassettes."""
import math
import random
from mathutils import Vector
from form import Mesh, UP, strip, lancet, illuminated_rib, collar

# From the south portal crown, travel around starboard to the north point.
HALF = [(0,-60,22.4),(15,-61,13.8),(23,-58,0),(48,-55,0),(77,-49,0),
        (90,-34,0),(102,-22,0),(102,-12.8,0),(102,12.8,0),(102,24,0),
        (88,43,0),(73,57,0),(39,64,0),(0,71.432,0)]
RIM = HALF + [(-x,y,z) for x,y,z in HALF[-2:0:-1]]
COUNT = len(RIM)
CENTER = Vector((0,12,0))
QUAD = [(0.,0.),(1.,0.),(1.,1.),(0.,1.)]


def node(i, level):
    x,y,portal = RIM[i % COUNT]
    factor = [1,.954,.765,.408,.073][level]
    elevation = [-2.4 if portal == 0 else portal, 12.6+portal*.61,
                 23.6+portal*.35+(1.25 if i%2==0 else -.75), 30.9+portal*.22+(1 if i%2==0 else -.9),36.85+portal*.035][level]
    if i%COUNT==0 and level in (2,3):
        elevation += 1.4 if level==2 else 1.93
    return Vector((x*factor,12+(y-12)*factor,elevation))


def clip(poly, dx, dy, limit):
    """Keep one convex half plane, preserving the winding and shared edges."""
    result = []
    for a,b in zip(poly, poly[1:]+poly[:1]):
        da,db = dx*a[0]+dy*a[1]-limit, dx*b[0]+dy*b[1]-limit
        if da <= 1e-9:
            result.append(a)
        if (da < -1e-9 and db > 1e-9) or (db < -1e-9 and da > 1e-9):
            t = da/(da-db)
            result.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
    return result


def seeds(i, row):
    rng = random.Random(1301+row*101+i)
    pts = [(rng.uniform(.05,.42),rng.uniform(.08,.45)),(rng.uniform(.6,.96),rng.uniform(.08,.42)),
           (rng.uniform(.02,.3),rng.uniform(.57,.93)),(rng.uniform(.39,.7),rng.uniform(.5,.83)),
           (rng.uniform(.78,.97),rng.uniform(.74,.98))]
    cells = []
    for p in pts:
        poly = QUAD
        for q in pts:
            if q == p:
                continue
            dx,dy = q[0]-p[0],q[1]-p[1]
            poly = clip(poly, dx,dy,dx*(p[0]+q[0])*.5+dy*(p[1]+q[1])*.5)
        cells.append(poly)
    return cells


def regions(i,level):
    # The illustrated impact crosses two adjoining courses. The broken border is
    # modeled through the full thickness. No intact backing spans the cavity.
    if i==3 and level in (0,1):
        if level==0:
            left=[(.12,0),(.18,.17),(.105,.34),(.19,.50),(.07,.68),(.11,.84),(.09,1)]
            right=[(.82,0),(.86,.23),(.81,.38),(.94,.60),(.89,.76),(.93,1)]
            return [[(0,a[1]),a,b,(0,b[1])] for a,b in zip(left,left[1:])] + [
                    [a,(1,a[1]),(1,b[1]),b] for a,b in zip(right,right[1:])]
        brow=[(0,0),(.09,0),(.19,.27),(.205,.39),(.32,.52),(.42,.48),(.58,.65),
              (.69,.56),(.83,.51),(.855,.34),(.91,.20),(.93,0),(1,0)]
        return [[a,b,(b[0],1),(a[0],1)] for a,b in zip(brow,brow[1:])]
    if level==0 and min(i,COUNT-1-i) in (2,4,5,8,10):
        # An outer clerestory is cut through each skirt plate. Three convex
        # regions wrap around the stepped, hexagonal mouth above a low sill.
        edge=[(0,.10),(.14,.10),(.20,.42),(.33,.66),(.65,.66),(.80,.42),(.87,.10),(1,.10)]
        shapes=[[(0,0),(1,0),(1,.10),(0,.10)]]
        for a,b in zip(edge,edge[1:]):
            shapes.append([a,b,(b[0],1),(a[0],1)])
        return shapes
    return [QUAD]


def clipped_region(poly, limits):
    for dx,dy,value in limits:
        poly = clip(poly,dx,dy,value)
        if len(poly)<3:
            return []
    return poly


class Face:
    def __init__(self,i,row):
        self.i, self.row = i,row
        self.a,self.b,self.c,self.d = node(i,row),node(i+1,row),node(i+1,row+1),node(i,row+1)
        self.norm = (self.b-self.a).cross(self.d-self.a).normalized()
        self.id = f'Prism_{["Skirt","Mantle","Roof","Crown"][row]}_{i+1:02d}'
        self.origin = self.point(.5,.5)
        self.cells = seeds(i,row)

        self.domains=regions(i,row)
        self.cut_axis=1 if i==3 and row<2 else 0
        self.keep=self.half_residual()

    def half_residual(self):
        # Integrate the true face area by triangle fans in the fitted surface.
        # A clerestory or historic impact changes how much material remains.
        def area(poly):
            if len(poly)<3:
                return 0
            world=[self.point(*p) for p in poly]
            return abs(sum((b-world[0]).cross(c-world[0]).dot(self.norm)*.5
                           for b,c in zip(world[1:],world[2:])))
        original=sum(area(poly) for poly in self.domains)
        low,high=0,.5
        for _ in range(20):
            edge=(low+high)*.5
            amount=sum(area(clipped_region(poly,[plane])) for poly in self.domains
                       for plane in self.strips(edge))
            if amount<original*.5:
                low=edge
            else:
                high=edge
        return (low+high)*.5

    def strips(self,edge):
        a=self.cut_axis
        return [(1-a,a,edge),(a-1,-a,edge-1)]

    def point(self,u,v,h=0):
        # The two planes share the a-c crease. This keeps a ray through a
        # broken face consistent under n-gon tessellation and glTF reimport.
        if u>=v:
            return self.a+(self.b-self.a)*u+(self.c-self.b)*v+self.norm*h
        return self.a+(self.c-self.d)*u+(self.d-self.a)*v+self.norm*h

    def plate(self,m,uv,back,front,mat,edge=None):
        for dx,dy in ((1,-1),(-1,1)):
            polygon=clip(uv,dx,dy,0)
            if len(polygon)<3:
                continue
            m.loft([self.point(u,v,back) for u,v in polygon],[self.point(u,v,front) for u,v in polygon],mat)
            if edge:
                for k in range(-len(polygon),0):
                    m.surfaces[k]=edge

    def build(self,group,stage,proxy=False):
        m = Mesh()
        for region in self.domains:
            # Heavy retains two torn strips; even inside a pre-existing breach
            # the remaining ribbons lose the middle half of their height.
            heavy_axis=self.cut_axis
            limits=[[]] if stage!='Heavy' else [[plane] for plane in self.strips(self.keep)]
            for bound in limits:
                if proxy:
                    self.plate(m,clipped_region(region,bound),-.71,0,'raw')
                    continue
                for k,cell in enumerate(self.cells):
                    halfplanes = []
                    for a,b in zip(cell,cell[1:]+cell[:1]):
                        dx,dy=b[1]-a[1],a[0]-b[0]
                        halfplanes.append((dx,dy,dx*a[0]+dy*a[1]))
                    poly=clipped_region(region, bound+halfplanes)
                    if len(poly)<3:
                        continue
                    self.plate(m,poly,-.71,-.12,'night','raw')
                    u=sum(p[0] for p in poly)/len(poly)
                    v=sum(p[1] for p in poly)/len(poly)
                    inset=[(u+(a-u)*.986,v+(b-v)*.986) for a,b in poly]
                    tint='mauve' if (k+self.i+self.row)%7==0 else 'pearl'
                    self.plate(m,inset,-.119,.025+(k%3)*.022,tint,'edge')
                    # A second skin inside the hall catches the ribs' reflected green.
                    self.plate(m,inset,-.75,-.712,tint)
                    if stage=='Light':
                        # Zigzag fractures remain on their parent plate on both faces.
                        points=[(u,v),(u+(inset[0][0]-u)*.30+.012,v+(inset[0][1]-v)*.30),
                                (u+(inset[0][0]-u)*.55-.015,v+(inset[0][1]-v)*.55),inset[0]]
                        for a,b in zip(points,points[1:]):
                            for h in (.115,-.79):
                                strip(m,self.point(*a,h),self.point(*b,h),.20,.05,self.norm,'raw')
                                strip(m,self.point(*a,h+.023),self.point(*b,h+.023),.052,.03,self.norm,'mint')
                    if stage=='Heavy':
                        for a,b in zip(inset,inset[1:]+inset[:1]):
                            if max(abs(a[heavy_axis]-self.keep),abs(b[heavy_axis]-self.keep))<.025 or max(abs(a[heavy_axis]-(1-self.keep)),abs(b[heavy_axis]-(1-self.keep)))<.025:
                                strip(m,self.point(*a,.03),self.point(*b,.03),.22,.17,self.norm,'raw')
        if not proxy and self.row in (0,2) and self.i!=3:
            # Inset optical belt and fasteners belong to the cassette, including
            # the broken-state stubs. These short lenses never bridge a Heavy hole.
            for u0,u1 in [(.07,self.keep-.012),(1-self.keep+.012,.93)] if stage=='Heavy' else [(.06,.94)]:
                v=.775 if self.row==2 else .845
                a,b=self.point(u0,v,.14),self.point(u1,v,.14)
                lancet(m,a,b,1.35,self.norm,'amethyst',.18,.22)
                lancet(m,a.lerp(b,.09)+self.norm*.16,a.lerp(b,.92)+self.norm*.16,.42,self.norm,'mint',.13,.27)
        if not proxy and self.row==1 and self.i!=3:
            # Broad armored eyelids cap the shoulder of each petal. The inset
            # green louvers are separated by individual gunmetal mullions.
            outline=[(.03,.95),(.14,.73),(.60,.72),(.94,.81),(.97,.965),(.61,.91),(.25,.91)]
            windows=[(.13,.895),(.20,.795),(.58,.775),(.89,.837),(.60,.862),(.27,.858)]
            sections=[[]] if stage!='Heavy' else [[plane] for plane in self.strips(self.keep-.004)]
            for section in sections:
                self.plate(m,clipped_region(outline,section),.075,.47,'amethyst','edge')
                self.plate(m,clipped_region(windows,section),.473,.53,'green','brass')
                for k in range(9):
                    u=.22+k*.077
                    if section and (section[0][0]==1 and u+.023>self.keep-.004 or section[0][0]==-1 and u<1-self.keep+.004):
                        continue
                    a,b=self.point(u,.79,.55),self.point(u+.023,.86,.55)
                    strip(m,a,b,.13,.09,self.norm,'edge')
        if not proxy and self.row==0 and min(self.i,COUNT-1-self.i) in (6,9,11,12):
            for u in (.135,.865):
                a,b=self.point(u,.19,-.80),self.point(u,.78,-.80)
                lancet(m,a,b,2.7,-self.norm,'amethyst',.28,.27)
                lancet(m,a-self.norm*.26,b-self.norm*.26,1.23,-self.norm,'mint',.33,.31)
        if not proxy and self.row in (1,2) and self.i!=3:
            # Flush inspection cartouches and stamped registry marks sit on the
            # outer margins, so both survive with their own Heavy residual.
            for u,sgn in [(.13,1),(.87,-1)]:
                a,b=self.point(u,.11,.12),self.point(u+sgn*.015,.40,.12)
                section=(self.b-self.a).length
                width=min(2.3,section*.13)
                lancet(m,a,b,width,self.norm,'night',.15,.30)
                lancet(m,a.lerp(b,.08)+self.norm*.14,a.lerp(b,.90)+self.norm*.14,width*.57,self.norm,'edge',.14,.32)
                for k in range(4):
                    t=.23+k*.10
                    q=a.lerp(b,t)+self.norm*.30
                    side=(self.b-self.a).normalized()*width*(.16-.016*k)
                    strip(m,q-side,q+side,.095,.08,self.norm,'brass' if k!=2 else 'mint')
        if not proxy and self.row==1 and self.i!=3:
            # Offset a short ladder of pale alien glyphs from the panel seal.
            from relics import glyph
            right=(self.b-self.a).normalized()
            up=self.norm.cross(right).normalized()
            glyph(m,self.point(.11,.57,.14),right,up,1.12,self.i,'brass')
        m.texcoords=[[(u*.48,v*.48) for u,v in face_uv] for face_uv in m.texcoords]
        name=self.id+'_'+('Proxy_' if proxy else '')+stage
        return m.finish(name,group,self.origin,PanelId=self.id,Appearance=stage,Role='QueryProxy' if proxy else 'HullSkin',
                        StoryId='01' if self.row==0 else '02',Placement='Wall' if self.row<2 else 'Roof')


def boot(mesh,i):
    """Flared landing spurs, split armored knuckles and nested knee lenses."""
    if RIM[i][2]>0:
        return
    a,b,c=node(i,0),node(i,1),node(i,2)
    out=Vector((a.x,a.y-12,0)).normalized()
    tangent=Vector((-out.y,out.x,0))
    # Side pilasters stop at the fixed survey edge. Grow their returns inward.
    shoe=a-out*.60
    for sign in (-1,1):
        side=tangent*sign
        p=shoe+side*3.86+UP*.10
        q=a.lerp(b,.41)+side*2.22+out*.30
        r=b+side*1.05+out*.35
        s=b.lerp(c,.57)+side*.53
        strip(mesh,p,q,2.3,1.0,out,'amethyst','edge',.80)
        illuminated_rib(mesh,q,r,1.61,.81,out)
        strip(mesh,r,s,1.03,.69,out,'edge','amethyst',.25)
        v=shoe+side*3.0+UP*.58
        strip(mesh,v-side*.85,v+side*.85,.54,.95,out,'night')
    axis=(b-a).normalized()
    for k in range(4):
        p=a.lerp(b,.50)+axis*k*.49+out*.66
        strip(mesh,p-tangent*.80,p+tangent*.80,.135,.11,out,'brass')


def assemble(panels, frame, library):
    records = []
    for i in range(COUNT):
        for row in range(4):
            if row==0 and i in (7,COUNT-8):
                continue
            face=Face(i,row)
            pristine=face.build(panels,'Pristine')
            light=face.build(library,'Light')
            heavy=face.build(library,'Heavy')
            solid=face.build(library,'Pristine',True)
            residual=face.build(library,'Heavy',True)
            records.append(dict(id=face.id,pivot=[round(n,5) for n in face.origin],placement=pristine['Placement'],
                                story=pristine['StoryId'],pristine=pristine.name,light=light.name,heavy=heavy.name,
                                intactAndLightQuery=solid.name,heavyQuery=residual.name,total=None))
        m=Mesh()
        for j in range(4):
            a,b=node(i,j),node(i,j+1)
            main = i in (0,2,4,6,9,11,13,15,17,20,22,24)
            if j>=2 and not main:
                continue
            tangent=node(i+1,j)-node(i-1,j)
            n=tangent.cross(b-a).normalized()
            width=(5.35 if main else 2.85)*(1-.14*j)
            if i==0:
                width=8.15-j*.87
            illuminated_rib(m,a,b,width,1.15 if main else .78,n,main or j==0)
            if i==0:
                ridge=Vector((0,-.30,1)).normalized()
                for side in (-1,1):
                    root=a+Vector((side*width*.41,0,-.05))
                    tip=b+Vector((side*width*.28,0,.31))
                    strip(m,root,tip,.77,.85,ridge,'edge','brass')
                lancet(m,a+ridge*.89,b+ridge*.89,width*.44,ridge,'green',.42,.48)
                lancet(m,a.lerp(b,.08)+ridge*1.19,b-ridge*.01+ridge*1.19,width*.19,ridge,'mint',.22,.42)
            # A secondary return flange is visible beneath the roof.
            strip(m,a-n*.91,b-n*.91,width*.53,.45,-n,'amethyst','edge')
        boot(m,i)
        m.finish(f'Meridian {i+1:02d} • folded longeron',frame,node(i,1),Role='StableFrame')
    # Eave bands vary in weight. The greatest mass occurs at the entry arch.
    for i in range(COUNT):
        m=Mesh()
        for j in (0,1,2,4):
            if j==0 and i not in (0,1,COUNT-1,COUNT-2):
                continue
            a,b=node(i,j),node(i+1,j)
            outward=Vector(((a.x+b.x)*.5,(a.y+b.y)*.5-12,.05)).normalized()
            if i==3 and j==1:
                # The transverse band sheared off with the impact.
                strip(m,a,a.lerp(b,.08),1.25,.84,outward,'amethyst','edge')
                strip(m,a.lerp(b,.94),b,1.25,.84,outward,'amethyst','edge')
                continue
            if j==0:
                illuminated_rib(m,a,b,3.5,1.7,outward,True)
                illuminated_rib(m,a-outward*1.25,b-outward*1.25,2.6,.8,-outward,True)
            else:
                strip(m,a,b,1.25 if j==1 else .82,.84,UP if j>=2 else outward,'amethyst','edge')
        m.finish(f'Transverse seam {i+1:02d}',frame,node(i,1),Role='StableFrame')
    m=Mesh()
    for i in (0,13):
        spine=[node(i,j) for j in range(1,5)]
        for j,(a,b) in enumerate(zip(spine,spine[1:])):
            for sign in (-1,1):
                side=Vector((sign,0,0))
                toe=a+side*(2.75-j*.44)
                wing=a.lerp(b,.64)+side*(4.4-j*.62)+UP*.48
                tip=b+side*(1.9-j*.33)+UP*(1.06-j*.19)
                heel=a.lerp(b,.29)+side*(2.0-j*.36)+UP*.40
                ring=[toe,wing,tip,heel]
                m.loft([p-UP*.40 for p in ring],ring,'amethyst')
                strip(m,wing,tip,.30,.20,UP,'brass')
    collar(m,(0,12,0),[(8.0,36.5),(6.4,37.8),(4.7,38.4),(3.6,38.55),(2.2,39.1),(.25,40)],['amethyst','edge','night','green','mint'],10)
    m.finish('Polar seal • decagonal keystone',frame,(0,12,37),Role='StableFrame')
    return records
