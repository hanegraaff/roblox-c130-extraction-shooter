"""Low-poly hard-surface mesh construction with real UVs and outward winding."""
import math
import bpy
from mathutils import Vector

TAU = math.tau
MATERIALS = {}


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


class Mesh:
    """Accumulate independently editable mechanical pieces in one named component."""

    def __init__(self):
        self.vertices = []
        self.faces = []
        self.surfaces = []
        self.texcoords = []
        self.transform = lambda p: Vector(p)

    def solid(self, points, faces, mat):
        points = [self.transform(Vector(p)) for p in points]
        start = len(self.vertices)
        self.vertices.extend(points)
        center = sum(points, Vector())/len(points)
        for face in faces:
            a, b, c = [points[k] for k in face[:3]]
            normal = (b-a).cross(c-a)
            if normal.length_squared < 1e-12:
                continue
            if normal.dot(sum((points[k] for k in face), Vector())/len(face)-center) < 0:
                face = face[::-1]
            self.faces.append([start+k for k in face])
            self.surfaces.append(mat)
            axis = max(range(3), key=lambda i: abs(normal[i]))
            uv_axes = [(1, 2), (0, 2), (0, 1)][axis]
            self.texcoords.append([(points[k][uv_axes[0]]/5.4, points[k][uv_axes[1]]/5.4) for k in face])

    def loft(self, bottom, top, mat):
        n = len(bottom)
        self.solid(list(bottom)+list(top), [list(range(n)), list(range(n, 2*n))] +
                   [[i, (i+1) % n, (i+1) % n+n, i+n] for i in range(n)], mat)

    def block(self, x0, x1, y0, y1, z0, z1, mat, cut=0):
        if min(x1-x0, y1-y0, z1-z0) < .0001:
            return
        cut = min(cut, (x1-x0)*.3, (y1-y0)*.3)
        xy = ([(x0+cut, y0), (x1-cut, y0), (x1, y0+cut), (x1, y1-cut), (x1-cut, y1),
               (x0+cut, y1), (x0, y1-cut), (x0, y0+cut)] if cut else [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
        self.prism(xy, z0, z1, mat)

    def prism(self, xy, z0, z1, mat):
        self.loft([(x, y, z0) for x, y in xy], [(x, y, z1) for x, y in xy], mat)

    def rod(self, a, b, r, mat, n=8, r2=None):
        a, b = Vector(a), Vector(b)
        axis = (b-a).normalized()
        seed = Vector((1, 0, 0)) if abs(axis.z) > .85 else Vector((0, 0, 1))
        u = axis.cross(seed).normalized()
        v = axis.cross(u)
        offsets = [u*math.cos(TAU*i/n)+v*math.sin(TAU*i/n) for i in range(n)]
        self.loft([a+r*p for p in offsets], [b+(r if r2 is None else r2)*p for p in offsets], mat)

    def ring(self, ri, ro, z0, z1, mat, n=48, phase=0):
        for i in range(n):
            a, b = (i/n+phase)*TAU, ((i+1)/n+phase)*TAU
            self.prism([(r*math.cos(t), r*math.sin(t))
                       for r, t in [(ri, a), (ro, a), (ro, b), (ri, b)]], z0, z1, mat)

    def plate(self, points, mat, uv=None):
        """One outward-facing decal; points wind CCW as viewed from its front."""
        idx = len(self.vertices)
        self.vertices.extend(self.transform(Vector(p)) for p in points)
        self.faces.append(list(range(idx, idx+len(points))))
        self.surfaces.append(mat)
        self.texcoords.append(uv or [(0, 0), (1, 0), (1, 1), (0, 1)])

    def finish(self, name, group, pivot=(0, 0, 0), **attributes):
        if not self.faces:
            return None
        pivot = Vector(pivot)
        data = bpy.data.meshes.new(name)
        data.from_pydata([v-pivot for v in self.vertices], [], self.faces)
        keys = list(dict.fromkeys(self.surfaces))
        for key in keys:
            data.materials.append(MATERIALS[key])
        data.polygons.foreach_set("material_index", [keys.index(k) for k in self.surfaces])
        uv = data.uv_layers.new(name='SurfaceUV')
        uv.data.foreach_set('uv', [coord for face in self.texcoords for pair in face for coord in pair])
        data.update()
        obj = bpy.data.objects.new(name, data)
        group.objects.link(obj)
        obj.location = pivot
        for k, value in attributes.items():
            obj[k] = value
        return obj
