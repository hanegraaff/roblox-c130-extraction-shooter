"""Author the editable field case and a Blender-only front/rear review stage."""
from math import radians
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "assets/blender/medkit/medkit.blend"
sys.path.insert(0, str(ROOT / "scripts/rocket_launcher"))
from author import DepotProp, collection, make_material


PALETTE = {
    "Stone polymer": (143, 133, 120),
    "Stone bevel": (164, 153, 138),
    "Stone recess": (109, 100, 89),
    "Molded graphite": (55, 56, 59),
    "Graphite bevel": (76, 76, 76),
    "Rubber and seams": (41, 41, 42),
    "Medical enamel": (173, 71, 34),
    "Ivory marking": (246, 232, 205),
}


class FieldCase(DepotProp):
    """Model the case from exportable native profiles in studs, with -Z forward."""

    def __init__(self, scene):
        self.shell = collection(scene, "Field medkit • export geometry")
        self.materials = {name: make_material(name, rgb) for name, rgb in PALETTE.items()}

    def bumper(self, side, height, x_sign, y_sign, y_edge):
        name = f"{height} {side} bumper"
        x_edge = 1.07 * x_sign
        y_center = y_edge - .15 * y_sign
        self.shell_section(name, (x_edge - .17 * x_sign, y_center, 0), .17, .15, .91, .073,
                           "Molded graphite", "Graphite bevel")
        for face, z_sign in (("front", -1), ("rear", 1)):
            self.piece(f"{name} {face} inset", (x_edge - .17 * x_sign, y_center, .455 * z_sign),
                       (.15, .12, .012), "Graphite bevel")

    def assemble_case(self):
        self.shell_section("Case body", (0, .613, 0), 1.036, .58, .83, .14, "Stone polymer", "Stone bevel")
        self.shell_section("Lid seam", (0, 1.159, 0), 1.042, .023, .834, .017, "Rubber and seams")
        self.shell_section("Lid", (0, 1.281, 0), 1.046, .118, .858, .083, "Stone polymer", "Stone bevel")
        for side, sign in (("left", -1), ("right", 1)):
            self.bumper(side, "Lower", sign, -1, 0)
            self.bumper(side, "Upper", sign, 1, 1.41)

        self.shell_section("Front inset trim", (0, .59, -.419), .768, .309, .036, .089, "Stone recess")
        self.shell_section("Orange enamel inset", (0, .59, -.442), .733, .277, .02, .073, "Medical enamel")
        self.piece("Ivory cross upright", (0, .59, -.457), (.155, .432, .016), "Ivory marking")
        for side, sign in (("left", -1), ("right", 1)):
            self.piece(f"Ivory cross {side} arm", (.145 * sign, .59, -.457), (.135, .155, .016), "Ivory marking")

        self.shell_section("Rear inset trim", (0, .59, .419), .769, .315, .034, .095, "Stone recess")
        self.shell_section("Rear polymer inset", (0, .59, .439), .733, .283, .019, .079, "Stone polymer")
        for face, sign in (("Front", -1), ("Rear", 1)):
            for row, y in (("upper", .989), ("lower", .187)):
                self.piece(f"{face} {row} stiffening channel", (0, y, .422 * sign), (.805, .036, .023), "Stone recess")
                self.piece(f"{face} {row} chamfer", (0, y - .021, .426 * sign), (.758, .014, .018), "Stone bevel")

        for side, sign in (("left", -1), ("right", 1)):
            x = .621 * sign
            self.piece(f"{side} catch bed", (x, 1.159, -.436), (.247, .269, .061), "Rubber and seams")
            self.piece(f"{side} catch axle", (x, 1.268, -.467), (.208, .074, .089), "Graphite bevel")
            self.piece(f"{side} catch clip", (x, 1.139, -.485), (.166, .174, .089), "Molded graphite")
            self.piece(f"{side} catch clip bevel", (x, 1.206, -.531), (.145, .024, .016), "Graphite bevel")
            self.piece(f"{side} hinge plate", (x, 1.15, .442), (.242, .16, .073), "Molded graphite")
            self.piece(f"{side} hinge knuckle", (x, 1.181, .489), (.173, .079, .065), "Graphite bevel")
            self.piece(f"{side} handle foot", (.366 * sign, 1.429, -.016), (.227, .075, .235), "Molded graphite")
            tilt = Matrix.Rotation(radians(26 * sign), 3, "Z")
            self.piece(f"{side} sloped handle arm", (.327 * sign, 1.55, -.016), (.142, .239, .168),
                       "Graphite bevel", tilt)
        self.piece("Grip spine", (0, 1.653, -.016), (.6, .115, .171), "Molded graphite")
        for rib in range(-3, 4):
            self.piece(f"Grip rib {rib + 4}", (rib * .065, 1.658, -.016), (.04, .121, .183), "Rubber and seams")


def stage(scene):
    review = collection(scene, "Review • cameras and lights")
    focus = Vector((0, 0, .82))
    for name, position in (("Front three-quarter", (2.6, 5, 2.45)), ("Rear three-quarter", (-2.6, -5, 2.45))):
        data = bpy.data.cameras.new(name)
        camera = bpy.data.objects.new(name, data)
        review.objects.link(camera)
        camera.location = position
        camera.rotation_euler = (focus - camera.location).to_track_quat("-Z", "Y").to_euler()
        data.type, data.ortho_scale = "ORTHO", 3.35
    scene.camera = bpy.data.objects["Front three-quarter"]
    for name, position, power, size in (
        ("Soft key", (1.5, 3, 4.5), 320, 3.3), ("Front fill", (-2, 3, 2.5), 135, 4),
        ("Rear fill", (-2, -3, 3.5), 240, 4), ("Rim", (3, -2, 4), 270, 2.5),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.shape, data.size = power, "DISK", size
        light = bpy.data.objects.new(name, data)
        review.objects.link(light)
        light.location = position
        light.rotation_euler = (focus - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.004))
    floor = bpy.context.object
    floor.name = "Review backdrop"
    for parent in list(floor.users_collection):
        parent.objects.unlink(floor)
    review.objects.link(floor)
    floor.data.materials.append(make_material("Review gray", (96, 94, 93)))
    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 24, True
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 900, 650, 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system, scene.unit_settings.scale_length = "METRIC", .28
    FieldCase(scene).assemble_case()
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
