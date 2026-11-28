"""Author the original P28 aircraft and its Blender-only Ground review stage.

Run with Blender background Python. Editable mesh scales and placements use
one Blender unit per stud, X starboard, Y nose, Z up. Native shape tags declare
the matching Roblox primitive for the separate managed export compiler.
"""
from pathlib import Path
from math import cos, pi, sin, sqrt, tau

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/c130/c130.blend"

PALETTE = {
    "Charcoal": (51, 55, 60),
    "Upper panels": (61, 66, 72),
    "Lower panels": (42, 46, 52),
    "Controls": (40, 44, 51),
    "Engine seams": (37, 41, 47),
    "Graphite": (26, 30, 35),
    "Collar": (69, 72, 77),
    "Glazing": (22, 37, 45),
    "Slate paint": (121, 134, 149),
    "Crimson": (176, 34, 40),
    "Crimson scuff": (202, 45, 44),
    "Propeller": (52, 56, 61),
    "Tip paint": (122, 131, 142),
    "Propeller sweep": (116, 126, 139),
    "Port marker": (138, 41, 48),
    "Starboard marker": (50, 108, 89),
}

# Convert Roblox local points to right-handed Blender coordinates.
TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def linear(value):
    return ((value + 0.055) / 1.055) ** 2.4 if value > 0.04045 else value / 12.92


def make_materials():
    materials = {}
    for name, rgb in PALETTE.items():
        material = bpy.data.materials.new(name)
        alpha = 0.12 if name == "Propeller sweep" else 1
        color = tuple(linear(channel / 255) for channel in rgb) + (alpha,)
        material.diffuse_color = color
        material.use_nodes = True
        nodes = material.node_tree.nodes
        shader = nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Alpha"].default_value = alpha
        shader.inputs["Roughness"].default_value = 0.75 if name != "Glazing" else 0.28
        shader.inputs["Metallic"].default_value = 0.18 if name in ("Charcoal", "Collar") else 0
        if alpha < 1:
            # Variable-opacity radial sweep in the still, with the native disc
            # retaining its scalar opacity on the game render.
            tex = nodes.new("ShaderNodeTexCoord")
            split = nodes.new("ShaderNodeSeparateXYZ")
            combine = nodes.new("ShaderNodeCombineXYZ")
            material.node_tree.links.new(tex.outputs["Generated"], split.inputs["Vector"])
            for axis in "YZ":
                material.node_tree.links.new(split.outputs[axis], combine.inputs[axis])
            distance = nodes.new("ShaderNodeVectorMath")
            distance.operation = "DISTANCE"
            distance.inputs[1].default_value = (0, 0.5, 0.5)
            material.node_tree.links.new(combine.outputs[0], distance.inputs[0])
            ramp = nodes.new("ShaderNodeValToRGB")
            elements = ramp.color_ramp.elements
            elements[0].position, elements[0].color = 0, (0, 0, 0, 1)
            elements[1].position, elements[1].color = 0.5, (0.035, 0.035, 0.035, 1)
            for location, strength in ((0.12, 0.19), (0.34, 0.08), (0.43, 0.14)):
                elements.new(location).color = (strength, strength, strength, 1)
            material.node_tree.links.new(distance.outputs["Value"], ramp.inputs[0])
            material.node_tree.links.new(ramp.outputs["Color"], shader.inputs["Alpha"])
        materials[name] = material
    return materials


def collection(name):
    child = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(child)
    return child


def orthonormal(up, back):
    right = up.cross(back)
    return Matrix((right, up, back)).transposed()


def x_axis_along(axis):
    right = Vector(axis).normalized()
    reference = Vector((0, 1, 0)) if abs(right.y) < 0.9 else Vector((0, 0, 1))
    up = (reference - right * right.dot(reference)).normalized()
    return Matrix((right, up, right.cross(up))).transposed()


class Aircraft:
    """Assemble editable, exportable objects from stock native profiles."""

    def __init__(self):
        self.airframe = collection("Aircraft • editable airframe")
        self.hardware = collection("Aircraft • gameplay attachments")
        self.stage = collection("Review • lighting and camera")
        self.materials = make_materials()

    def primitive(self, name, shape, center, size, material, *, frame=None, query=False, rotor=None):
        rotation = frame if frame is not None else Matrix.Identity(3)
        if shape == "Ball":
            bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=0.5)
        elif shape == "Cylinder":
            bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.5, depth=1)
        elif shape == "Wedge":
            verts = [
                (-0.5, -0.5, -0.5), (0.5, -0.5, -0.5),
                (-0.5, -0.5, 0.5), (0.5, -0.5, 0.5),
                (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5),
            ]
            faces = [(0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1), (0, 2, 4), (1, 5, 3)]
            mesh = bpy.data.meshes.new(name)
            mesh.from_pydata(verts, [], faces)
            item = bpy.data.objects.new(name, mesh)
            self.airframe.objects.link(item)
        else:
            bpy.ops.mesh.primitive_cube_add(size=1)
        if shape != "Wedge":
            item = bpy.context.object
            for parent in list(item.users_collection):
                parent.objects.unlink(item)
            self.airframe.objects.link(item)
        if shape == "Cylinder":
            item.data.transform(Matrix.Rotation(pi / 2, 4, "Y"))
            for face in item.data.polygons:
                face.use_smooth = len(face.vertices) == 4
        elif shape == "Ball":
            for face in item.data.polygons:
                face.use_smooth = True
        item.name = name
        item.data.name = name
        item.matrix_world = (TO_BLENDER @ rotation).to_4x4()
        item.location = TO_BLENDER @ Vector(center)
        item.scale = size
        item.data.materials.append(self.materials[material])
        item["NativeShape"] = shape
        item["NativeQuery"] = query
        item["NativeTransparency"] = 0.88 if material == "Propeller sweep" else 0.0
        if rotor:
            item["Rotor"] = rotor
        return item

    def tube(self, name, center, size, material, *, axis=(0, 0, 1), query=False):
        return self.primitive(
            name, "Cylinder", center, size, material, frame=x_axis_along(axis), query=query
        )

    def ball(self, name, center, size, material, *, query=False):
        return self.primitive(name, "Ball", center, size, material, query=query)

    def triangle(self, name, points, depth, material, *, query=False, rotor=None):
        # Split at the altitude of the longest side. Roblox's stock WedgePart
        # can represent each half exactly using only an orthonormal frame.
        points = [Vector(point) for point in points]
        index = max(range(3), key=lambda i: (points[i - 1] - points[i - 2]).length_squared)
        start, end, tip = points[index - 2], points[index - 1], points[index]
        edge = (end - start).normalized()
        foot = start + edge * (tip - start).dot(edge)
        height = (tip - foot).length
        if height < 1e-5:
            return
        for index, endpoint in enumerate((start, end), 1):
            width = (foot - endpoint).length
            if width < 1e-5:
                continue
            frame = orthonormal((tip - foot) / height, (foot - endpoint) / width)
            self.primitive(
                f"{name}.{index}", "Wedge", (endpoint + tip) * 0.5, (depth, height, width),
                material, frame=frame, query=query, rotor=rotor,
            )

    def patch(self, name, points, depth, material, *, query=False, rotor=None):
        for index in range(1, len(points) - 1):
            self.triangle(
                f"{name}.{index}", (points[0], points[index], points[index + 1]),
                depth, material, query=query, rotor=rotor,
            )

    def marker(self, name, center, *, port=False):
        obj = bpy.data.objects.new(name, None)
        self.hardware.objects.link(obj)
        obj.empty_display_type = "ARROWS"
        obj.empty_display_size = 0.75
        # RightVector points directly out of the matching muzzle collar.
        frame = Matrix.Rotation(pi if port else 0, 3, "Y")
        obj.matrix_world = (TO_BLENDER @ frame).to_4x4()
        obj.location = TO_BLENDER @ Vector(center)
        obj["NativeMarker"] = True

    def add_airframe(self):
        self.tube("Cargo cabin", (0, 0, -2), (34, 9, 11.3), "Charcoal", query=True)
        self.ball("Rounded flight deck", (0, 0, -19), (11.3, 9, 17.2), "Charcoal", query=True)
        self.ball("Cargo rear shell", (0, 0.42, 12.0), (11.25, 8.7, 31.6), "Charcoal", query=True)
        self.ball("Tapered tail cone", (0, 2.12, 22.0), (6.83, 4.23, 16.0), "Charcoal", query=True)
        self.ball("Radome", (0, -0.65, -25.15), (4.9, 3.75, 4.85), "Engine seams", query=True)
        self.ball("Upper antenna", (0, 4.31, -16), (0.95, 0.68, 1.43), "Graphite")
        self.ball("Belly sensor", (0, -4.38, -15.4), (0.61, 0.22, 1.06), "Engine seams")
        self.ball("Cargo ramp skin", (0, -1.95, 17.5), (5.5, 1.46, 12.1), "Lower panels")
        for side in (-1, 1):
            label = "Starboard" if side > 0 else "Port"
            self.ball(f"{label} sponson", (side * 4.35, -2.5, -4), (3.22, 2.93, 19.5), "Lower panels", query=True)
            self.ball(f"{label} fairing plate", (side * 5.35, -0.22, -13.65), (0.7, 0.91, 1.85), "Upper panels")
            # Main wing tapers and sweeps modestly aft at the outer tip.
            self.patch(f"{label} wing", [
                (side * x, y, z) for x, y, z in (
                    (1.4, 3.43, -7.35), (17.5, 3.65, -7.35), (28, 3.9, -6.43),
                    (29, 3.95, -5.38), (28.8, 3.95, -2.26),
                    (27, 3.9, -1.25), (14.5, 3.65, 2.15), (1.4, 3.43, 3.15),
                )
            ], 1.10, "Charcoal", query=True)
            self.patch(f"{label} aileron", [
                (side * x, y, z) for x, y, z in (
                    (15.0, 3.7, 0.8), (26.8, 3.9, -2.4), (28.4, 3.95, -2.32),
                    (26.95, 3.9, -1.22), (15.0, 3.7, 2.02),
                )
            ], 1.105, "Controls", query=True)
            self.patch(f"{label} stabilizer", [
                (side * x, 3.8, z) for x, z in (
                    (0.6, 21.25), (10.42, 24.3), (12, 25.58),
                    (11.5, 27.65), (9.9, 28.45), (0.6, 28.92),
                )
            ], 0.75, "Upper panels", query=True)
            self.ball(f"{label} wing lamp", (side * 28.57, 3.94, -4.14), (0.35, 0.46, 0.68),
                      "Starboard marker" if side > 0 else "Port marker")
        self.patch("Dorsal fin", [(0, y, z) for y, z in (
            (3.0, 12.3), (4.82, 18), (13.47, 23.1), (13.96, 24.8),
            (13.55, 26.31), (5.0, 28.27), (3.0, 28.5),
        )], 1.35, "Charcoal", query=True)
        self.patch("Rudder", [(0, y, z) for y, z in (
            (4.6, 25.3), (12.7, 24.9), (13.2, 26.15), (5.0, 28.28), (4.5, 28.23),
        )], 1.355, "Controls", query=True)

    def add_engines(self):
        for side in (-1, 1):
            for index, absolute_x in enumerate((9.7, 17.5), 1):
                label = f"{'Starboard' if side > 0 else 'Port'}{index}"
                x = side * absolute_x
                y = 2.61 if index == 1 else 2.83
                front = -11.1 if index == 1 else -10.88
                self.ball(f"{label} nacelle", (x, y, front + 3.8), (3.77, 3.48, 10.2),
                          "Upper panels", query=True)
                self.tube(f"{label} intake ring", (x, y, front + 0.16), (0.48, 2.36, 2.55), "Engine seams")
                self.ball(f"{label} spinner", (x, y, front - 0.31), (1.66, 1.62, 1.85), "Graphite")
                self.tube(f"{label} translucent sweep", (x, y, front - 0.56), (0.065, 8.2, 8.2),
                          "Propeller sweep")
                hub = Vector((x, y, front - 0.56))
                self.marker(label, hub)
                for blade in range(4):
                    angle = blade * tau / 4 + (index - 1) * 0.22
                    outward = Vector((cos(angle), sin(angle), 0))
                    sideways = Vector((-sin(angle), cos(angle), 0))
                    upward = Vector((0, 0, 1))
                    blade_frame = Matrix((outward, sideways, upward)).transposed()
                    for suffix, center, width, depth, material in (
                        ("blade", 2.21, 3.28, 0.42, "Propeller"),
                        ("tip", 3.92, 0.29, 0.40, "Tip paint"),
                    ):
                        item = self.primitive(f"{label} {suffix} {blade + 1}", "Block",
                                              hub + outward * center, (width, depth, 0.08), material,
                                              frame=blade_frame, rotor=label)
                        item.hide_render = True

    def add_weapon_mounts(self):
        # Fictional exterior meshes share the visible end center with the
        # canonical server attachment. X is starboard in the flight frame.
        for name, side, y, z, span, tube_radius, collar_radius in (
            ("M102", 1, -2.21, 6.65, 3.3, 0.59, 0.79),
            ("GAU23", -1, -1.96, -8.9, 1.55, 0.28, 0.40),
        ):
            mount_x = 5.2 if side == 1 else 5.55
            self.primitive(f"{name} recessed mount", "Block", (side * (mount_x - 0.06), y, z),
                           (0.44, 1.8, 2.2), "Graphite")
            self.tube(f"{name} barrel", (side * (mount_x + span * 0.45), y, z),
                      (span * 0.90, tube_radius * 2, tube_radius * 2), "Graphite",
                      axis=(1, 0, 0), query=True)
            self.tube(f"{name} muzzle collar", (side * (mount_x + span - 0.37), y, z),
                      (0.66, collar_radius * 2, collar_radius * 2), "Collar",
                      axis=(1, 0, 0), query=True)
            muzzle_x = side * (mount_x + span - 0.04)
            self.tube(f"{name} dark bore", (muzzle_x, y, z),
                      (0.063, collar_radius * 1.48, collar_radius * 1.48), "Graphite", axis=(1, 0, 0))
            self.marker(f"{name}Muzzle", (muzzle_x, y, z), port=side < 0)

    @staticmethod
    def nose_point(side, z, degrees, surface=0.065):
        angle = degrees * pi / 180
        scale = sqrt(max(0.01, 1 - ((z + 19) / 8.6) ** 2)) if z < -19 else 1
        return (side * (5.65 * scale + surface) * cos(angle),
                (4.5 * scale + surface) * sin(angle), z)

    def add_livery(self):
        for side in (-1, 1):
            label = "Starboard" if side > 0 else "Port"
            # Dark fuselage glazing rests on the rounded flight-deck skin.
            for i, (start, end, floor, ceiling) in enumerate((
                (-25.20, -23.70, 26, 52), (-23.59, -22.11, 29, 59),
                (-22.0, -20.38, 31, 63), (-20.27, -18.75, 34, 63),
            ), 1):
                frame = [(start, floor), (end, floor + 2), (end + 0.18, ceiling),
                         (start + 0.22, ceiling - 2)]
                center_z = (start + end) / 2
                center_angle = (floor + ceiling) / 2
                self.patch(f"{label} flight deck pane {i}", [
                    self.nose_point(side, center_z + (z - center_z) * 0.88,
                                    center_angle + (angle - center_angle) * 0.91, 0.28)
                    for z, angle in frame
                ], 0.07, "Glazing")
            def paint(name, points, material, surface=0.115):
                self.triangle(f"{label} {name}", [
                    self.nose_point(side, z, angle, surface) for z, angle in points
                ], 0.025, material)

            paint("shark eye brow", [(-16.05, 14), (-23.57, -1), (-19.58, 0)], "Crimson")
            paint("shark eye lower", [(-23.57, -1), (-20.52, -12), (-18.33, 4)], "Crimson")
            paint("shark pupil", [(-20.92, -2), (-22.04, 0), (-21.35, -7)], "Graphite", 0.265)
            paint("shark eye brush edge", [(-16.01, 14), (-17.71, 10), (-16.68, 12)], "Crimson scuff")
            for i, (z0, a0, z1, a1) in enumerate((
                (-16.47, -33, -17.75, -40), (-17.75, -40, -19.03, -47),
                (-19.03, -47, -20.32, -52), (-20.32, -52, -21.58, -56),
                (-21.58, -56, -22.85, -58), (-22.85, -58, -24.01, -60),
                (-24.01, -60, -25.10, -62), (-25.10, -62, -26.08, -65),
            ), 1):
                mid = (z0 + z1) / 2
                paint(f"shark tooth {i}", [(z0, a0), (mid, a0 - 16 + i % 2 * 4), (z1, a1 + 7)], "Crimson")
                if i in (1, 3, 6, 8):
                    paint(f"shark stroke {i}", [(mid, a0 - 14), (mid - 0.28, a0 - 17), (z1 - 0.05, a1 + 7)],
                          "Crimson scuff", 0.14)

            def side_mark(u, v):
                # Side paint follows the side of the cabin. The lateral
                # surface remains nearly flat at this angular range.
                return (side * (sqrt(max(0.05, 1 - (v / 4.5) ** 2)) * 5.65 + 0.10), v, 9.4 + u)

            self.insignia(f"{label} fuselage insignia", side_mark, 1.52)
        self.insignia("Port upper wing insignia", lambda u, v: (-22.3 + u, 4.48, -3.83 + v), 1.52)
        self.insignia("Starboard lower wing insignia", lambda u, v: (22.3 + u, 3.18, -3.83 + v), 1.52)

    def insignia(self, name, coords, radius):
        # Original subdued star and double bars as editable geometric paint.
        rim = []
        for i in range(10):
            angle = pi / 2 + i * pi / 5
            reach = radius if i % 2 == 0 else radius * 0.45
            rim.append(coords(cos(angle) * reach, sin(angle) * reach))
        self.patch(f"{name} star center", rim[1::2], 0.035, "Slate paint")
        for i in range(0, 10, 2):
            self.triangle(f"{name} star {i}", (rim[i - 1], rim[i], rim[i + 1]), 0.035, "Slate paint")
        for side in (-1, 1):
            for height in (-0.29, 0.23):
                points = [Vector(coords(side * x, v)) for x, v in (
                    (1.16, height), (3.1, height), (3.1, height + 0.25), (1.16, height + 0.25),
                )]
                across = points[1] - points[0]
                upward = points[3] - points[0]
                right = across.normalized()
                back = across.cross(upward).normalized()
                up = back.cross(right)
                self.primitive(f"{name} bar {side} {height}", "Block", sum(points, Vector()) / 4,
                               (across.length, upward.length, 0.025),
                               "Slate paint", frame=Matrix((right, up, back)).transposed())

    def make_stage(self):
        camera_position = Vector((31, 112, -22))
        bpy.ops.object.camera_add(location=camera_position)
        camera = bpy.context.object
        camera.name = "Ground view • below starboard nose"
        camera.rotation_euler = (Vector((0, 1.5, 1.4)) - camera_position).to_track_quat("-Z", "Y").to_euler()
        camera.data.type = "ORTHO"
        camera.data.ortho_scale = 74
        scene = bpy.context.scene
        scene.camera = camera
        for location, energy, size, color in (
            ((35, 31, 64), 92000, 70, (0.86, 0.92, 1.0)),
            ((55, 60, -42), 62000, 64, (0.94, 0.96, 1.0)),
            ((-35, -55, 41), 100000, 48, (1.0, 0.89, 0.79)),
        ):
            bpy.ops.object.light_add(type="AREA", location=location)
            light = bpy.context.object
            light.rotation_euler = (-Vector(location)).to_track_quat("-Z", "Y").to_euler()
            light.data.energy, light.data.shape, light.data.size, light.data.color = energy, "DISK", size, color
        for item in [camera, *[o for o in scene.objects if o.type == "LIGHT"]]:
            for parent in list(item.users_collection):
                parent.objects.unlink(item)
            self.stage.objects.link(item)
        world = scene.world
        world.use_nodes = True
        background = world.node_tree.nodes.get("Background")
        background.inputs["Color"].default_value = (0.31, 0.35, 0.41, 1)
        background.inputs["Strength"].default_value = 0.7
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 16
        scene.render.resolution_x, scene.render.resolution_y = 1360, 720
        scene.render.resolution_percentage = 100
        scene.unit_settings.system = "METRIC"
        scene.unit_settings.scale_length = 0.28
        scene["Source axes"] = "1 Blender unit = 1 stud. X starboard, Y forward, Z up. Flight pivot at (0,0,0)."


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.world = bpy.data.worlds.new("Review sky")
    aircraft = Aircraft()
    aircraft.add_airframe()
    aircraft.add_engines()
    aircraft.add_weapon_mounts()
    aircraft.add_livery()
    aircraft.make_stage()
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = None
    bpy.context.preferences.filepaths.save_version = 0
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER), compress=True)


if __name__ == "__main__":
    main()
