"""Check exact material-triangle preservation and full-scale Salt Flats site fit."""
import math
from pathlib import Path
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from salt_flats import placement, prepare_import as prepare
from salt_flats.walk_surfaces import walk_surfaces


def triangle_corners(doc, blob, primitive):
    """Compare triangles by complete corner data, independent of vertex index order."""
    attrs = [list(prepare.vertex_rows(doc, blob, accession))
             for _name, accession in sorted(primitive["attributes"].items())]
    indices = [int.from_bytes(row, "little")
               for row in prepare.vertex_rows(doc, blob, primitive["indices"])]
    corners = [tuple(attribute[index] for attribute in attrs) for index in indices]
    return list(zip(corners[::3], corners[1::3], corners[2::3]))


class SaltFlatsImportPreflight(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source, cls.binary = prepare.decode_glb(prepare.ASSEMBLY.read_bytes())

    def test_oversized_wreck_material_keeps_each_triangle_and_all_corner_attributes(self):
        mesh = next(m for m in self.source["meshes"] if m["name"].startswith("H40"))
        oversized = next(
            p for p in mesh["primitives"]
            if self.source["accessors"][p["indices"]]["count"] > prepare.TRIANGLE_LIMIT * 3
        )
        doc, blob = prepare.partition(self.source, self.binary)
        split = next(m for m in doc["meshes"] if m["name"] == mesh["name"])
        material = oversized["material"]
        chunks = [p for p in split["primitives"] if p["material"] == material]
        self.assertEqual(len(chunks), 2)
        self.assertTrue(all(doc["accessors"][p["indices"]]["count"] // 3
                            <= prepare.TRIANGLE_LIMIT for p in chunks))
        self.assertCountEqual(
            triangle_corners(self.source, self.binary, oversized),
            [triangle for primitive in chunks for triangle in triangle_corners(doc, blob, primitive)],
        )

    def test_full_size_site_keeps_authored_doors_and_all_wreck_meshes(self):
        poses = prepare.pose_tree(self.source)
        staged = []
        for index, node in enumerate(self.source["nodes"]):
            origin, rotation, props = poses[index]
            if "mesh" not in node or props.get("DamageGroup") != "HerculesWreck":
                continue
            for p in self.source["meshes"][node["mesh"]]["primitives"]:
                position = self.source["accessors"][p["attributes"]["POSITION"]]
                staged.append({"role": "wreck", "sourceObject": node["name"],
                               "pose": {"translation": origin, "rotation": rotation},
                               "localMinimum": position["min"], "localMaximum": position["max"]})
        measure = placement.audit_site(
            [{"objects": staged}], prepare.SITE, prepare.YAW_DEGREES, prepare.HILL_MOVES, prepare.rotate
        )
        doors = measure["mainDoorCentersStuds"]
        self.assertAlmostEqual(math.dist(*doors), 104, places=2)
        self.assertGreater(measure["minimumBoundaryGapStuds"], 25)
        self.assertGreater(min(measure["minimumHillFootprintGapsStuds"].values()), 4)
        self.assertEqual(measure["wreckSourceObjects"], 61)
        with self.assertRaisesRegex(ValueError, "TerrainHill00"):
            placement.audit_site(
                [{"objects": staged}], prepare.SITE, prepare.YAW_DEGREES, {}, prepare.rotate
            )
        with self.assertRaisesRegex(ValueError, "Incomplete wreck assembly"):
            placement.audit_site(
                [{"objects": [row for row in staged if not row["sourceObject"].startswith("H41")]}],
                prepare.SITE, prepare.YAW_DEGREES, prepare.HILL_MOVES, prepare.rotate,
            )

    def test_walking_surfaces_reach_four_levels_and_match_ramp_endpoints(self):
        recipe = walk_surfaces()
        hangar = {box["key"]: box for box in recipe["hangar"]}
        wreck = {box["key"]: box for box in recipe["wreck"]}
        treads = [row for key, row in hangar.items() if "_Tread" in key]
        self.assertEqual(len(treads), 120)
        self.assertEqual(len(hangar), len(recipe["hangar"]))
        for level in range(2, 5):
            deck = hangar[f"Gallery{level}"]
            self.assertAlmostEqual(deck["center"][1] + deck["size"][1] / 2, (level - 1) * 12)
        ramp = wreck["Ramp"]
        pitch = math.radians(ramp["pitchDegrees"])
        _, y, z = ramp["center"]
        half_run = ramp["size"][2] / 2
        half_thickness = ramp["size"][1] / 2
        for sign, expected in [(-1, (3.16, 38.55)), (1, (0.09, 55.20))]:
            self.assertAlmostEqual(y + half_thickness * math.cos(pitch)
                                   - sign * half_run * math.sin(pitch), expected[0])
            self.assertAlmostEqual(z + half_thickness * math.sin(pitch)
                                   + sign * half_run * math.cos(pitch), expected[1])


if __name__ == "__main__":
    unittest.main()
