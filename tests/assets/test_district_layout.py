"""Check the stock district layout and the approaches players follow from Sandbreak."""
import json
import math
import unittest

from scripts.districts import layout


class DistrictLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = json.loads(layout.WORLD.read_text())
        cls.nodes = {child["Name"]: child for child in source["Children"]}

    def test_checked_in_terrain_matches_every_authored_cell(self):
        recipe = {child["Name"]: child for child in self.nodes["TerrainRecipe"]["Children"]}
        self.assertEqual(set(recipe), {"TerrainBounds", "SurfaceRaster"})
        raster = recipe["SurfaceRaster"]["Properties"]["Value"]
        expected = ["".join(layout.paint(x, z) for z in range(-358, 360, 4))
                    for x in range(-358, 360, 4)]
        self.assertEqual(raster.splitlines(), expected)
        self.assertEqual(set(raster.replace("\n", "")), set(layout.MATERIALS))

    def test_each_exit_and_destination_joins_the_circuit_outside_the_reserve(self):
        circuit = layout.TRACKS["Circuit"]
        self.assertEqual(circuit[0], circuit[-1])
        for name in ("NorthExit", "EastExit", "SouthExit", "WestExit"):
            self.assertIn(layout.TRACKS[name][-1], circuit)
        for name in ("Hangar", "Radar", "Depot"):
            self.assertIn(layout.TRACKS[name][0], circuit)
        left, right, north, south = layout.RESERVE
        for name, path in layout.TRACKS.items():
            for a, b in zip(path, path[1:]):
                steps = math.ceil(math.dist(a, b))
                for step in range(steps + 1):
                    x, z = [lo + (hi-lo)*step/steps for lo, hi in zip(a, b)]
                    self.assertFalse(left <= x <= right and north <= z <= south, name)
                    self.assertIn(layout.paint(x, z), "dpav", name)

    def test_south_pad_has_only_corner_marks_and_no_pickup(self):
        reserve = self.nodes["SouthBuildingReserve"]
        self.assertEqual({part["Name"] for part in reserve["Children"]},
                         {f"Survey{i}{j}{axis}" for i in range(2) for j in range(2) for axis in "XZ"})
        for item in reserve["Children"]:
            self.assertFalse(item["Properties"]["CanCollide"])
        anchors = {node["Name"]: node["Properties"]["CFrame"][:3]
                   for node in self.nodes["Anchors"]["Children"] if node["Name"].startswith("Launcher")}
        self.assertEqual(anchors, {key: list(pos) for key, pos in layout.SITES.items()})
        for x in range(-106, 107, 4):
            for z in range(186, 333, 4):
                self.assertEqual(layout.paint(x, z), "s")
