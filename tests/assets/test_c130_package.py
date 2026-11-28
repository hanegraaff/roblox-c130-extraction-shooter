"""R27/P28 A1 package invariants for the editable and source-managed aircraft."""
import hashlib
import json
from math import cos, sin, tau
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "assets/models/C130.model.json"
EXPORTS = ROOT / "assets/exports/c130"


class AircraftPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = json.loads(NATIVE.read_text())
        cls.audit = json.loads((EXPORTS / "package-audit.json").read_text())
        cls.root, cls.airframe, cls.rotors, cls.rounded_queries = cls.model["Children"]

    def test_managed_export_has_bound_blender_source_and_no_remote_dependencies(self):
        self.assertEqual(self.audit["externalAssetDependencies"], [])
        for path, expected in self.audit["sha256"].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected, path)
        glb = (EXPORTS / "c130.glb").read_bytes()
        magic, version, length, json_size, kind = struct.unpack_from("<4s4I", glb)
        self.assertEqual((magic, version, length, kind), (b"glTF", 2, len(glb), 0x4E4F534A))
        graph = json.loads(glb[20:20 + json_size])
        self.assertNotIn("images", graph)
        self.assertFalse(any("uri" in entry for entry in graph["buffers"]))
        self.assertEqual(len(graph["nodes"]), self.audit["meshObjects"])
        self.assertEqual(len(graph["meshes"]), self.audit["meshObjects"])

    def test_flight_frame_muzzles_share_original_root_and_visible_bores(self):
        root = self.root["Properties"]
        self.assertEqual(self.root["Name"], "Hitbox")
        self.assertEqual(root["Size"], [12, 10, 46])
        self.assertEqual(root["CFrame"], [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
        self.assertEqual(root["Transparency"], 1)
        self.assertFalse(root["CanQuery"])
        markers = {item["Name"]: item["Properties"]["CFrame"] for item in self.root["Children"]}
        visual = {item["Name"]: item["Properties"] for item in self.airframe["Children"]}
        for weapon, sign in (("GAU23", -1), ("M102", 1)):
            marker = markers[f"{weapon}Muzzle"]
            self.assertEqual(marker[:3], visual[f"{weapon} dark bore"]["CFrame"][:3])
            self.assertEqual(marker[:3], self.audit["muzzlesStuds"][f"{weapon}Muzzle"])
            self.assertGreater(marker[0] * sign, 6)
            self.assertLess(marker[1], 0)
            self.assertEqual(marker[3], sign)
        for span, low, high in zip((58, 18.5, 57.6), self.audit["boundsStuds"]["minimum"],
                                   self.audit["boundsStuds"]["maximum"]):
            self.assertAlmostEqual(high - low, span, delta=0.1)
        self.assertLess(self.audit["boundsStuds"]["minimum"][2], -27)

    def test_painted_skin_embeds_one_atlas_and_replaces_raised_paint(self):
        layout = json.loads((EXPORTS / "c130-painted-layout.json").read_text())
        receipt = json.loads((ROOT / "assets/imports/c130/native-receipt.json").read_text())
        skin = (ROOT / "assets/models/C130PaintedSkin.rbxm").read_bytes()
        glb = (EXPORTS / "c130-painted-skin.glb").read_bytes()
        atlas = (EXPORTS / "c130-camouflage.png").read_bytes()
        for bytes_, key in ((skin, "nativeSha256"), (glb, "sourceGlbSha256"), (atlas, "textureSha256")):
            self.assertEqual(hashlib.sha256(bytes_).hexdigest(), receipt[key])
        self.assertEqual(struct.unpack_from(">2I", atlas, 16), (2048, 2048))
        json_size, json_type = struct.unpack_from("<2I", glb, 12)
        self.assertEqual(json_type, 0x4E4F534A)
        graph = json.loads(glb[20:20 + json_size])
        self.assertEqual(len(graph["images"]), 1)
        self.assertNotIn("uri", graph["images"][0])
        self.assertEqual(set(layout["regions"]), {item["name"] for item in receipt["parts"]})
        self.assertEqual(len(graph["meshes"]), 3)
        self.assertTrue(all(0 < data["triangles"] < 20000 for data in layout["regions"].values()))
        self.assertEqual(len({item["texture"] for item in receipt["parts"]}), 1)
        source = {item["Name"]: item for item in self.airframe["Children"]}
        self.assertTrue(set(layout["replacesVisuals"]) <= source.keys())
        self.assertTrue(all(not source[name]["Properties"]["CanQuery"] for name in layout["removedRaisedPaint"]))
        self.assertEqual({name for name in source if " shark " in name},
                         {name for name in layout["removedRaisedPaint"] if " shark " in name})

    def test_native_query_shapes_and_cosmetic_rotors_do_not_share_authority(self):
        visual = self.airframe["Children"]
        groups = self.rotors["Children"]
        self.assertEqual([group["Name"] for group in groups], ["Port1", "Port2", "Starboard1", "Starboard2"])
        for group in groups:
            rotor_name = group["Name"]
            parts = group["Children"]
            self.assertEqual(parts[0]["Name"], "Hub")
            self.assertEqual(parts[0]["Properties"]["CFrame"][:3], self.audit["rotorAxesStuds"][rotor_name])
            self.assertEqual(len(parts), 9)
            self.assertTrue(all(not part["Properties"]["CanQuery"] for part in parts))
        self.assertEqual(sum(item["Properties"]["CanQuery"] for item in visual)
                         + len(self.rounded_queries["Children"]),
                         self.audit["nativeQueryableObjects"])
        self.assertTrue(all(item["Properties"]["Transparency"] == 0 for item in visual
                            if item["Properties"]["CanQuery"]))
        managed = visual + [part for rotor in groups for part in rotor["Children"][1:]]
        self.assertEqual(len(managed), self.audit["meshObjects"])
        self.assertLessEqual(len(managed), 325)
        self.assertTrue(all(item["ClassName"] in {"Part", "WedgePart"} for item in managed))
        for item in managed:
            properties = item["Properties"]
            self.assertFalse(properties["CanTouch"])
            self.assertFalse(properties["CanCollide"])

    def test_rounded_render_meshes_and_engines_use_only_inscribed_native_queries(self):
        visual = {item["Name"]: item for item in self.airframe["Children"] if item.get("Children")}
        queries = self.rounded_queries["Children"]
        self.assertEqual(len(queries), self.audit["nativeRoundedQueryVolumes"])
        self.assertLessEqual(len(queries), 200)
        for name in ("Rounded flight deck", "Cargo rear shell", "Tapered tail cone",
                     "Port1 nacelle", "Port2 nacelle", "Starboard1 nacelle", "Starboard2 nacelle"):
            self.assertTrue(any(item["Name"].startswith(name + " query ") for item in queries), name)
        for item in visual.values():
            mesh, = item["Children"]
            self.assertEqual(mesh["ClassName"], "SpecialMesh")
            self.assertEqual(mesh["Properties"]["MeshType"], "Sphere")
            self.assertNotIn("MeshId", mesh["Properties"])
            self.assertEqual(item["Properties"]["Size"], [1, 1, 1])
            self.assertFalse(item["Properties"]["CanQuery"])
        for query in queries:
            props = query["Properties"]
            name, _ = query["Name"].rsplit(" query ", 1)
            source = visual[name]
            mesh, = source["Children"]
            source_frame = source["Properties"]["CFrame"]
            frame = props["CFrame"]
            length, width, depth = props["Size"]
            self.assertEqual(width, depth)
            self.assertEqual(props["Shape"], "Cylinder")
            self.assertTrue(props["CanQuery"])
            self.assertFalse(props["CanCollide"] or props["CanTouch"])
            self.assertEqual(props["Transparency"], 1)
            semiaxes = [axis * 0.5 for axis in mesh["Properties"]["Scale"]]
            # Cylinder volume is convex. Both sampled end circles must fit
            # the visible ellipsoid, which also contains the volume between.
            for end in (-0.5, 0.5):
                for spoke in range(128):
                    angle = spoke * tau / 128
                    point = [length * end, width * 0.5 * cos(angle), depth * 0.5 * sin(angle)]
                    world = [frame[row] + sum(frame[3 + row * 3 + col] * point[col] for col in range(3))
                             for row in range(3)]
                    local = [sum(source_frame[3 + row * 3 + col] * (world[row] - source_frame[row])
                                 for row in range(3)) for col in range(3)]
                    distance_squared = sum((axis / semiaxis) ** 2 for axis, semiaxis in zip(local, semiaxes))
                    self.assertLessEqual(distance_squared, 1, query["Name"])


if __name__ == "__main__":
    unittest.main()
