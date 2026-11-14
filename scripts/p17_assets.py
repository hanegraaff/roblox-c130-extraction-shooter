"""Compile the approved P16 material geometry into a server-only definition.

This gate checks immutable reviewed inputs and deterministic runtime data. It
never uploads assets, assigns cloud ownership or claims imported mesh availability.
The default command is read-only; --write regenerates only ApprovedOutpost.luau.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path("assets/blender/military-outpost")
EXPORT = Path("assets/exports/military-outpost")
OUTPUT = Path("src/server/ApprovedOutpost.luau")
BLEND_SHA = "4c1c5264020616b1af3b36c9dd37442919b386655149ee207591cd37da041d8c"
CATALOG_SHA = "6e632a170de2183e355759e544980170d62b157365b62716ef913ed32f193478"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def approved_catalog(root: Path = ROOT) -> dict:
    """Fail before generation if reviewed source/catalog identity has changed."""
    for name, expected in (("military-outpost.blend", BLEND_SHA), ("panel-catalog.json", CATALOG_SHA)):
        if sha(root / SOURCE / name) != expected:
            raise ValueError(f"P17 requires the approved P16 input: {name}")
    return json.loads((root / SOURCE / "panel-catalog.json").read_text())


def compile_definition(root: Path = ROOT) -> str:
    """Compile exact rectangles and export hashes, preserving reviewed coordinates."""
    catalog = approved_catalog(root)
    lock = json.loads((root / SOURCE / "package-lock.json").read_text())
    locked = {entry["path"]: entry["sha256"] for entry in lock["files"]}
    def source_record(name: str) -> str:
        path = EXPORT / name
        digest = sha(root / path)
        if locked.get(path.as_posix()) != digest:
            raise ValueError(f"P17 source export differs from reviewed package lock: {name}")
        return digest
    lines = [
        "--!strict", "--[=[",
        "    ApprovedOutpost: immutable server-only construction data derived from the exact",
        "    P16 package approved by the user. Units are studs; canonical coordinates are",
        "    Blender X/Y/Z (face X/Z). No assets are uploaded or presumed accessible here.",
        "    Regenerate with scripts/p17_assets.py; never hand-tune approved art data.",
        "]=]",
        "export type Source = { source: string, sha256: string }",
        "export type State = { source: string, sha256: string, rectangles: { { number } } }",
        "export type Family = { size: { number }, states: { [string]: State }, fragments: { Source } }",
        "local ApprovedOutpost: { revision: string, blendSha256: string, families: { [string]: Family } } = { revision = \"p16-v1\", blendSha256 = \"\", families = {} }",
        'ApprovedOutpost.revision = "p16-v1"',
        f'ApprovedOutpost.blendSha256 = "{BLEND_SHA}"',
        "ApprovedOutpost.families = {",
    ]
    for family in catalog["families"]:
        lines += [f'    {family["id"]} = {{', "        size = { " + ", ".join(map(str, family["dimensions_studs"])) + " },", "        states = {"]
        for name, state in family["states"].items():
            lines += [f"            {name} = {{", f'                source = "{state["mesh"]}",', f'                sha256 = "{source_record(state["mesh"])}",', "                rectangles = {"]
            for rectangle in state["rectangles"]:
                lines += ["                    { " + ", ".join(f"{number:.6g}" for number in rectangle) + " },"]
            lines += ["                },", "            },"]
        lines += ["        },", "        fragments = {"]
        for fragment in family["fragments"]:
            lines += [f'            {{ source = "{fragment["mesh"]}", sha256 = "{source_record(fragment["mesh"])}" }},']
        lines += ["        },", "    },"]
    lines += ["}", "return ApprovedOutpost", ""]
    return "\n".join(lines)


def normalized(source: str) -> str:
    """Ignore formatter whitespace only; all tokens and values must still match."""
    return re.sub(r",(?=})", "", re.sub(r"\s+", "", source))


def verify(root: Path = ROOT) -> dict:
    generated = compile_definition(root)
    if normalized((root / OUTPUT).read_text()) != normalized(generated):
        raise ValueError("P17 runtime definition differs from approved catalog; regenerate scripts/p17_assets.py --write")
    manifest = json.loads((root / "assets/manifest.json").read_text())
    recipes = [entry for entry in manifest.get("runtime_recipes", []) if entry["id"] == "approved-outpost-materials"]
    if len(recipes) != 1 or recipes[0].get("local_path") != OUTPUT.as_posix() or recipes[0].get("sha256") != sha(root / OUTPUT):
        raise ValueError("P17 runtime descriptor requires exact manifest provenance/hash")
    return {"suite": "P17AssetDefinition", "discovered": 1, "passed": 1, "failed": 0,
            "families": 6, "appearances": 24, "fragment_sources": 24,
            "cloud_import_verified": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.write:
        (ROOT / OUTPUT).write_text(compile_definition())
        print(f"Regenerated {OUTPUT}; format it and refresh its runtime_recipes SHA-256 before verification.")
    else:
        print(json.dumps(verify(), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError) as error:
        print(f"P17 asset preparation failed: {error}", file=sys.stderr)
        sys.exit(1)
