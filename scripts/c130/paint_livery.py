"""Paint the editable C-130 skin and stage a textured glTF batch in Blender.

Run on the regenerated aircraft master. All paint is authored in flight
coordinates and baked into a single sRGB atlas. The separate upload batch
contains only the stationary painted skin. Flight anchors and query geometry
come from the project's existing managed template.
"""
import argparse
import json
from math import cos, pi, sin, sqrt
from pathlib import Path
import struct
import sys
import zlib

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SIZE = 2048
FRONT, BACK = -28.5, 30.5
PAINT_NAME = "Aircraft skin • brush and camouflage"

BODY = (
    "Cargo cabin", "Rounded flight deck", "Cargo rear shell", "Tapered tail cone",
    "Radome", "Cargo ramp skin", "Port sponson", "Starboard sponson",
)
GROUPS = ("Fuselage", "WingAndTail", "Nacelles")


def coordinates(width, height, x_interval, y_interval):
    """Return broadcastable texel centers in aircraft coordinates."""
    x = np.linspace(*x_interval, width, dtype=np.float32)[None, :]
    y = np.linspace(*y_interval, height, dtype=np.float32)[:, None]
    return x, y


def mottling(x, y):
    """Fixed, curved camouflage field at several scales."""
    skew = x * 0.19 + y * 0.35
    return (
        np.sin(skew + np.sin(y * 0.24 - x * 0.09))
        + 0.67 * np.sin(y * 0.45 - x * 0.33 + 0.7)
        + 0.29 * np.sin(x * 0.76 + y * 0.63)
        + 0.12 * np.sin(x * 1.89 - y * 1.38)
    )


def skin(x, y, underside, rng):
    """Three subdued colors with overspray and worn metal panel variation."""
    field = mottling(x, y)
    palette = ((42, 47, 47), (64, 72, 66), (92, 93, 79)) if not underside else (
        (44, 49, 54), (63, 68, 68), (79, 83, 73)
    )
    first = np.clip((field + 0.54) / 0.09, 0, 1)[..., None]
    second = np.clip((field - 0.61) / 0.10, 0, 1)[..., None]
    dark, base, light = (np.array(color, dtype=np.float32) for color in palette)
    color = dark + (base - dark) * first + (light - base) * second
    fine = rng.normal(0, 1.24, field.shape)
    paint_wear = 2.5 * np.sin(x * 2.18 + np.sin(y * 3.15)) + 1.3 * np.sin(y * 5.61 - x)
    color += (fine + paint_wear)[..., None]
    return color


def layered(rgb, paint, amount):
    """Composite a pigment color in place using a bounded opacity raster."""
    alpha = np.clip(amount, 0, 1)[..., None]
    rgb[:] = rgb * (1 - alpha) + paint * alpha


def polygon(x, y, points):
    """Rasterize a closed brush shape with a soft one-texel edge."""
    inside = np.zeros(np.broadcast_shapes(x.shape, y.shape), dtype=bool)
    edges = np.full(inside.shape, np.inf, dtype=np.float32)
    for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1]):
        dx, dy = x1 - x0, y1 - y0
        # Treat one radian as about four studs on the nose.
        t = np.clip(((x - x0) * dx + (y - y0) * dy * 16) / (dx * dx + dy * dy * 16), 0, 1)
        edges = np.minimum(edges, (x - x0 - t * dx) ** 2 + (y - y0 - t * dy) ** 2 * 16)
        if dy:
            inside ^= ((y0 > y) != (y1 > y)) & (x < (y - y0) * dx / dy + x0)
    return np.clip(0.5 + np.where(inside, 1, -1) * np.sqrt(edges) / 0.051, 0, 1)


def paint_shark(rgb, longitudinal, signed_angle, rng):
    """Paint a brushed red jaw, black maw, irregular ivory teeth and eyes."""
    angle = abs(signed_angle)
    z = longitudinal + np.sin(signed_angle * 8.1 + longitudinal * 2.3) * 0.07
    # Small asymmetric dry brush edges remain continuous across the belly.
    a = np.abs(signed_angle + np.sin(longitudinal * 5.9 + signed_angle * 20.2) * 0.008)
    outer = [(-27.4, 0), (-27.05, 0.77), (-25.5, 1.2), (-23.6, 1.3),
             (-21.25, 1.36), (-18.6, 1.45), (-16.0, 1.77), (-17.2, 1.27),
             (-19.2, 0.97), (-21.5, 0.71), (-24.1, 0.55), (-26.1, 0.25),
             (-27.07, 0)]
    # Extend the closure slightly across the cylindrical belly seam.
    outer = [(u, v if v > 0 else -0.04) for u, v in outer]
    inner = [(-27.18, -0.04), (-26.78, 0.68), (-25.35, 1.12), (-23.45, 1.20),
             (-21.1, 1.26), (-18.4, 1.36), (-16.58, 1.62), (-17.56, 1.29),
             (-19.45, 1.04), (-21.6, 0.81), (-24.12, 0.66), (-26.26, 0.35),
             (-26.99, -0.04)]
    red = polygon(z, a, outer)
    mouth = polygon(z, a, inner)
    bristle = 0.81 + 0.13 * np.sin(signed_angle * 257 - longitudinal * 5.3)
    bristle += 0.06 * np.sin(signed_angle * 389 - longitudinal * 13.6)
    red_color = np.array([151, 38, 33]) + (np.sin(z * 2.1 + a * 12) * 17)[..., None]
    layered(rgb, red_color, red * bristle)
    layered(rgb, np.array([26, 26, 26]), mouth * 0.96)
    upper = [(u, v) for u, v in inner[:7] if v > 0]
    lower = sorted(inner[7:-1])
    for boundary, downward, centers in (
        (upper, True, (-26.52, -25.55, -24.47, -23.29, -22.13, -20.96, -19.82, -18.68, -17.68)),
        (lower, False, (-26.06, -25.01, -23.88, -22.71, -21.58, -20.48, -19.35, -18.28)),
    ):
        for index, center in enumerate(centers):
            base = float(np.interp(center, *zip(*boundary)))
            width = 0.44 + (index % 3) * 0.045
            reach = (0.21 + (index % 4) * 0.025) * (-1 if downward else 1)
            tooth = polygon(z, a, [(center-width, base), (center+width, base),
                                   (center+0.10, base+reach), (center-0.02, base+reach*0.91)])
            layered(rgb, np.array([198, 187, 154]), tooth * mouth * (0.87 + bristle * 0.12))
    eye = [(-24.0, 1.72), (-22.7, 1.83), (-20.45, 2.06), (-18.7, 2.24),
           (-19.25, 1.96), (-21.05, 1.72), (-22.92, 1.61)]
    eye_mask = polygon(z, a, eye)
    layered(rgb, red_color, eye_mask * bristle)
    pupil = polygon(z, a, [(-22.69, 1.795), (-21.35, 1.89), (-21.91, 1.69), (-22.39, 1.70)])
    layered(rgb, np.array([28, 29, 30]), pupil * eye_mask * 0.97)
    dry = rng.normal(0, 1.1, rgb.shape[:2]) + np.sin(z * 3.18 + a * 211) * 1.8
    rgb += (dry * np.maximum(red, eye_mask) * (angle < 2.55))[..., None]


def insignia(rgb, x, y, center_x, center_y):
    """Paint a subdued star-and-bars stencil directly into the atlas."""
    star = []
    for tooth in range(10):
        angle = pi / 2 + tooth * pi / 5
        radius = 1.35 if tooth % 2 == 0 else 0.60
        star.append((center_x + cos(angle) * radius, center_y + sin(angle) * radius))
    mark = polygon(x, y, star)
    for side in (-1, 1):
        ax, bx = sorted((center_x + side, center_x + side * 2.65))
        for height in (-0.30, 0.13):
            ay = center_y + height
            mark = np.maximum(mark, polygon(x, y, [(ax, ay), (bx, ay), (bx, ay + 0.17), (ax, ay + 0.17)]))
    tint = np.array([119, 132, 142])
    layered(rgb, tint, mark * 0.88)


def atlas_pixels():
    rng = np.random.default_rng(1328)
    atlas = np.empty((SIZE, SIZE, 3), np.uint8)
    z, a = coordinates(SIZE, 1024, (FRONT, BACK), (-pi, pi))
    wrapped = np.cos(a) * 9.0 + np.sin(a) * 1.8
    body = skin(z, wrapped, False, rng)
    seam = np.minimum((z + 1.18) % 3.13, 3.13 - (z + 1.18) % 3.13)
    frames = np.clip(1 - seam / 0.064, 0, 1)
    strip = np.minimum((a + 0.22) % 0.88, 0.88 - (a + 0.22) % 0.88)
    ribs = np.clip(1 - strip / 0.016, 0, 1)
    body -= (frames * 6 + ribs * 4)[..., None]
    bolts = (frames > 0.22) * np.exp(-((np.mod(a + pi, 0.117) - 0.0585) / 0.016) ** 2)
    body += (bolts * 6)[..., None]
    paint_shark(body, z, a, rng)
    insignia(body, z, (abs(a) - pi/2) * 4.5, 9.4, 0)
    atlas[:1024] = np.clip(body, 0, 255).astype(np.uint8)
    for i, underside in enumerate((False, True)):
        x, z = coordinates(SIZE, 512, (-30.2, 30.2), (-13.1, 31.3))
        wings = skin(x * 0.86 + z * 0.27, z * 1.15, underside, rng)
        panel = np.minimum((x+1.1) % 4.05, 4.05 - (x+1.1) % 4.05)
        rib = np.minimum((z+0.4) % 2.35, 2.35 - (z+0.4) % 2.35)
        wings -= (6 * np.clip(1 - panel / 0.06, 0, 1) + 3 * np.clip(1 - rib / 0.051, 0, 1))[..., None]
        soot = sum(np.exp(-((x - engine) / 1.35) ** 2) for engine in (-17.5, -9.7, 9.7, 17.5))
        wings -= (9.5 * soot * np.exp(-((z-0.2) / 4.4) ** 2))[..., None]
        insignia(wings, x, z, 22.3 if underside else -22.3, -3.83)
        atlas[1024 + i*512:1536 + i*512] = np.clip(wings, 0, 255).astype(np.uint8)
    return atlas


def write_png(path, pixels):
    """Write stable 8-bit sRGB PNG bytes without an external Python package."""
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data)))
    scanlines = b"".join(b"\0" + row.tobytes() for row in pixels)
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
                     + chunk(b"sRGB", b"\0") + chunk(b"IDAT", zlib.compress(scanlines, 9))
                     + chunk(b"IEND", b""))


def material(path):
    image = bpy.data.images.load(str(path), check_existing=False)
    image.name = "C-130 camouflage and brushed shark livery"
    image.pack()
    paint = bpy.data.materials.new(PAINT_NAME)
    paint.use_nodes = True
    shader = paint.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = 0.66
    shader.inputs["Metallic"].default_value = 0.06
    texture = paint.node_tree.nodes.new("ShaderNodeTexImage")
    texture.name = "Baked aircraft paint"
    texture.image = image
    paint.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    return paint


def region(name):
    if name.startswith(BODY):
        return "Fuselage"
    if "nacelle" in name:
        return "Nacelles"
    if any(key in name for key in (" wing.", " aileron.", " stabilizer.", "Dorsal fin.", "Rudder.")):
        return "WingAndTail"
    return None


def cambered_wing(side):
    """Smooth airfoil with tapered ends inside the original wing span."""
    stations = ((1.4, -7.35, 3.15, 3.43, 0.55), (14.5, -7.35, 2.15, 3.65, 0.55),
                (17.5, -7.35, 1.34, 3.65, 0.52), (27, -6.53, -1.25, 3.90, 0.39),
                (28.8, -5.73, -2.16, 3.94, 0.21), (29.0, -5.28, -2.48, 3.95, 0.10))
    samples = 32
    vertices, faces = [], []
    for x, front, rear, height, depth in stations:
        for sample in range(samples):
            angle = 2*pi*sample/samples
            chord = (1-cos(angle))/2
            # Closed, asymmetric leading-to-trailing section. The leading edge
            # has more volume than the tapered trailing edge.
            lift = sqrt(chord*(1-chord)) * (1.74-0.74*chord) * depth
            y = height + (lift if sample <= samples/2 else -lift)
            vertices.append((side*x, -(front + (rear-front)*chord), y))
    faces.append(tuple(reversed(range(samples))))
    for band in range(len(stations)-1):
        for sample in range(samples):
            a = band*samples+sample
            b = band*samples+(sample+1)%samples
            faces.append((a, b, b+samples, a+samples))
    faces.append(tuple(range((len(stations)-1)*samples, len(stations)*samples)))
    if side < 0:
        faces = [tuple(reversed(face)) for face in faces]
    mesh = bpy.data.meshes.new("Cambered wing")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.calc_loop_triangles()
    if sum(mesh.vertices[t.vertices[0]].co.dot(mesh.vertices[t.vertices[1]].co.cross(
            mesh.vertices[t.vertices[2]].co)) for t in mesh.loop_triangles) < 0:
        mesh.flip_normals()
    for face in mesh.polygons:
        face.use_smooth = len(face.vertices) == 4
    obj = bpy.data.objects.new("Starboard cambered wing" if side > 0 else "Port cambered wing", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def assign_uv(obj, section, paint):
    """Map hull skin around the belly and airfoils in plan view."""
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name="Paint UV")
    obj.data.materials.clear()
    obj.data.materials.append(paint)
    world = obj.matrix_world
    for polygon in obj.data.polygons:
        xy = []
        for vertex in polygon.vertices:
            point = world @ obj.data.vertices[vertex].co
            x, y, z = point.x, point.z, -point.y
            if section == "Fuselage":
                angle = np.arctan2(x, -y)
                xy.append(((z - FRONT) / (BACK - FRONT), (angle + pi) / (2*pi)))
            else:
                xy.append(((x + 30.2) / 60.4, (z + 13.1) / 44.4))
        if section == "Fuselage" and max(v for _, v in xy) - min(v for _, v in xy) > 0.5:
            top = sum(v for _, v in xy) >= len(xy) / 2
            xy = [(u, (1 if top else 0) if (v > 0.5) != top else v) for u, v in xy]
        normal = world.to_3x3().inverted().transposed() @ polygon.normal
        if section == "Fuselage":
            start, height = 0, 1024
        else:
            start, height = (1024 if normal.z >= 0 else 1536), 512
        for loop, (u, v) in zip(polygon.loop_indices, xy):
            uv.data[loop].uv = ((2+min(max(u, 0), 1)*(SIZE-4))/SIZE,
                               1-(start+2+min(max(v, 0), 1)*(height-4))/SIZE)


def export_skin(groups, output):
    """Join by region with stable names, keeping each region below the mesh limit."""
    copies = []
    for name, originals in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in originals:
            duplicate = obj.copy()
            duplicate.data = obj.data.copy()
            bpy.context.scene.collection.objects.link(duplicate)
            duplicate.select_set(True)
            bpy.context.view_layer.objects.active = duplicate
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = "C130_" + name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        copies.append(joined)
    bpy.ops.object.select_all(action="DESELECT")
    info = {}
    for obj in copies:
        obj.select_set(True)
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        if triangles > 18000:
            raise ValueError(f"{obj.name} has {triangles} triangles")
        info[obj.name] = {"triangles": triangles,
                          "bounds": [[round(min(v.co[axis] for v in obj.data.vertices), 5) for axis in range(3)],
                                     [round(max(v.co[axis] for v in obj.data.vertices), 5) for axis in range(3)]]}
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                              export_yup=True, export_texcoords=True, export_materials="EXPORT",
                              export_animations=False, export_cameras=False, export_lights=False)
    return info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--skip-render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    colors = output / "c130-camouflage.png"
    write_png(colors, atlas_pixels())
    paint = material(colors)
    groups = {name: [] for name in GROUPS}
    removed, replaced = [], []
    for obj in sorted(bpy.context.scene.objects, key=lambda piece: piece.name):
        if "NativeShape" not in obj:
            continue
        if " shark " in obj.name or " insignia " in obj.name:
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        if " wing." in obj.name or " aileron." in obj.name:
            replaced.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        section = region(obj.name)
        if section:
            replaced.append(obj.name)
            assign_uv(obj, section, paint)
            groups[section].append(obj)
    for side in (-1, 1):
        wing = cambered_wing(side)
        assign_uv(wing, "WingAndTail", paint)
        groups["WingAndTail"].append(wing)
    if len(removed) < 30 or not all(groups.values()):
        raise ValueError("Expected the original P28 geometry and three painted skin regions")
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "c130-painted.blend"), compress=True)
    if not args.skip_render:
        bpy.context.scene.render.filepath = str(output / "c130-painted-preview.png")
        bpy.ops.render.render(write_still=True)
    info = export_skin(groups, output / "c130-painted-skin.glb")
    (output / "c130-painted-layout.json").write_text(json.dumps({
        "atlasPixels": [SIZE, SIZE], "regions": info, "replacesVisuals": sorted(replaced),
        "removedRaisedPaint": removed,
    }, indent=2) + "\n")
    print(json.dumps(info))


if __name__ == "__main__":
    main()
