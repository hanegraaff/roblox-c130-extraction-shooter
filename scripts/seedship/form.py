"""Common fabrication primitives for the seedship's folded ribs and optical inlays."""
import math
from mathutils import Vector
from meshwork import Mesh

UP = Vector((0, 0, 1))


def strip(mesh, a, b, width, depth, outward, metal, flank=None, taper=1):
    """Six-sided section, with broad flats and narrow polished bevels."""
    a, b, out = Vector(a), Vector(b), Vector(outward).normalized()
    axis = (b-a).normalized()
    lateral = axis.cross(out)
    if lateral.length < .01:
        lateral = axis.cross(Vector((1,0,0)))
    lateral.normalize()
    normal = lateral.cross(axis).normalized()
    section = [(-.5,-.45),(.5,-.45),(.5,.14),(.36,.5),(-.36,.5),(-.5,.14)]
    first = [a + lateral*x*width + normal*y*depth for x,y in section]
    last = [b + lateral*x*width*taper + normal*y*depth for x,y in section]
    mesh.loft(first, last, metal)
    if flank:
        # The side bevels take the brighter metal while the wide face stays dark.
        for i in (-4,-2):
            mesh.surfaces[i] = flank
    return normal


def lancet(mesh, a, b, width, outward, material, height=.08, waist=.24):
    """Faceted spear-shaped lens, raised along its central ridge."""
    a,b,n = Vector(a),Vector(b),Vector(outward).normalized()
    side = (b-a).cross(n).normalized()
    middle = a.lerp(b,waist)
    ring = [a, middle+side*width/2, b, middle-side*width/2]
    verts = ring + [middle+n*height, middle-n*.08]
    mesh.solid(verts, [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)], material)


def illuminated_rib(mesh, a, b, width, depth, outward, light=True):
    a,b = Vector(a),Vector(b)
    n = strip(mesh,a,b,width,depth,outward,'amethyst','edge')
    if light and (b-a).length > 2:
        for offset, factor, mat, height in [(.49,.52,'night',.09),(.54,.33,'green',.14),(.59,.17,'mint',.15)]:
            d = n*depth*offset
            lancet(mesh,a.lerp(b,.06)+d,a.lerp(b,.94)+d,width*factor,n,mat,height,.36)
        for t in (.17,.77):
            q = a.lerp(b,t)+n*depth*.64
            side = (b-a).cross(n).normalized()*width*.20
            strip(mesh,q-side,q+side,.12,.10,n,'brass')


def collar(mesh, center, rings, materials, sides=8, phase=0):
    """Turn a changing polygonal profile around a vertical axis."""
    x,y,z = center
    prev = None
    for j,(radius, height) in enumerate(rings):
        loop = [(x+radius*math.cos(i*math.tau/sides+phase),
                 y+radius*math.sin(i*math.tau/sides+phase), z+height) for i in range(sides)]
        if prev:
            mesh.loft(prev,loop,materials[(j-1)%len(materials)])
        prev = loop


def crystal(mesh, center, radius, height, twist=.11, palette=('olive','green','mint')):
    x,y,z = center
    n = 6
    def ring(rad, elev, phase):
        return [(x+rad*math.cos(i*math.tau/n+phase), y+rad*math.sin(i*math.tau/n+phase), z+elev) for i in range(n)]
    rings = [ring(radius*.24,0,.20),ring(radius,height*.24,.20),ring(radius*.83,height*.72,.20+twist)]
    for j in range(2):
        for i in range(n):
            k=(i+1)%n
            mesh.solid([rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],(x,y,z+height*(.15+j*.35))],
                       [(0,1,2,3),(0,4,1),(1,4,2),(2,4,3),(3,4,0)],palette[(i+j)%len(palette)])
    for i in range(n):
        mesh.solid([rings[2][i],rings[2][(i+1)%n],(x+radius*.13,y,z+height),(x,y,z+height*.71)],
                   [(0,1,2),(0,3,1),(1,3,2),(2,3,0)],palette[(i+1)%len(palette)])


def path(mesh, points, radius, mat, sides=5):
    for a,b in zip(points, points[1:]):
        mesh.rod(a,b,radius,mat,sides)
