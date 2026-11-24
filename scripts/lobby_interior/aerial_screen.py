"""Render the original fictional landscape printed on P21's television screen.

Run in a fresh Blender 5.3 background process. The temporary diorama provides
real terrain, roofs, and shadows at one fixed angle. Only its four-by-three
green phosphor still is used by the lobby. The seed fixes layout and grain.
"""

from math import cos, sin
from pathlib import Path
import random
import struct
import tempfile
import zlib

import bpy
from mathutils import Vector
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/blender/lobby-interior/aerial-screen.png"
WIDTH, HEIGHT = 640, 480
RNG = random.Random(2101)


def height(x, y):
    """Layer flat-topped bluffs around a low valley; works on scalars or arrays."""
    ridge = .8 * np.sin(.19*x + .09*y) + .6 * np.sin(.26*y - .13*x)
    soil = .18*np.sin(x*.26) + .14*np.cos(y*.33 + .09*x)
    for cx, cy, rx, ry, top in [
        (-32, 11, 12, 15, 10), (-16, 40, 15, 8, 13),
        (16, 57, 13, 11, 17), (39, 20, 8, 18, 8), (-48, 52, 12, 14, 15),
    ]:
        distance = (abs((x-cx)/rx)**4 + abs((y-cy)/ry)**4)**.25
        edge = 1.09 - distance + .065*ridge + .02*np.sin(.63*y+.58*x)
        wall = np.clip(edge*5.2, 0, 1)
        terraces = wall + .018*np.sin(wall*40)*np.sin(np.pi*wall)
        soil = soil + top*terraces + 2.1*np.clip((edge+.46)*1.9, 0, 1)
    return soil


def road_x(y):
    return -4 + 6*np.sin(y*.051+.7) + 2*np.sin(y*.11)


def ground():
    """Construct and color the landscape with a winding unpaved road."""
    x, y = np.meshgrid(np.linspace(-95, 95, 380), np.linspace(-66, 99, 330))
    z = height(x, y)
    indices = np.arange(x.size).reshape(x.shape)
    quads = np.stack((indices[:-1, :-1], indices[:-1, 1:], indices[1:, 1:], indices[1:, :-1]), axis=2)
    mesh = bpy.data.meshes.new("Mesa valley")
    mesh.from_pydata(np.stack((x, y, z), axis=2).reshape(-1, 3).tolist(), [], quads.reshape(-1, 4).tolist())
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.collection.objects.link(obj)
    rand = np.random.default_rng(2102)
    tone = .28 + .04*np.sin(x*.79+y*.62) + .024*np.sin(y*1.44-x*1.12) + rand.normal(0, .047, x.shape)
    tone += .065*np.cos(z*2.7)*np.minimum(1, z/3)
    road = np.clip((2.4 + .25*np.cos(y*.24)-abs(x-road_x(y)))*2.2, 0, 1)
    tone = tone*(1-road) + (.57 + .035*np.sin(y*.4))*road
    gray = np.repeat(np.clip(tone, .08, 1)[..., None], 4, axis=2)
    gray[:, :, 3] = 1
    color = mesh.color_attributes.new(name="Earth", type="FLOAT_COLOR", domain="POINT")
    color.data.foreach_set("color", gray.astype(np.float32).ravel())
    mat = bpy.data.materials.new("Dry ground and road")
    mat.use_nodes = True
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = color.name
    mat.node_tree.links.new(attr.outputs["Color"],
                            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mesh.materials.append(mat)


def gray_material(name, value):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (value, value, value, 1)
    return mat


def box(name, center, size, material, angle):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    obj.rotation_euler.z = angle
    obj.data.materials.append(material)


def yard(x, y, walls, roof, dark):
    """A stepped adobe roof, a parapet, and a shadowed framed doorway."""
    w, d, h = RNG.uniform(2, 4.8), RNG.uniform(2.3, 4), RNG.uniform(1.4, 3.1)
    corners = [float(height(x+dx, y+dy)) for dx in (-w*.55, w*.55) for dy in (-d*.55, d*.55)]
    if max(corners)-min(corners) > .7 or max(corners) > 3:
        return
    a = RNG.uniform(-.32, .32)
    base = float(height(x, y))-.14

    def block(name, dx, dy, z, size, mat):
        box(name, (x+dx*cos(a)-dy*sin(a), y+dx*sin(a)+dy*cos(a), base+z), size, mat, a)
    block("House", 0, 0, h/2, (w, d, h), walls)
    block("Roof", 0, 0, h+.09, (w+.2, d+.2, .18), roof)
    block("Parapet", 0, d/2, h+.27, (w+.1, .12, .32), walls)
    if RNG.random() < .5:
        block("Upper room", w*.19, d*.12, h+.54, (w*.46, d*.50, 1.05), walls)
    block("Doorway", -w*.18, -d/2-.025, .53, (.46, .05, 1.11), dark)
    block("Window", w*.24, -d/2-.025, h*.63, (.49, .05, .42), dark)


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    ground()
    walls = [gray_material("Clay", v) for v in (.3, .39, .47)]
    roof, dark = gray_material("Pale roof", .65), gray_material("Door recess", .035)
    for y in (-33, -26, -19, -9, 2, 11, 20, 29):
        for side in (-1, 1):
            by = y+RNG.uniform(-1.8, 1.8)
            bx = road_x(by)+side*RNG.uniform(5.8, 10.7)
            yard(bx, by, RNG.choice(walls), roof, dark)
            if RNG.random() < .65:
                yard(bx+side*5.7, by+3.1, RNG.choice(walls), roof, dark)
    scrub = gray_material("Shrub", .087)
    for i in range(175):
        x, y = RNG.uniform(-47, 48), RNG.uniform(-45, 52)
        if abs(x-road_x(y)) < 4 or height(x, y) > 5:
            continue
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=1, location=(x, y, float(height(x, y))+.07))
        obj = bpy.context.object
        r = RNG.uniform(.35, 1.08)
        obj.scale = (r, r*RNG.uniform(.6, 1.1), r*RNG.uniform(.6, 1.2))
        obj.data.materials.append(scrub)
    bpy.ops.object.light_add(type="SUN", rotation=(.91, -.52, -.75))
    bpy.context.object.data.energy = 2.2
    bpy.context.object.data.angle = .10
    world = bpy.data.worlds.new("Desert sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.43, .43, .43, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .55
    scene.world = world
    bpy.ops.object.camera_add(location=(21, -61, 19))
    cam = bpy.context.object
    cam.rotation_euler = (Vector((-4, 16, 4.5))-cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    cam.data.clip_end = 300
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 8
    scene.render.resolution_x, scene.render.resolution_y = WIDTH, HEIGHT
    scene.render.resolution_percentage = 100
    return scene


def phosphor(pixels):
    """Tone the rendered still, retaining readable shadows on the small CRT."""
    light = pixels[:, :, 0]
    lo, hi = np.percentile(light, [1, 99.3])
    level = np.clip((light-lo)/(hi-lo), 0, 1)**.77
    y, x = np.mgrid[-1:1:complex(HEIGHT), -1:1:complex(WIDTH)]
    level *= (1-.27*(.52*x*x+.48*y*y)) * (1-.056*(np.indices(level.shape)[0] % 2))
    rng = np.random.default_rng(2103)
    level = np.clip(level + rng.normal(0, .012, level.shape), 0, 1)
    rgb = np.array([8, 30, 29]) + level[:, :, None]*np.array([124, 184, 148])
    return rgb.astype(np.uint8)


def write_png(rgb):
    """Store the RGB8 plate without metadata or external image dependencies."""
    def chunk(kind, data):
        return struct.pack(">I", len(data))+kind+data+struct.pack(">I", zlib.crc32(kind+data))
    raw = b"".join(b"\0"+row.tobytes() for row in rgb)
    header = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR", header) +
                       chunk(b"IDAT", zlib.compress(raw, 9))+chunk(b"IEND", b""))


if __name__ == "__main__":
    scene = build_scene()
    with tempfile.TemporaryDirectory() as temp:
        scene.render.filepath = str(Path(temp)/"diorama.png")
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(scene.render.filepath)
        pixels = np.empty(WIDTH*HEIGHT*4, dtype=np.float32)
        img.pixels.foreach_get(pixels)
    write_png(phosphor(pixels.reshape(HEIGHT, WIDTH, 4)[::-1]))
