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
        self.assertEqual(set(recipe), {"TerrainBounds", "SurfaceRaster", "ReliefRaster"})
        raster = recipe["SurfaceRaster"]["Properties"]["Value"]
        expected = ["".join(layout.paint(x, z) for z in range(-358, 360, 4))
                    for x in range(-358, 360, 4)]
        self.assertEqual(raster.splitlines(), expected)
        self.assertEqual(set(raster.replace("\n", "")), set(layout.MATERIALS))
        heights = recipe["ReliefRaster"]["Properties"]["Value"]
        expected_heights = ["".join(format(layout.relief(x, z), "x") for z in range(-358, 360, 4))
                            for x in range(-358, 360, 4)]
        self.assertEqual(heights.splitlines(), expected_heights)
        self.assertTrue(all(h == "0" or m != "." for h, m in zip(heights, raster)))

    def test_each_exit_and_destination_joins_the_circuit_outside_the_reserve(self):
        circuit = layout.TRACKS["Circuit"]
        self.assertEqual(circuit[0], circuit[-1])
        for name in ("NorthExit", "EastExit", "SouthExit", "WestExit"):
            self.assertIn(layout.TRACKS[name][-1], circuit)
        for name in ("Hangar", "Radar", "Depot", "Seedship"):
            self.assertIn(layout.TRACKS[name][0], circuit)
        left, right, north, south = layout.RESERVE
        for name, path in layout.TRACKS.items():
            for a, b in zip(path, path[1:]):
                steps = math.ceil(math.dist(a, b))
                for step in range(steps + 1):
                    x, z = [lo + (hi-lo)*step/steps for lo, hi in zip(a, b)]
                if name != "Seedship":
                    self.assertFalse(left <= x <= right and north <= z <= south, name)
                    self.assertIn(layout.paint(x, z), "dpav", name)
                self.assertEqual(layout.relief(x, z), 0, name)

    def test_south_site_stays_flat_with_four_landmark_launcher_pickups(self):
        self.assertNotIn("SouthBuildingReserve", self.nodes)
        anchors = {node["Name"]: node["Properties"]["CFrame"][:3]
                   for node in self.nodes["Anchors"]["Children"] if node["Name"].startswith("Launcher")}
        self.assertEqual(anchors, {key: list(pos) for key, pos in layout.SITES.items()})
        platform = self.nodes["SeedshipLauncherPlatform"]["Properties"]
        self.assertEqual(platform["CFrame"][:3], [0, 2.5, 214])
        self.assertEqual(platform["Size"], [6, 0.2, 6])
        self.assertTrue(platform["CanCollide"] and platform["CanQuery"])
        for x in range(-106, 107, 4):
            for z in range(186, 333, 4):
                self.assertEqual(layout.relief(x, z), 0)
        self.assertEqual(layout.paint(0, 259), "m")

    def test_crater_rim_and_ridges_fade_to_adjacent_districts(self):
        x, z = layout.CRATER
        self.assertEqual(layout.relief(x, z), 0)
        self.assertGreaterEqual(layout.relief(x - 25, z), 6)
        self.assertEqual(layout.relief(0, -140), 0)
        self.assertLess(layout.martian_weight(0, 141), layout.martian_weight(0, 193))
        self.assertLess(layout.martian_weight(208, 192), layout.martian_weight(108, 235))
