"""Check the P22 artifact inspector's rejection paths with small XML fixtures."""

import base64
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from inspect_build import CFRAME_COMPONENTS, LOBBY_ART, check_native_lobby_art


NAME = "P22_Portrait_04"
SOURCE = "Portrait 04 | canvas"
HASH = "e" * 64
APPROVED_COLOR = "rbxassetid://111747031021921"
CANVAS = f"{LOBBY_ART}/{NAME}"
APPEARANCE = f"{CANVAS}/{NAME}_Surface"


def attribute_bytes(items):
    output = bytearray(struct.pack("<I", len(items)))
    for key, value in items.items():
        output.extend(struct.pack("<I", len(key)) + key.encode())
        if isinstance(value, str):
            encoded = value.encode()
            output.extend(bytes([2]) + struct.pack("<I", len(encoded)) + encoded)
        elif isinstance(value, list):
            output.extend(bytes([17]) + struct.pack("<3f", *value))
        else:
            output.extend(bytes([6]) + struct.pack("<d", value))
    return base64.b64encode(output).decode()


def property_node(properties, tag, name, value):
    entry = ET.SubElement(properties, tag, name=name)
    entry.text = str(value)
    return entry


def visual_fixture(color_id=APPROVED_COLOR):
    root = ET.Element("Item", {"class": "Folder"})
    mesh = ET.SubElement(root, "Item", {"class": "MeshPart"})
    properties = ET.SubElement(mesh, "Properties")
    for key, value in (("Anchored", "true"), ("CanCollide", "false"), ("CanQuery", "false"), ("CanTouch", "false")):
        property_node(properties, "bool", key, value)
    pose = ET.SubElement(properties, "CoordinateFrame", name="CFrame")
    for key, value in zip(CFRAME_COMPONENTS, [584.218, 9.1, -20.6, 1, 0, 0, 0, 1, 0, 0, 0, 1]):
        ET.SubElement(pose, key).text = str(value)
    for name, values in (("size", [.001, 10.2, 7.65]), ("InitialSize", [0, 10.2, 7.65])):
        size = ET.SubElement(properties, "Vector3", name=name)
        for axis, value in zip("XYZ", values):
            ET.SubElement(size, axis).text = str(value)
    mesh_id = ET.SubElement(properties, "Content", name="MeshContent")
    ET.SubElement(mesh_id, "uri").text = "rbxassetid://10"
    property_node(properties, "BinaryString", "AttributesSerialize", attribute_bytes({
        "LobbyArtSource": SOURCE,
        "LobbyArtRole": "Portrait",
        "LobbyPortrait": 4,
        "LobbyColorSourceSha256": HASH,
        "LobbyNativeColor": color_id,
        "NativeMeshId": "rbxassetid://10",
        "NativeMeshSize": [0, 10.2, 7.65],
        "NativeCollisionFidelity": "Default",
        "NativeRenderFidelity": "Automatic",
    }))
    appearance = ET.SubElement(mesh, "Item", {"class": "SurfaceAppearance"})
    appearance_properties = ET.SubElement(appearance, "Properties")
    color = ET.SubElement(appearance_properties, "Content", name="ColorMapContent")
    ET.SubElement(color, "uri").text = color_id
    return {LOBBY_ART: root, CANVAS: mesh, APPEARANCE: appearance}


class WaitingLobbyCompiled(unittest.TestCase):
    def setUp(self):
        self.nodes = visual_fixture()
        self.catalog = {"paintings": [{
            "canvas": SOURCE,
            "source_sha256": HASH,
            "portrait": 4,
            "center_blender": [64.218, 20.6, 9.1],
            "size_studs": [7.65, 10.2],
        }]}
        mock = patch("inspect_build.approved_lobby_art", return_value={SOURCE: ("Portrait", HASH)})
        mock.start()
        self.addCleanup(mock.stop)

    def test_compiled_canvas_preserves_native_mesh_and_color_slots(self):
        signature = check_native_lobby_art(self.nodes, self.catalog)
        self.assertEqual(signature[SOURCE][-2:], ("rbxassetid://10", APPROVED_COLOR))

    def test_rejects_compiled_canvas_with_metadata_but_wrong_color_slot(self):
        self.nodes[APPEARANCE].find("Properties/Content/uri").text = "rbxassetid://99"
        with self.assertRaisesRegex(RuntimeError, "Missing native lobby color texture"):
            check_native_lobby_art(self.nodes, self.catalog)

    def test_rejects_unapproved_image_even_if_serialized_metadata_matches(self):
        with self.assertRaisesRegex(RuntimeError, "Unapproved native lobby color asset"):
            check_native_lobby_art(visual_fixture("rbxassetid://99"), self.catalog)

    def test_rejects_moved_or_unanchored_canvas(self):
        with self.subTest("unexpected placement"):
            self.nodes[CANVAS].find("Properties/CoordinateFrame/X").text = "585"
            with self.assertRaisesRegex(RuntimeError, "Portrait 4 native frame, texture or placement"):
                check_native_lobby_art(self.nodes, self.catalog)
        with self.subTest("unanchored"):
            self.nodes[CANVAS].find("Properties/bool[@name='Anchored']").text = "false"
            with self.assertRaisesRegex(RuntimeError, "collision settings"):
                check_native_lobby_art(self.nodes, self.catalog)

    def test_rejects_second_assembly_or_imported_character(self):
        with self.subTest("storage copy"):
            self.nodes["ServerStorage/Assets/LobbyArt"] = ET.Element("Item", {"class": "Folder"})
            with self.assertRaisesRegex(RuntimeError, "Duplicate managed lobby art"):
                check_native_lobby_art(self.nodes, self.catalog)
            del self.nodes["ServerStorage/Assets/LobbyArt"]
        with self.subTest("extra character"):
            self.nodes[f"{LOBBY_ART}/ImportedAvatar"] = ET.Element("Item", {"class": "Model"})
            with self.assertRaisesRegex(RuntimeError, "Unexpected lobby art object"):
                check_native_lobby_art(self.nodes, self.catalog)
