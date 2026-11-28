"""Build the editable P29 depot prop and its Blender-only review stage.

Author dimensions in Roblox studs and coordinates (negative Z points forward).
Each editable piece has a matching stock Part or WedgePart profile. The assembly
has a sealed face, and its three attachments describe presentation points only.
"""
from math import radians
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/rocket-launcher/rocket-launcher.blend"
TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
PALETTE = {
    "Slate shell": (103, 103, 105),
    "Slate edge": (123, 121, 118),
    "Sand armor": (166, 140, 105),
    "Sand edge": (187, 159, 120),
    "Graphite": (59, 58, 61),
    "Graphite edge": (81, 78, 78),
    "Teal enamel": (40, 128, 122),
    "Teal edge": (66, 149, 137),
    "Pad rubber": (54, 50, 51),
    "Grip rubber": (44, 42, 43),
}

# Roblox's WedgePart is a prism along X, with an upright back on +Z.
CORNERS = [(-.5, -.5, -.5), (.5, -.5, -.5), (-.5, -.5, .5),
           (.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]
WEDGE_FACES = [(0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1), (0, 2, 4), (1, 5, 3)]


def make_material(name, rgb):
    def linear(channel):
        value = channel / 255
        return ((value + .055) / 1.055) ** 2.4 if value > .04045 else value / 12.92

    color = tuple(linear(channel) for channel in rgb) + (1,)
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = .86 if "rubber" in name else .57
    shader.inputs["Metallic"].default_value = 0 if "rubber" in name else .12
    return material


def collection(scene, name):
    folder = bpy.data.collections.new(name)
    scene.collection.children.link(folder)
    return folder


class DepotProp:
    def __init__(self, scene):
        self.shell = collection(scene, "Launcher • export geometry")
        self.markers = collection(scene, "Launcher • fitted attachments")
        self.materials = {name: make_material(name, rgb) for name, rgb in PALETTE.items()}

    def piece(self, name, center, size, material, orientation=None, *, shape="Block"):
        if shape == "Wedge":
            mesh = bpy.data.meshes.new(name)
            mesh.from_pydata(CORNERS, [], WEDGE_FACES)
            obj = bpy.data.objects.new(name, mesh)
            self.shell.objects.link(obj)
        else:
            bpy.ops.mesh.primitive_cube_add(size=1)
            obj = bpy.context.object
            for parent in list(obj.users_collection):
                parent.objects.unlink(obj)
            self.shell.objects.link(obj)
        obj.name = obj.data.name = name
        obj.matrix_world = (TO_BLENDER @ (orientation if orientation is not None else Matrix.Identity(3))).to_4x4()
        obj.location = TO_BLENDER @ Vector(center)
        obj.scale = size
        obj.data.materials.append(self.materials[material])
        obj["NativeShape"] = shape
        return obj

    def wedge(self, name, corner, rise, run, thickness, material):
        """Extrude a right triangle about the plane defined by its two legs."""
        corner, rise, run = map(Vector, (corner, rise, run))
        up, back = rise.normalized(), -run.normalized()
        if abs(up.dot(back)) > 0.00001:
            raise ValueError(f"{name}: wedge legs must be perpendicular")
        orientation = Matrix((up.cross(back), up, back)).transposed()
        return self.piece(name, corner + (rise + run) * .5,
                          (thickness, rise.length, run.length), material, orientation, shape="Wedge")

    def shell_section(self, name, center, half_width, half_height, length, bevel, material, edge=None):
        """Create one beveled rectangular section with a continuous octagonal silhouette."""
        x, y, z = center
        inner_width, inner_height = half_width - bevel, half_height - bevel
        self.piece(name + " center", center, (2 * inner_width, 2 * half_height, length), material)
        for side, sign_x in (("left", -1), ("right", 1)):
            self.piece(name + " " + side, (x + sign_x * (half_width - bevel / 2), y, z),
                       (bevel, 2 * inner_height, length), material)
            for edge_name, sign_y in (("upper", 1), ("lower", -1)):
                self.wedge(f"{name} {side} {edge_name}",
                           (x + sign_x * inner_width, y + sign_y * inner_height, z),
                           (sign_x * bevel, 0, 0), (0, sign_y * bevel, 0), length,
                           edge if edge and sign_y == 1 else material)

    def raised_bar(self, name, start, end, width, thickness, material):
        """Join two YZ-plane points with a canted rectangular bar."""
        start, end = Vector(start), Vector(end)
        back = (end - start).normalized()
        right = Vector((1, 0, 0))
        orientation = Matrix((right, back.cross(right), back)).transposed()
        self.piece(name, (start + end) * .5, (width, thickness, (end - start).length), material, orientation)

    def side_badge(self, name, plane, y, z, height, length, slant, fill):
        """Make a thick parallelogram panel with two opposed chamfered ends."""
        half_length = length / 2
        self.piece(name + " face", (plane, y, z), (.028, height, length - slant), fill)
        for end in (-1, 1):
            self.wedge(name + (" front" if end == -1 else " rear"),
                       (plane, y + end * height / 2, z + end * (half_length - slant / 2)),
                       (0, -end * height, 0), (0, 0, end * slant), .028, fill)

    def marker(self, name, center, rotation=None):
        marker = bpy.data.objects.new(name, None)
        self.markers.objects.link(marker)
        marker.empty_display_type = "ARROWS"
        marker.empty_display_size = .17
        marker.matrix_world = (TO_BLENDER @ (rotation if rotation is not None else Matrix.Identity(3))).to_4x4()
        marker.location = TO_BLENDER @ Vector(center)
        marker["LauncherAttachment"] = True

    def assemble(self):
        self.shell_section("Slate body", (0, 0, -.035), .483, .443, 2.985, .113, "Slate shell", "Slate edge")
        self.shell_section("Sand forward collar", (0, 0, -1.095), .513, .47, .49, .116, "Sand armor", "Sand edge")
        self.shell_section("Sand aft collar", (0, 0, 1.193), .515, .468, .34, .109, "Sand armor", "Sand edge")
        self.shell_section("Closed graphite cap", (0, 0, -1.55), .535, .472, .51, .124, "Graphite", "Graphite edge")
        self.shell_section("Recessed end face", (0, 0, -1.81), .481, .418, .04, .105, "Graphite")
        self.piece("Diagonal teal paint", (0, 0, -1.833), (.145, .891, .006), "Teal enamel",
                   Matrix.Rotation(radians(-36), 3, "Z"))
        for sign, side in ((-1, "left"), (1, "right")):
            for height, location in ((.402, "upper"), (-.406, "lower")):
                self.raised_bar(f"Sand nose buffer {side} {location}",
                                (sign * .389, height, -1.76), (sign * .389, height, -1.438),
                                .13, .094, "Sand armor")
            for level, label in ((.217, "upper"), (-.219, "lower")):
                self.piece(f"Graphite {side} {label} rail", (sign * .512, level, .04),
                           (.094, .101, 2.34), "Graphite")
                self.piece(f"Rail {side} {label} bevel", (sign * .523, level + .052, .04),
                           (.056, .012, 2.28), "Graphite edge")
            self.side_badge(f"Forward armor {side}", sign * .489, .05, -.875, .31, .47, .12, "Sand armor")
            self.side_badge(f"Aft lower shoe {side}", sign * .489, -.354, .732, .161, .62, .095, "Sand armor")
        self.side_badge("Offset teal plate rim", .506, -.003, .59, .248, .98, .128, "Graphite edge")
        self.side_badge("Offset teal plate", .524, .003, .591, .204, .921, .119, "Teal enamel")
        self.piece("Teal plate catchlight", (.539, .104, .591), (.006, .012, .73), "Teal edge")

        for level, label in ((-.292, "lower"), (0, "middle"), (.292, "upper")):
            self.shell_section(f"Rear pad {label}", (0, level, 1.567), .504, .141, .435, .075, "Pad rubber")
            self.shell_section(f"Rear pad {label} inset", (0, level, 1.806), .447, .119, .07, .056, "Pad rubber")
        self.piece("Rear pad bridge", (0, 0, 1.382), (.87, .845, .109), "Grip rubber")

        for z, direction, label in ((-.734, 1, "front"), (.731, -1, "rear")):
            self.piece(f"Carry bridge {label} saddle", (0, .473, z), (.477, .126, .391), "Slate edge")
            self.raised_bar(f"Carry bridge {label} arm", (0, .522, z), (0, .885, z + direction * .224),
                            .272, .147, "Graphite")
        self.piece("Carry bridge center", (0, .879, 0), (.27, .144, 1.03), "Grip rubber")
        for index, z in enumerate((-.296, 0, .296), 1):
            self.piece(f"Carry bridge molded pad {index}", (0, .912, z), (.306, .121, .25), "Pad rubber")

        self.piece("Lower grip mount", (0, -.447, .06), (.465, .122, .57), "Graphite")
        self.raised_bar("Lower grip", (0, -.474, .092), (0, -.94, .237), .30, .396, "Graphite")
        for index, y in enumerate((-.596, -.711, -.826), 1):
            z = .092 + (y + .474) / -.466 * .145
            for side, x in (("left", -.153), ("right", .153)):
                self.piece(f"Lower grip {side} inset {index}", (x, y, z), (.012, .059, .236), "Grip rubber",
                           Matrix.Rotation(radians(17), 3, "X"))
        self.marker("CarryGrip", (0, -.699, .164))
        self.marker("Muzzle", (0, 0, -1.849))
        self.marker("GroundContact", (-.559, 0, 0), Matrix.Rotation(radians(90), 3, "Z"))


def stage(scene):
    review = collection(scene, "Review • cameras and lights")
    focus = Vector((0, .05, -.03))
    for name, position, distance in (("Three-quarter", (4, 5, 2.7), 4.8), ("Side profile", (7, 0, 0), 4.6)):
        camera_data = bpy.data.cameras.new(name)
        camera = bpy.data.objects.new(name, camera_data)
        review.objects.link(camera)
        camera.location = position
        camera.rotation_euler = (focus - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera_data.type, camera_data.ortho_scale = "ORTHO", distance
        if name == "Three-quarter":
            scene.camera = camera
    for name, position, power, size in (
        ("Soft key", (3, 4, 6), 780, 4.5), ("Fill", (4, -2, 2), 330, 5),
        ("Rim", (-4, -2, 5), 920, 3.2), ("Nose fill", (-1, 5, .4), 170, 4),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size = power, "DISK", size
        obj = bpy.data.objects.new(name, data)
        review.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (focus - obj.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -1.012))
    floor = bpy.context.object
    floor.name = "Review backdrop"
    for parent in list(floor.users_collection):
        parent.objects.unlink(floor)
    review.objects.link(floor)
    floor.data.materials.append(make_material("Review gray", (107, 105, 106)))
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 28
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1000, 700, 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system, scene.unit_settings.scale_length = "METRIC", .28
    DepotProp(scene).assemble()
    stage(scene)
    bpy.ops.object.select_all(action="DESELECT")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.shading.color_type = "MATERIAL"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))


if __name__ == "__main__":
    main()
