"""Author the P20 limestone portrait and render its four Blender inspection cameras.

Run from the repository root with Blender in background mode and --python-exit-code 1.
The portrait uses hand-placed landmarks from the bust photograph. Portrait 1 guides the backward hair flow, gathered brow and downward eye line.
Coordinates below are a local sculpting grid, with positive depth toward the viewer.
One grid unit becomes 0.02 Blender units (studs). The reference guides shape only.
"""

import bmesh
import openvdb
from bisect import bisect_right
from hashlib import sha256
import json
from math import atan2, cos, exp, hypot, pi, sin, sqrt
from pathlib import Path
import sys

import bpy
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/blender/lobby-bust/lobby-bust.blend"
EXPORT = ROOT / "assets/exports/lobby-bust/lobby-bust.glb"
VIEWS = ROOT / "docs/evidence/p20"
SCALE = 0.02
TAU = 2 * pi
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
sculpt = bpy.data.collections.new("Lobby Bust · export meshes")
stage = bpy.data.collections.new("Measurement stage · review only")
rig = bpy.data.collections.new("Atelier · cameras and lights")
for collection in (sculpt, stage, rig):
    scene.collection.children.link(collection)


def world(x, depth, row):
    return (x * SCALE, -depth * SCALE, (1060 - row) * SCALE)


def gauss(x, width):
    return exp(-min((x / width) ** 2, 100))


def smooth(value):
    u = max(0, min(1, value))
    return u * u * (3 - 2 * u)


def interp(knots, value):
    """Shape-preserving cubic Hermite interpolation, including near flat extrema."""
    if value <= knots[0][0]:
        return knots[0][1]
    for i in range(len(knots) - 1):
        x, y = knots[i]
        nx, ny = knots[i + 1]
        if value <= nx:
            dx = nx - x
            m = (ny - y) / dx

            def tangent(point):
                if point == 0 or point == len(knots) - 1:
                    return m
                a, b, c = knots[point - 1: point + 2]
                left = (b[1] - a[1]) / (b[0] - a[0])
                right = (c[1] - b[1]) / (c[0] - b[0])
                return 2 * left * right / (left + right) if left * right > 0 else 0

            u = (value - x) / dx
            return y + (ny - y) * smooth(u) + dx * u * (1 - u) * (
                (1 - u) * tangent(i) - u * tangent(i + 1)
            )
    return knots[-1][1]


def material(name, color, roughness=0.72):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


stone = material("01  Honed limestone", (0.72, 0.65, 0.52))
hair_stone = material("02  Combed limestone", (0.68, 0.615, 0.5))
frame_stone = material("03  Polished spec rims", (0.58, 0.50, 0.38), 0.45)
iris = material("04  Chiseled iris", (0.41, 0.375, 0.30))
pupil = material("05  Pupil recess", (0.095, 0.085, 0.065))
shirt_stone = material("06  Dressed limestone", (0.70, 0.63, 0.51))
amber = material("Plinth · bronze", (0.26, 0.14, 0.05), 0.37)
slate = material("Stage · smoked teal", (0.08, 0.122, 0.119))
wall = material("Stage · sand plaster", (0.34, 0.30, 0.245))


def mesh(name, vertices, faces, mat, collection=sculpt):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.materials.append(mat)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    for face in data.polygons:
        face.use_smooth = True
    return obj


def rings(name, loops, mat, collection=sculpt, reverse=False):
    """Close a sequence of circumferential loops; first loop is the lower cap."""
    n = len(loops[0])
    faces = [tuple(reversed(range(n)))]
    for j in range(len(loops) - 1):
        for i in range(n):
            other = (i + 1) % n
            a = j * n
            faces.append((a + i, a + other, a + n + other, a + n + i))
    faces.append(tuple(range((len(loops) - 1) * n, len(loops) * n)))
    if reverse:
        faces = [f[::-1] for f in faces]
    return mesh(name, [point for row in loops for point in row], faces, mat, collection)


def cross_sections(name, profiles, mat, step=128, collection=sculpt):
    loops = []
    for row, radius, depth, center in profiles:
        loops.append([world(radius * sin(TAU * i / step),
                            center + depth * cos(TAU * i / step), row)
                      for i in range(step)])
    return rings(name, loops, mat, collection)


# Turned foot. The upper fillet slips under the curved shirt crop.
cross_sections("01 | Turned socle", [
    (1060, 223, 223, 0), (1059, 232, 232, 0), (1055, 239, 239, 0),
    (1048, 242, 242, 0), (1041, 241, 241, 0), (1036, 237, 237, 0),
    (1034, 232, 232, 0), (1034, 227, 227, 0), (1032, 227, 227, 0),
    (1027, 223, 223, 0), (1014, 211, 187, 0), (995, 200, 167, 0),
    (980, 196, 153, 0), (962, 195, 145, 0), (948, 197, 140, 0),
    (939, 202, 137, 0)], stone)


# The shirt's cropped shoulders form a rising arc on each side of the socle.
shirt_profile = [
    (0.00, 202, 165, 975), (0.03, 217, 170, 968),
    (0.13, 260, 176, 935), (0.32, 291, 180, 870),
    (0.61, 328, 170, 756), (0.76, 335, 151, 686),
    (0.785, 332, 143, 672), (0.81, 320, 139, 660),
    (0.92, 227, 125, 617), (1.00, 132, 107, 577),
]
shirt_channels = [[(p[0], p[i]) for p in shirt_profile] for i in (1, 2, 3)]


def shirt_point(t, angle):
    rx, depth, row = (interp(channel, t) for channel in shirt_channels)
    co, si = cos(angle), sin(angle)
    # An open V at the throat, lower than the rear and shoulder yoke.
    front_row = interp([(0, 975), (.03, 971), (.13, 941), (.32, 894), (.61, 831), (.76, 804),
                        (.785, 798), (.81, 789), (.92, 765), (1, 746)], t)
    row += (front_row-row)*max(0, co)**4.8
    row -= 23 * abs(si) ** 3 * max(0, 1 - 1.5 * t)
    x = rx * si
    fold = (3.2 * sin(0.045 * x + 0.006 * row) + 1.3 * sin(0.087 * x - row * 0.015))
    fold *= smooth(t / 0.10) * (.45 + .55 * gauss(abs(x) - 165, 94))
    return world(x, depth * co + fold * max(0, co), row)


cloth = [[shirt_point(j / 70, TAU * i / 200) for i in range(200)] for j in range(71)]
# Fold the upper rim down and inward so the inside of the neckline is hollow.
cloth.append([(p[0]*.90, p[1]*.86, p[2]-.35) for p in cloth[-1]])
cloth.append([(p[0]*.60, p[1]*.57, (1060-799)*SCALE) for p in cloth[-1]])
rings("02 | Cropped shirt and shoulders", cloth, shirt_stone)


def shirt_front(x, row, back=False):
    """Find the nearest frontal shirt depth at a chosen cloth landmark."""
    from math import asin
    low, high = 0, 1
    for _ in range(18):
        t = (low + high) / 2
        radius = interp(shirt_channels[0], t)
        angle = asin(min(.999, max(-.999, x / radius)))
        point = shirt_point(t, pi-angle if back else angle)
        if 1060 - point[2] / SCALE > row:
            low = t
        else:
            high = t
    return -point[1] / SCALE


def sheet(name, nu, nv, point, mat, thickness, inward=None):
    """Close a hand-shaped fabric slab with a second surface behind the face."""
    front, rear, faces = [], [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            x, depth, row = point(i / nu, j / nv)
            front.append(world(x, depth, row))
            dx, dd = inward(j/nv) if inward else (0, -1)
            rear.append(world(x + thickness*dx, depth + thickness*dd, row))
    width, offset = nu + 1, len(front)
    for j in range(nv):
        for i in range(nu):
            a = width * j + i
            f = (a, a + width, a + width + 1, a + 1)
            faces.extend([f, tuple(offset + k for k in reversed(f))])
    rim = list(range(width)) + [j * width + nu for j in range(1, nv + 1)]
    rim += list(range(offset - 2, offset - width - 1, -1))
    rim += [j * width for j in range(nv - 1, 0, -1)]
    for a, b in zip(rim, rim[1:] + rim[:1]):
        faces.append((a, b, b + offset, a + offset))
    return mesh(name, front + rear, faces, mat)


# Box placket follows the changing depth of the chest, including the lifted top.
def placket(u, v):
    row = 745 + v * 229
    x = -9 + u * 53 + 10 * v
    return (x, shirt_front(x, row) + 1 + 2.1 * sin(pi * u) ** .35, row)


sheet("03 | Shirt placket", 10, 36, placket, shirt_stone, 3)


def oval(name, x, depth, row, rx, ry, rz, mat):
    loops = []
    for i in range(25):
        a = -.4999 * pi + .9998 * pi * i / 24
        loops.append([world(x + rx * cos(a) * sin(TAU * j / 40),
                            depth + ry * cos(a) * cos(TAU * j / 40),
                            row - rz * sin(a)) for j in range(40)])
    return rings(name, loops, mat)


for idx, row in enumerate((772, 915), 1):
    x = 14 + idx * 3
    depth = shirt_front(x, row) + 4
    # Button profiles include a real recessed face and two shallow drill holes.
    loops = []
    profile = [(0, 10), (2, 11), (4, 11), (5, 9.8), (4, 8), (2.7, 6.9)]
    for d, r in profile:
        loops.append([world(x + r * sin(TAU * i / 40), depth + d, row - r * cos(TAU * i / 40))
                      for i in range(40)])
    rings(f"04.{idx} | Saucer button", loops, shirt_stone, reverse=True)
    for dx in (-2.4, 2.4):
        oval(f"04.{idx} | Button drill", x + dx, depth + 2.75, row, 1.15, .2, 1.35, iris)


# Head and throat are one continuous skin. Front relief is measured relative
# to the turning ellipses; profile has a receding temple, jaw angle and occiput.
head_section = [
    (83, 6, -5, 8), (96, 72, -5, 67), (125, 118, -3, 103),
    (158, 147, -3, 125), (198, 162, -3, 140), (249, 169, -3, 142),
    (299, 166, -2, 139), (341, 161, -5, 133), (392, 158, -5, 133),
    (434, 156, -1, 134), (487, 153, 4, 136), (530, 148, 11, 133),
    (565, 143, 14, 131), (595, 133, 12, 125), (622, 123, 9, 111),
    (654, 119, 6, 104), (688, 118, 15, 108), (721, 108, 18, 101),
    (752, 82, 12, 88), (770, 30, -3, 40),
]
head_channels = [[(p[0], p[i]) for p in head_section] for i in (1, 2, 3)]


def eye_edges(x):
    """Upper/lower lid edges, with a lower tear duct and asymmetric corners."""
    t = (abs(x) - 70) / 38
    center = 340 - 2.7 * t + 1.1 * sin(x / 42)
    arc = max(0, 1 - t * t) ** .68
    return center - 18 * arc, center + 13.2 * arc, t


def reference_planes():
    """Infer bounded *geometry* cues from raking light on the supplied portrait.

    Solve for shallow surface height along the upper-left illumination direction
    at scales between a skin fold and a cheek. Broad form, silhouette, features,
    unseen surfaces and all colors remain independently modeled. The reference
    image is removed immediately and is never a material or packed dependency.
    """
    reference = bpy.data.images.load(str(ROOT/"src/images/redesigned-lobby/main-lobby-bust.jpeg"))
    w, h = reference.size
    pixels = np.empty(w*h*4, dtype='float32')
    reference.pixels.foreach_get(pixels)
    bpy.data.images.remove(reference)
    rgb = pixels.reshape(h, w, 4)[::-1, :, :3]
    value = np.log(.09 + rgb @ np.array([.213, .715, .072]))
    kx, ky = np.meshgrid(TAU*np.fft.rfftfreq(w), TAU*np.fft.fftfreq(h))
    k2 = kx*kx+ky*ky
    derivative = .63*kx+.77*ky
    band = (1-np.exp(-k2*21**2/2))*np.exp(-k2*2.0**2/2)
    inv = -1j*derivative/(derivative**2+.19*k2+.000003)
    return np.clip(np.fft.irfft2(np.fft.rfft2(value)*band*inv, s=(h, w)), -9, 9)


reference_height = reference_planes()


def observed_folds(x, row):
    # The frontal photograph is a few degrees off axis. Tile the facial patch
    # through a mild projective warp around the existing anatomical landmarks.
    col = 373+x-.00055*x*x
    a, b = int(col), int(row)
    u, v = col-a, row-b
    h = ((1-u)*reference_height[b, a]+u*reference_height[b, a+1])*(1-v)
    h += ((1-u)*reference_height[b+1, a]+u*reference_height[b+1, a+1])*v
    ax = abs(x)
    skin = smooth((row-161)/43)*smooth((714-row)/50)*smooth((155-ax)/34)
    # Leave the glasses, nose and open eyes to their own modeled geometry.
    upper, lower, t = eye_edges(x)
    eye = gauss(t, 1.13)*gauss(row-(upper+lower)/2, 25)
    top_rim = gauss(row-(301+.0006*(ax-84)**2), 9)*smooth((150-ax)/10)
    low_rim = gauss(row-(389-.0041*(ax-75)**2), 12)*gauss(ax-75, 60)
    folds = 3.5 + 3.3*gauss(row-570, 60)*gauss(x, 92) + 1.8*gauss(row-284, 42)
    mouth_line = 478 + 49*min(1.2, ax/86)**2.65
    lip = gauss(row-mouth_line, 11)*gauss(x, 79)
    return folds*h*skin*(1-.94*eye)*(1-top_rim)*(1-low_rim)*(1-.75*lip)


def facial_relief(x, row):
    ax = abs(x)
    # Flatten the face plane and retain temples, orbital rims and diagonal cheekbones.
    d = 8 * gauss(row - 370, 152) * gauss(ax - 81, 45)
    d += 23 * gauss(ax - 110, 38) * gauss(row - 397 + .24 * (ax - 110), 36)
    d += 6 * gauss(ax-79, 34) * gauss(row-399, 17)
    d -= 3 * gauss(ax-108, 25)*gauss(row-429+.35*(ax-108), 7)
    d -= 14 * gauss(ax - 115, 28) * gauss(row - 467, 55)
    d += 15 * gauss(ax - 108, 35) * gauss(row - 526, 41)
    # Sweeping arches of the superciliary ridge, gathered above the glabella.
    brow_y = 300 - 25*sin(pi*min(1, ax/147)) + .10*max(0, ax-94) + 1.65*sin(.044*x)
    # Paired glabellar pads squeeze together over the depressed inner brows.
    crease = 8 + .0033*(row-292)**2
    d += 6.3*gauss(ax-crease-7.5, 9.8)*gauss(row-271, 24)
    d -= 4.3*gauss(ax-crease, 4.9)*gauss(row-268, 26)
    d += 17 * gauss(row - brow_y, 12) * gauss(ax - 64, 54)
    d += 11 * gauss(row - brow_y - 9, 15) * gauss(ax - 37, 32)
    d -= 5 * gauss(row - brow_y - 14, 5.5) * gauss(ax - 72, 42)
    frown_line = 8 + .0025 * (284 - row) ** 2
    d -= 3.5 * gauss(ax - frown_line, 5) * gauss(row - 271, 28)
    d += 3.2 * gauss(ax - frown_line - 8, 8) * gauss(row - 266, 32)
    for y, width in [(209, 73), (227, 100), (245, 71)]:
        curve = y + .0010 * ax * ax + 1.4 * sin(.084 * x + y)
        d -= 2.1 * gauss(row - curve, 2.8) * gauss(x, width)
        d += 1.7 * gauss(row - curve - 4.7, 4.5) * gauss(x, width)
    # Sculpt eyeball, lid margins, crease, and lower orbital bag into the face.
    upper, lower, t = eye_edges(x)
    d -= 17 * gauss(t, 1.30) * gauss(row - 342, 35)
    bag_y = 371 - 13 * min(1.6, t * t) - 2.5 * t
    d += 8.8 * gauss(row - bag_y, 9.5) * gauss(t, .92)
    d -= 3.8 * gauss(row - bag_y - 8.5, 3.6) * gauss(t, .93)
    # Bone, cartilaginous dorsum, broad tip, alae, two deep nostrils.
    d += 14 * gauss(x, 22) * gauss(row - 366, 57)
    d += 6.5 * gauss(ax - 34, 15) * gauss(row - 409, 16)
    d -= 5 * gauss(ax - 44, 6) * gauss(row - 410, 16)
    # Maxilla, downturned mouth and strong nasolabial folds ending beside the corners.
    naso = 44 + .46 * (row - 423) - .0007 * (row - 454) ** 2
    d += 14 * gauss(x, 82) * gauss(row - 468, 48)
    d += 8 * gauss(ax-97, 28)*gauss(row-527, 58)
    d += 8 * gauss(ax-55, 34)*gauss(row-537, 36)
    d += 13 * gauss(ax - naso - 13, 18) * gauss(row - 472, 54)
    d -= 4.5 * gauss(ax - naso, 8.3) * gauss(row - 475, 54)
    d += 3 * gauss(ax - 8, 4.3) * gauss(row - 451, 19)
    d -= 3 * gauss(x, 5.8) * gauss(row - 451, 20)
    mouth = 478 + 49 * min(1.2, ax / 86) ** 2.65 + 1.0 * sin(x * .051)
    lip = exp(-min((ax / 87) ** 14, 80))
    d += 7.3 * gauss(row - mouth + 7, 10) * lip
    d += 10.3 * gauss(row - mouth - 11.0, 15.5) * lip
    d += 12 * gauss(row - 527, 27)*gauss(x, 58)
    d -= 4.7 * gauss(row - mouth, 2.5) * lip
    d -= 3.8 * gauss(ax - 86, 7) * gauss(row - 528, 10)
    d -= 3.0 * gauss(row - mouth - 30, 9) * gauss(x, 57)
    # Puckered mentalis, paired marionette hollows and overlapping throat folds.
    d += 25 * gauss(x, 72) * gauss(row - 563, 40)
    d += 5.5 * gauss(ax - (78+.34*(row-541)), 9.5) * gauss(row-541, 18)
    d -= 3.7 * gauss(row-562+.4*(ax-98), 6.7)*gauss(ax-97, 20)
    d += 2.7 * gauss(ax-41, 21) * gauss(row-565, 21)
    d -= 7 * gauss(ax - (82 - .45 * (row - 545)), 7) * gauss(row - 555, 21)
    for y, amount, width in [(603, 8, 12), (635, 9, 11), (658, 4, 9)]:
        curve = y - .0034 * ax * ax + 2.3 * sin(.06 * x + y)
        d += amount * gauss(row - curve, width) * gauss(x, 107)
        d -= amount * .58 * gauss(row - curve - 9, width * .54) * gauss(x, 108)
    return d + observed_folds(x, row)


def head_depth(x, row):
    rx, center, radius = [interp(k, row) for k in head_channels]
    co = sqrt(max(.000001, 1 - min(.999999, (x / rx) ** 2)))
    return center + radius * co ** .73 + facial_relief(x, row) * smooth(co / .62)


def head_point(row, angle):
    rx, center, radius = [interp(k, row) for k in head_channels]
    co = cos(angle)
    x = rx * sin(angle)
    if co > 0:
        d = center + radius * co ** .73 + facial_relief(x, row) * smooth(co / .62)
    else:
        d = center + co * radius
    # The hidden scalp rolls into the combed shell at its hairline.
    boundary = hair_bound(angle)
    edge_row = 259 - 188 * cos(boundary) - 5 * sin(angle) * sin(boundary)
    inside = smooth((edge_row - row) / 42)
    x *= 1 - .40 * inside
    d = d * (1 - .40 * inside) - 20 * inside
    # Jowl narrows around the mandibular angle behind the forward cheeks.
    x *= 1 - .064*gauss(row-588, 54)*abs(sin(angle))**1.7
    # Lift the jaw angle beneath the ear, with a longer central underchin.
    row -= 13 * abs(sin(angle))**1.8 * gauss(row-578, 45)
    return world(x, d, row)


def hair_bound(a):
    return interp([(-1, 2.40), (-.58, 2.16), (-.18, 1.91), (.11, 1.77),
                   (.37, 1.48), (.70, 1.14), (1, 1.015)], cos(a)) + .025 * sin(3*a+.55) + .025*sin(7*a)*max(0, cos(a))


head = rings("05 | Portrait · face, jowls and throat", [
    [head_point(770 - 687 * j / 245, TAU * i / 240) for i in range(240)]
    for j in range(246)], stone)


# Sculpt the nose volumetrically. Blend inclined bridge, tip and lobes, then
# carve two oblique nostrils through the underside. OpenVDB ships with Blender.


def join_clay(a, b, radius):
    h = np.maximum(radius-np.abs(a-b), 0.0) / radius
    return np.minimum(a, b) - h*h*radius*.25


spacing = 1.45
origin = np.array([-62., 109., 286.])
ix, iy, iz = np.indices((87, 84, 111), dtype=float)
xx, dd, rr = ix*spacing+origin[0], iy*spacing+origin[1], iz*spacing+origin[2]


def ellipsoid(dx, dy, dz, radii):
    a, b, c = radii
    return (np.sqrt((dx/a)**2+(dy/b)**2+(dz/c)**2)-1)*min(a, b, c)


# Bulb and bridge run diagonally out from the glabella.
tilt = .31
nose_field = ellipsoid(xx, dd-156 - tilt*(rr-361), rr-361, (17.5, 20, 59))
nose_field = join_clay(nose_field,
                       ellipsoid(xx, dd-173-.34*(rr-392), rr-392, (20, 26, 29)), 7)
nose_field = join_clay(nose_field,
                       ellipsoid(xx, dd-189, rr-412, (24, 25, 17.5)), 6)
nose_field = join_clay(nose_field,
                       ellipsoid(xx, dd-173, rr-420, (10.5, 21, 12)), 3.5)
nose_field = join_clay(nose_field,
                       ellipsoid(np.abs(xx)-32, dd-161, rr-409, (17.5, 22, 14)), 6.3)
# Base cheek patch rolls the outside of each wing flush into the actual head.
skin = np.asarray([[head_depth(x, row) for row in rr[0, 0, :]] for x in xx[:, 0, 0]])[:, None, :]
base_patch = np.maximum.reduce(np.broadcast_arrays(dd-skin+3, 122-dd,
                                                   (abs(xx)-51)*1.8, (abs(rr-372)-68)*1.8))
nose_field = join_clay(nose_field, base_patch, 6.8)
# The nostril axis exits below and in front, leaving a rounded outer sill.
nare = ellipsoid(abs(xx)-26, dd-172-.84*(rr-421), rr-422, (9, 11.8, 11))
nose_field = -join_clay(-nose_field, nare, 2.6)
grid = openvdb.FloatGrid(20)
grid.copyFromArray(np.clip(nose_field, -20, 20).astype('float32'))
verts, tris, quads = grid.convertToPolygons(0.0, .12)
mesh("05b | Dorsum, alae and nose tip", [world(*(p*spacing+origin)) for p in verts],
     list(tris)+list(quads), stone)


def corneal_depth(x, row):
    upper, lower, t = eye_edges(x)
    center = .5 * (upper+lower)
    r2 = t*t + ((row-center) / 18.7)**2
    base = head_depth(x, row)
    return base + 8 + 18.5 * max(0, 1 - .90 * r2)


# Seat each carved iris low in its aperture and tip the corneal tangent
# toward the across-room camera, about 16.5 degrees below the eyes.
gaze_row = 345.3
gaze_x = 68.1
gaze_slope = {}
for side in (-1, 1):
    x = side*gaze_x
    slope_x = (corneal_depth(x+.15, gaze_row)-corneal_depth(x-.15, gaze_row))/.30
    slope_row = (corneal_depth(x, gaze_row+.15)-corneal_depth(x, gaze_row-.15))/.30
    gaze_slope[side] = ((x*SCALE+1.6)/42-slope_x, -.296-slope_row)


def eye_surface(x, row):
    side = -1 if x < 0 else 1
    dx, dr = x-side*gaze_x, row-gaze_row
    correction = gaze_slope[side][0]*dx + gaze_slope[side][1]*dr
    return corneal_depth(x, row) + correction*gauss(dx, 26)*gauss(dr, 18)


for side in (-1, 1):
    # Fill the palpebral opening with a convex globe; surround it with a curved
    # lid that rolls up from the eyeball and blends into the orbital socket.
    globe, lid = [], []
    for j in range(20):
        t = .001 + .999*j/19
        loop = []
        for i in range(96):
            a = TAU*i/96
            x = side*(70 + 38*t*cos(a))
            up, lo, _ = eye_edges(x)
            c = (up+lo)/2
            row = c + (lo-up)*.5*sin(a)*t / max(.01, sqrt(1-(t*cos(a))**2)) if abs(sin(a)) > .00001 else c
            row = max(up, min(lo, row))
            loop.append(world(x, eye_surface(x, row), row))
        globe.append(loop)
    rings(f"06 | Eye globe {side:+d}", globe, stone, reverse=side < 0)
    for j in range(24):
        v = j/23
        loop = []
        for i in range(96):
            a = TAU*i/96
            x = side*(70+38*cos(a))
            up, lo, _ = eye_edges(x)
            row = up if sin(a) < 0 else lo
            edge = eye_surface(x, row)
            x += side*10*cos(a)*v
            row += (15 if sin(a) < 0 else 11)*sin(a)*v
            soft = smooth(v)
            d = edge*(1-soft) + (head_depth(x, row)-1)*soft
            d += (5 if sin(a) < 0 else 3.6)*sin(v*pi)
            loop.append(world(x, d, row))
        lid.append(loop)
    # Only the skin strip is visible. An internal skirt closes both ends.
    lid.append([(p[0], p[1]+.19, p[2]) for p in lid[-1]])
    lid.append([(p[0], p[1]+.19, p[2]) for p in lid[0]])
    n = len(lid[0])
    faces = []
    for j in range(len(lid)):
        for i in range(n):
            k = (i+1) % n
            after = (j+1) % len(lid)
            faces.append((j*n+i, j*n+k, after*n+k, after*n+i))
    mesh(f"06 | Upper and lower lid {side:+d}", [p for loop in lid for p in loop], faces, stone)
    x0, row0 = side*gaze_x, gaze_row
    for label, profile, mat in [
        ("Limbus", [(13.8, .12), (13.1, .56), (12.4, .85)], frame_stone),
        ("Iris", [(12.6, .66), (11.1, 1.65), (10, 1.2), (6.85, 1.35)], iris),
            ("Pupil", [(7.15, 1.32), (6.1, 1.57), (3.3, 1.33), (.1, 1.23)], pupil)]:
        loops = []
        for radius, offset in profile:
            loop = []
            for i in range(64):
                a = TAU*i/64
                x, row = x0+radius*sin(a), row0-.96*radius*cos(a)
                # Roll the submerged portion under the actual lower lid.
                _, lower, _ = eye_edges(x)
                buried = 2.6*max(0, row-lower+1.25)
                loop.append(world(x, eye_surface(x, row)+offset-buried, row))
            loops.append(loop)
        rings(f"06 | {label} {side:+d}", loops, mat, reverse=True)


# Ears attach on a tilted plane. A radial cartilage field shapes the protruding
# helix, concha, tragus, antihelix and lobule on each ear, including its rear.
for side in (-1, 1):
    loops = []
    for j in range(62):
        r = .003 + .997 * j / 61
        loop = []
        for i in range(112):
            a = TAU * i / 112
            u, v = sin(a) * r, cos(a) * r
            x = 161 + 30 * u * (1 + .13 * v) + 6 * v
            row = 403 - 66 * v
            d = 16 - 30 * u - 10 * v
            d += 15.4 * gauss(r - (.84-.09*max(0, -v)), .13)
            d += 12 * gauss(u - .14 - .22*sin(3*v+.2), .18) * gauss(v - .04, .60)
            d += 9.7 * gauss(u + .11 + .62*v, .17) * gauss(v - .39, .31)
            d += 13 * gauss(u + .48, .20) * gauss(v + .065, .27)
            d -= 15 * gauss(u + .13, .28) * gauss(v - .08, .32)
            d += 11 * gauss(v + .67, .32) * gauss(u + .05, .68)
            loop.append(world(side * x, d, row))
        loops.append(loop)
    # Keep the rear shell behind the deepest concha at the same projected
    # landmark. Contracting only the rim to form the back crosses the cavity.
    for j in range(20, -1, -1):
        r = .003 + .997*j/20
        loop = []
        for i in range(112):
            a = TAU*i/112
            u, v = sin(a)*r, cos(a)*r
            x = 161 + 30*u*(1+.13*v) + 6*v
            row = 403 - 66*v
            depth = 16 - 30*u - 10*v - (19 + 7*(1-r*r))
            loop.append(world(side*x, depth, row))
        loops.append(loop)
    rings(f"07 | Modeled ear {'L' if side < 0 else 'R'}", loops, stone, reverse=(side < 0))


# Combed shell. Meridians of an asymmetric displaced dome spiral back from a
# scalloped hairline into a crown behind the skull. The same waves wrap the nape.
# The broad, unequal locks are divided at the hairline, like the front
# reference. Their roots lie on the scalp. Each forelock first rises out
# over the forehead, then folds back onto the crown. The temple locks
# travel toward the back of the head; the nape follows the opposite arc.
lock_divisions = [-pi, -2.79, -2.39, -2.07, -1.76, -1.54, -1.32, -1.07, -.81,
                  -.55, -.29, -.055, .21, .47, .76, 1.04, 1.30, 1.55, 1.83,
                  2.15, 2.48, 2.78, pi]


def lock_fraction(root_angle):
    signed = (root_angle+pi) % TAU-pi
    index = min(len(lock_divisions)-2, bisect_right(lock_divisions, signed)-1)
    low, high = lock_divisions[index:index+2]
    return index, (signed-low)/(high-low)


def hair_point(t, root_angle, inset=0):
    progress = 1-t
    root_cos = cos(root_angle)
    front = max(0, root_cos)
    index, fraction = lock_fraction(root_angle)
    # Bend entire sheaves backward at the temples and break the forelock's
    # symmetry with a shallow S from the hairline to the off-center whorl.
    a = root_angle + (.36*sin(root_angle)+.20*front)*sin(pi*progress)
    a += (.13*sin(2*root_angle+.4)+.085*front)*sin(TAU*progress)
    a += .32*front**3*sin(TAU*progress+.25)*sin(pi*progress)
    a += .11*sin(3*root_angle-.45)*sin(pi*progress)
    co, si = cos(a), sin(a)
    phi = hair_bound(root_angle)*t
    bulge = sin(pi*fraction)**.72
    channel = gauss(min(fraction, 1-fraction), .072)
    comb = .8*sin(TAU*4*fraction+.75*sin(TAU*progress+root_angle))
    comb += .42*sin(TAU*8*fraction-2*progress)
    shoulder = .5+.5*sin(index*1.77)
    weight = smooth(phi/.28)*smooth((progress+.012)/.10)
    relief = ((5.0+4.2*shoulder)*bulge-2.0*channel+comb)*weight
    r = 177 + 5*front*sin(phi)
    x = r*sin(phi)*si-14*cos(phi)**3
    depth = 159*sin(phi)*co-10-45*cos(phi)**3
    row = 259-188*cos(phi)-5*si*sin(phi)
    # A broad front crest rises before the whorl, which turns down at the back.
    row += 17*smooth((progress-.65)/.35)
    row -= 10*gauss(progress-.56, .22)*front
    depth -= 9*smooth((progress-.66)/.34)

    # Fit the root ring to each actual forehead and temple landmark.
    rx, center, radius = [interp(k, row) for k in head_channels]
    seat = smooth((t-.71)/.29)
    scalp_depth = center+radius*(max(0, co)**.73 if co > 0 else co)
    x = x*(1-seat)+(rx+1.4)*si*seat
    depth = depth*(1-seat)+(scalp_depth+1.4*co)*seat

    # The lifted front has an intentional forward overhang above its roots.
    # The wider upper arc carries that volume back into the crown.
    roll = gauss(progress-.21, .21)*smooth(progress/.16)*front**.58
    depth += 48*roll + 18*gauss(progress-.37, .20)*front*smooth(progress/.18)
    row -= 16*roll + 8*gauss(progress-.39, .20)*front*smooth(progress/.18)
    x += 4.6*si*roll
    root_wave = gauss(progress, .12)*(2.7*cos(TAU*fraction)+2.4*sin(3*root_angle))
    row += root_wave*front
    x += (relief-inset)*si*sin(phi)
    depth += (relief-inset)*co*sin(phi)
    row -= (relief-inset)*cos(phi)
    return world(x, depth, row)


hair_loops = [[hair_point(1, TAU*i/720, 13) for i in range(720)]]
hair_loops += [[hair_point(1-.9998*j/98, TAU*i/720) for i in range(720)] for j in range(99)]
# Preserve the approved overall bust height while redistributing hair volume.
height_adjustment = 19.824-max(p[2] for row in hair_loops for p in row)
hair_loops = [[(x, y, z+height_adjustment*smooth((z-17.0)/2.6)) for x, y, z in row] for row in hair_loops]
rings("08 | Swept hair · crown, temples and nape", hair_loops, hair_stone)


def catmull(points, t, cyclic=False):
    n = len(points)
    scaled = t * (n if cyclic else n - 1)
    i, f = int(scaled), scaled % 1

    def get(j):
        return Vector(points[j % n if cyclic else min(n - 1, max(0, j))])
    a, b, c, d = (get(j) for j in (i - 1, i, i + 1, i + 2))
    return .5 * (2*b + (c-a)*f + (2*a - 5*b + 4*c-d)*f*f + (-a+3*b-3*c+d)*f*f*f)


def tube(name, path, radius, mat, segments=64, sides=10, cyclic=False):
    """Sweep an elliptical chisel section in a stable local frame."""
    grid = []
    for j in range(segments if cyclic else segments + 1):
        t = j / segments
        wrap = (lambda u: u % 1) if cyclic else (lambda u: max(0, min(1, u)))
        center = Vector(path(t))
        tangent = (Vector(path(wrap(t + .0001))) - Vector(path(wrap(t - .0001)))).normalized()
        ref = Vector((0, 1, 0)) if abs(tangent.y) < .86 else Vector((0, 0, 1))
        normal = tangent.cross(ref).normalized()
        binormal = tangent.cross(normal).normalized()
        r1, r2 = radius(t)
        grid.append([center + normal * (r1 * SCALE * cos(TAU * i / sides))
                     + binormal * (r2 * SCALE * sin(TAU * i / sides)) for i in range(sides)])
    if not cyclic:
        return rings(name, grid, mat)
    faces = []
    for j in range(segments):
        for i in range(sides):
            n, k = (j + 1) % segments, (i + 1) % sides
            faces.append((j*sides+i, j*sides+k, n*sides+k, n*sides+i))
    return mesh(name, [p for ring in grid for p in ring], faces, mat)


# Rounded rectangular rims have a thick brow, a fine lower edge, an integral
# saddle bridge and separate curved temples. Open rims preserve orbital detail.
frame_nodes = [(16, 311), (39, 304), (86, 300), (129, 302),
               (144, 308), (145, 328), (141, 355), (133, 376),
               (118, 385), (80, 389), (47, 386), (30, 376), (21, 355), (15, 331)]


def lens_depth(x, row):
    return 165 - .00162 * x * x + .07 * (337 - row)


for side in (-1, 1):
    def rim(t):
        x, row = catmull(frame_nodes, t, True)
        return world(side * x, lens_depth(x, row), row)

    def section(t):
        _, row = catmull(frame_nodes, t, True)
        weight = smooth((357 - row) / 51)
        return 2.65 + 2.4 * weight, 2.8 + 1.7 * weight

    tube(f"09 | Spectacle rim {'L' if side < 0 else 'R'}", rim, section, frame_stone, 160, 12, True)
    arm = [(141, lens_depth(141, 315), 315), (149, 115, 314),
           (157, 91, 316), (166, 48, 322), (179, 15, 329),
           (183, -8, 337), (182, -22, 361)]
    tube(f"09 | Temple {'L' if side < 0 else 'R'}",
         lambda t: world(*[v if j else side * v for j, v in enumerate(catmull(arm, t))]),
         lambda t: (3.6 - t, 4.4 - 1.8 * t), frame_stone)
bridge = [(-20, 165, 311), (-14, 169, 316), (-9, 170, 318),
          (0, 171, 317), (9, 170, 318), (14, 169, 316), (20, 165, 311)]
tube("09 | Saddle bridge", lambda t: world(*catmull(bridge, t)),
     lambda t: (6.2 - 1.3*sin(pi*t), 4.4), frame_stone, 60, 12)


# Draped collar panels run from either side of the throat to the nape. The
# tips project from the chest, casting an actual undercut shadow onto the shirt.
outer = [(4, 749), (33, 716), (77, 691), (118, 653), (151, 684),
         (209, 717), (198, 661), (166, 602), (145, 574), (127, 553)]
inner = [(5, 744), (21, 721), (55, 684), (93, 657), (115, 627),
         (126, 597), (130, 584), (133, 570), (130, 559), (127, 552)]


# Parameterize both edges by the same angle about the throat. Matching edges
# by control-point number can fold a triangle back across the collar point.
def radial_guide(points):
    return [(atan2(x, row-516), hypot(x, row-516)) for x, row in points]


inside_edge, outside_edge = radial_guide(inner), radial_guide(outer)
start_angle = max(inside_edge[0][0], outside_edge[0][0])
end_angle = min(inside_edge[-1][0], outside_edge[-1][0])
for side in (-1, 1):
    def collar(u, v):
        angle = start_angle + (end_angle-start_angle)*v
        inner_radius = interp(inside_edge, angle)
        outer_radius = max(inner_radius+1.8, interp(outside_edge, angle))
        r = inner_radius + (outer_radius-inner_radius)*u
        x, row = r*sin(angle), 516+r*cos(angle)
        chest = shirt_front(x, row)
        neck = head_depth(min(x, interp(head_channels[0], row)*.996), row)
        taper = smooth((.90-v)/.23)
        inner_depth = chest+4 + max(0, neck-chest-2)*taper
        depth = (1-u)*inner_depth + u*(chest+5.5)
        depth += (8+5*sin(v*pi))*sin(pi*u)*sin(pi*v)
        return side*x, depth, row + (3*sin(v*pi) if side < 0 else 0)

    sheet(f"10 | Point collar {'L' if side < 0 else 'R'}", 15, 80, collar, shirt_stone, 3.5)


# The folded back collar joins the two front leaves and follows the nape.
# A shallow yoke seam and central box pleat finish the walk-around view.
def back_collar(u, v):
    a = 1.04 + (TAU-2.08)*v
    front = max(0, cos(a))
    side = smooth((abs(sin(a))-.47)/.5)
    taper = .35+.65*smooth(min(v, 1-v)/.17)
    # Use one elliptic radial coordinate for both leaf thickness and drape.
    # Radius and height then stay single-valued at every angle, including
    # the tapered tips tucked underneath the two point leaves.
    top_row = 545 + 63*side + 35*front*front
    row = top_row + u*taper*(46-19*side)
    r = (145-18*side-12*front) + taper*((24-3*side)*u+4.5*sin(pi*u))
    return r*sin(a), 10+.91*r*cos(a), row


def nape_inward(v):
    a = 1.04 + (TAU-2.08)*v
    return -sin(a), -.91*cos(a)


sheet("10 | Collar leaf at the nape", 12, 112, back_collar, shirt_stone, 2.8, nape_inward)


def yoke_curve(t):
    x = 534*(t-.5)
    row = 696-14*(x/267)**2
    return world(x, shirt_front(x, row, back=True)-.65, row)


tube("11 | Rear shoulder yoke", yoke_curve,
     lambda t: (.5+.6*sin(pi*t), .7+.75*sin(pi*t)), shirt_stone, 102, 8)


def back_pleat(u, v):
    x = (u-.5)*(27-14*v)
    row = 696+242*v
    seam = 1.6*sin(pi*u)*sin(pi*v)**.5
    return x, shirt_front(x, row, back=True)-.2-seam, row


sheet("11 | Pressed box pleat", 8, 30, back_pleat, shirt_stone, 2)

# Three original periodic stone maps are packed in the editable and exported
# in the GLB. Shared continuous planar coordinates avoid seams on facial cuts.


def limestone_map(mat, seed):
    rng = np.random.default_rng(seed)
    n = 384
    gy, gx = np.mgrid[0:n, 0:n] / n
    fx, fy = np.meshgrid(np.fft.rfftfreq(n)*n, np.fft.fftfreq(n)*n)
    radius2 = fx*fx + fy*fy

    def field(frequency):
        spectrum = np.fft.rfft2(rng.normal(size=(n, n)))
        values = np.fft.irfft2(spectrum*np.exp(-radius2/(2*frequency**2)), s=(n, n))
        return (values-values.mean())/values.std()

    cloud, sediment, grit = field(2.3), field(10), field(42)
    vein = np.exp(-(np.sin(TAU*(gx+gy)+.67*cloud+.19*sediment)/.079)**2)
    density = 1 + .022*cloud + .012*sediment + .010*grit - .034*vein
    rgba = np.ones((n, n, 4), dtype=np.float32)
    for c in range(3):
        rgba[:, :, c] = 1.055*np.clip(density * mat.diffuse_color[c], 0, 1)**(1/2.4)-.055
    img = bpy.data.images.new(mat.name + " · original grain", width=n, height=n, alpha=False)
    # Image pixel floats are linear, and Blender applies the sRGB transfer at pack.
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = img
    shader = mat.node_tree.nodes.get("Principled BSDF")
    mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])


for index, mat in enumerate((stone, hair_stone, shirt_stone)):
    limestone_map(mat, 2001 + index)
for obj in sculpt.objects:
    data = obj.data
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    # Recalculation makes neighbors consistent, but very thin closed shells
    # also need the unambiguous signed-volume test for the exterior direction.
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    uv = data.uv_layers.new(name="Stone projection")
    coords = []
    for loop in data.loops:
        x, y, z = data.vertices[loop.vertex_index].co
        coords.extend(((x + .43*y)/6.8, (z - .72*y)/6.8))
    uv.data.foreach_set('uv', coords)
    data.update()


# A baked, tangent-space chisel grain follows each lock. It preserves the
# finer swept ridges at floor distance without tessellating every strand.
hair_obj = next(obj for obj in sculpt.objects if obj.name.startswith("08"))
flow_uv = hair_obj.data.uv_layers.new(name="Lock direction")
for polygon in hair_obj.data.polygons:
    indices = list(polygon.loop_indices)
    cols = [hair_obj.data.loops[k].vertex_index % 720 for k in indices]
    wraps = max(cols)-min(cols) > 360
    for k, col in zip(indices, cols):
        ring = hair_obj.data.loops[k].vertex_index // 720
        phi_fraction = 1-min(1, max(0, (ring-1)/98))
        flow_uv.data[k].uv = (1.0 if wraps and col == 0 else col/720, phi_fraction)
height, width = 512, 1024
vv, uu = np.mgrid[0:height, 0:width]
a = TAU*uu/width
t = vv/height
boundary = np.array([hair_bound(theta) for theta in a[0]])[None, :]
phi = boundary*t
# The secondary chisel grooves share the lock coordinates of the sculpt.
# Their direction follows the modeled outward roll and rearward sweep.
fraction = np.array([lock_fraction(theta)[1] for theta in a[0]])[None, :]
strand = TAU*6*fraction + .57*np.sin(2*phi+a) + .60*np.sin(2*TAU*fraction-phi)
strand += .48*np.sin(TAU*3*fraction+3*phi)*np.cos(2*a-phi)
envelope = np.clip(t*5, 0, 1)*np.clip((1.06-t)*7, 0, 1)
grooves = (.60*np.sin(strand)+.22*np.sin(1.999*strand+.65*np.cos(a+phi))
           + .18*np.cos(3*strand+2*phi))*envelope
dx = .69*(np.roll(grooves, -1, 1)-np.roll(grooves, 1, 1))
dy = .47*np.gradient(grooves, axis=0)
ln = np.sqrt(1+dx*dx+dy*dy)
buf = np.ones((height, width, 4), dtype='float32')
buf[:, :, 0] = .5-.5*dx/ln
buf[:, :, 1] = .5-.5*dy/ln
buf[:, :, 2] = .5+.5/ln
normal_img = bpy.data.images.new("Combed locks · chisel normal", width=width, height=height, alpha=False)
normal_img.colorspace_settings.name = 'Non-Color'
normal_img.pixels.foreach_set(buf.ravel())
normal_img.pack()
nodes = hair_stone.node_tree.nodes
links = hair_stone.node_tree.links
uv_node = nodes.new('ShaderNodeUVMap')
uv_node.uv_map = flow_uv.name
normal_tex = nodes.new('ShaderNodeTexImage')
normal_tex.image = normal_img
links.new(uv_node.outputs['UV'], normal_tex.inputs['Vector'])
normal_node = nodes.new('ShaderNodeNormalMap')
normal_node.uv_map = flow_uv.name
normal_node.inputs['Strength'].default_value = .34
links.new(normal_tex.outputs['Color'], normal_node.inputs['Color'])
links.new(normal_node.outputs['Normal'], nodes.get('Principled BSDF').inputs['Normal'])


# Reduce smooth areas while preserving the authored eyelid cuts, hair waves
# and drapery in denser areas. The dense editable meshes remain in the .blend.
for obj in sculpt.objects:
    # Give silhouette and expression most of the mesh budget. Tiny drills,
    # buttons, temple arms and folded cloth can share far fewer triangles.
    group = obj.name.split(" ", 1)[0].split(".", 1)[0]
    budgets = {"01": 2600, "02": 4400, "03": 600, "04": 330, "05": 18800, "05b": 3800,
               "06": 1150, "07": 2950, "08": 18100, "09": 1700, "10": 1900, "11": 900}
    target = budgets[group]
    obj.data.calc_loop_triangles()
    original = len(obj.data.loop_triangles)
    if original > target:
        mod = obj.modifiers.new("Adaptive export tessellation", 'DECIMATE')
        mod.ratio = target/original
        mod.use_collapse_triangulate = True


def stage_disk(name, radius, heights, mat):
    return cross_sections(name, [(1060-z/SCALE, radius, radius, 0)
                                 for z in heights], mat, 160, stage)


stage_disk("Round staging block", 390, (-2.65, -.12), wall)
stage_disk("Inset bronze rim", 392, (-.19, -.11), amber)
stage_disk("Contact slab", 385, (-.12, 0), wall)


def box(name, location, dimensions, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    stage.objects.link(obj)
    obj.dimensions = dimensions
    obj.data.materials.append(mat)
    return obj


floor_z = -2.65
box("Floor · one-stud inlay grid", (0, 0, floor_z-.2), (125, 125, .4), slate)
# Broad-jointed floor tiles and plain wall pilasters provide perspective.
for pos in range(-48, 49, 4):
    box("Four stud floor joint X", (pos, 0, floor_z + .004), (.022, 98, .012), wall)
    box("Four stud floor joint Y", (0, pos, floor_z + .004), (98, .022, .012), wall)
box("Gallery scale wall", (0, 12.6, 18), (98, .5, 44), wall)
for x in (-24, -16, -9, 9, 16, 24):
    box("Wall reveal", (x, 12.31, 18), (.035, .06, 44), slate)
for x in (-10.2, 10.2):
    box("Five-stud height gauge", (x, -.4, floor_z + 2.5), (.16, .16, 5), amber)
    for tick in range(1, 6):
        box("One stud graduation", (x, -.50, floor_z + tick - .035), (.42, .18, .07), amber)
    box("Gauge foot", (x, -.4, floor_z + .08), (1.05, .7, .16), amber)


def camera(name, location, target, lens, ortho=None):
    data = bpy.data.cameras.new(name)
    obj = bpy.data.objects.new(name, data)
    rig.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    data.lens = lens
    if ortho:
        data.type = 'ORTHO'
        data.ortho_scale = ortho
    return obj


front = camera("A1 · Portrait", (-4.8, -54, 12.3), (0, 0, 9.95), 70, 22.3)
quarter = camera("A1 · Three quarters", (28, -40, 14), (0, 0, 10), 70, 22.4)
detail = camera("A1 · Hair roll and downward gaze", (-15.5, -38, 17.9), (0, -.55, 16.35), 84, 8.9)
arrival = camera("A2 · Player eye 4.5 studs above floor", (-1.6, -45, floor_z+4.5), (0, 0, 8.85), 38)


def area(name, location, energy, size, tint, target):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.shape, data.size, data.color = energy, 'DISK', size, tint
    obj = bpy.data.objects.new(name, data)
    rig.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


area("Window · upper left", (-16, -13, 25), 6200, 7.2, (1, .93, .82), (0, 0, 10))
area("Atelier bounce", (12, -9, 13), 1050, 13, (.76, .83, 1), (0, 0, 9))
area("High rim", (3, 8, 29), 4600, 10, (1, .85, .64), (0, 0, 13))
area("Soft front", (-6, -18, 7), 240, 13, (1, .92, .82), (0, 0, 9))

scene.world = bpy.data.worlds.new("Neutral studio atmosphere")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.31, .34, .37, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .23
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 5
scene.view_settings.view_transform = 'AgX'

# Give the editable file a clean, orbitable first view and a central foot pivot.
for obj in bpy.context.selected_objects:
    obj.select_set(False)
bpy.context.view_layer.objects.active = head
for screen in bpy.data.screens:
    for area_ui in screen.areas:
        if area_ui.type == 'VIEW_3D':
            space = area_ui.spaces.active
            space.region_3d.view_rotation = front.rotation_euler.to_quaternion()
            space.region_3d.view_distance = 31
            space.region_3d.view_location = (0, 0, 10)
            space.region_3d.view_perspective = 'ORTHO'
            space.shading.color_type = 'MATERIAL'
            space.overlay.show_overlays = False
# Hidden backdrop panels still render in the review cameras. They cannot
# obstruct the opening solid viewport when the user orbits behind the head.
for helper in stage.objects:
    if helper.name.startswith(("Gallery scale wall", "Wall reveal")):
        helper.hide_set(True)

pivot = bpy.data.objects.new("Lobby Bust · base center", None)
pivot.empty_display_type = 'PLAIN_AXES'
pivot.empty_display_size = .6
for part in list(sculpt.objects):
    part.parent = pivot
sculpt.objects.link(pivot)

scene.camera = front
scene.render.resolution_x, scene.render.resolution_y = 800, 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)
for obj in sculpt.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format='GLB', use_selection=True,
                          export_apply=True, export_cameras=False, export_lights=False,
                          export_yup=True, export_animations=False)
# Update only this pair of content hashes when intentionally rebuilding it.
manifest_path = ROOT / "assets/manifest.json"
manifest = json.loads(manifest_path.read_text())
records = {entry["local_path"]: entry for entry in manifest["assets"]}
for artifact in (SOURCE, EXPORT):
    record = records[artifact.relative_to(ROOT).as_posix()]
    record["sha256"] = sha256(artifact.read_bytes()).hexdigest()
manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
print("P20_SOURCE_AND_EXPORT_READY", flush=True)

if "--no-render" not in sys.argv:
    for cam, name, size in [(front, "front", (800, 1000)), (quarter, "three-quarter", (800, 1000)),
                            (arrival, "player-eye", (1120, 740)), (detail, "hair-and-gaze", (920, 880))]:
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = size
        if "--preview" in sys.argv:
            scene.cycles.samples = 6
            scene.render.resolution_percentage = 55
        scene.render.filepath = str(VIEWS / (name + ".png"))
        bpy.ops.render.render(write_still=True)
