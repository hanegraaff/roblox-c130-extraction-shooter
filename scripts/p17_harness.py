"""Bind the managed P17 native harness to current production and test bytes.

``--write`` refreshes only test-only P17Metadata.luau. The default rejects stale
metadata and any semantic edit to the frozen server/client body. The historical
production revision identifies the original evidence independently of this
checkout's fingerprints. This tool does not run or certify native acceptance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRODUCT_COMMIT = "cd7071b9ed00452ee2bba06d7bc9ccbde22c3976"
PRODUCT_TREE = "1f8d4d231b7081adfe3bafe8ade5dc6acf9e2d47"
OUTPUT = "tests/studio/server/P17Metadata.luau"
FIXTURE_VERSION = "v9-verified-avatar-handoff"
SERVER_PROBE = "tests/studio/server/P17MaterialHarness.luau"
CLIENT_PROBE = "tests/studio/client/P17MaterialHarness.luau"
FROZEN_BODIES = {
    SERVER_PROBE: "150dc81a15bdd0e2eb52803bcc089e100e932eb78125142f024f31035285f4f9",
    CLIENT_PROBE: "980b6023fc486e90cd11c08100cec9d50551df829f845fef9321e0edbb78abf2",
}


def digest(data: bytes) -> str:
    """Return a lowercase SHA-256 for exact source/artifact bytes."""
    return hashlib.sha256(data).hexdigest()


def canonical(value: object) -> bytes:
    """Platform-independent sorted UTF-8 JSON for source-map fingerprints."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def production_path(path: str) -> bool:
    """Select runtime Luau and authored assets, excluding package prose/cache."""
    item = Path(path)
    return (path.startswith("src/") and item.suffix == ".luau") or (
        path.startswith("assets/") and item.suffix != ".md" and "__pycache__" not in item.parts
        and item.suffix != ".pyc"
    ) or path == "default.project.json"


def source_inputs(root: Path) -> tuple[dict[str, str], dict[str, str]]:
    """Discover exact production and test inputs; generated metadata excludes itself."""
    production = {path.relative_to(root).as_posix(): digest(path.read_bytes())
                  for area in ("src", "assets") for path in (root / area).rglob("*")
                  if path.is_file() and production_path(path.relative_to(root).as_posix())}
    production["default.project.json"] = digest((root / "default.project.json").read_bytes())
    fixtures = {path.relative_to(root).as_posix(): digest(path.read_bytes())
                for path in (root / "tests").rglob("*")
                if path.is_file() and path.suffix in {".luau", ".json", ".py"}
                and path.relative_to(root).as_posix() != OUTPUT}
    for name in ("test.project.json", "rokit.toml", "wally.toml", "wally.lock",
                 "scripts/p17_harness.py", "scripts/inspect_build.py", "scripts/verify.py",
                 "scripts/lobby_interior/prepare_collision.py", "scripts/lobby_interior/stage_import.py",
                 "scripts/lobby_interior/native_config.py", "scripts/lobby_interior/capture_native.luau",
                 "scripts/lobby_interior/finish_native.luau",
                 "docs/evidence/p22/blender-oil-reimport.json", "docs/evidence/p22/upload-operations.json"):
        fixtures[name] = digest((root / name).read_bytes())
    return dict(sorted(production.items())), dict(sorted(fixtures.items()))


def check_inputs(root: Path, expected: dict[str, str], actual: dict[str, str]) -> None:
    """Reject missing, added or changed bound files without mutating the checkout."""
    if expected.keys() != actual.keys():
        raise ValueError("source input coverage differs: " + str(sorted(expected.keys() ^ actual.keys())))
    for name, value in expected.items():
        if value != actual[name] or not (root / name).is_file():
            raise ValueError("source fingerprint differs: " + name)


def check_frozen_body(path: Path, expected: str) -> None:
    """Permit documented header/module-name promotion only; preserve v7 executable bytes."""
    contents = path.read_bytes()
    marker = b"local Players ="
    if marker not in contents or digest(contents[contents.index(marker):]) != expected:
        raise ValueError("frozen gameplay body differs: " + path.name)


def check_reference_revision(root: Path) -> None:
    """Verify the historical P17 source anchor without pinning future runtime edits."""
    reference = subprocess.run(
        ["git", "rev-parse", "--verify", f"{PRODUCT_COMMIT}^{{tree}}"],
        cwd=root, text=True, capture_output=True,
    )
    if reference.returncode != 0 or reference.stdout.strip() != PRODUCT_TREE:
        raise ValueError("historical P17 production revision unavailable or incorrect")


def metadata(root: Path = ROOT) -> dict:
    """Generate provenance data only; the future harness commit is supplied at invocation."""
    for name, expected in FROZEN_BODIES.items():
        check_frozen_body(root / name, expected)
    production, fixtures = source_inputs(root)
    check_reference_revision(root)
    manifest = json.loads((root / "assets/manifest.json").read_text())
    bindings = [{key: asset.get(key) for key in ("id", "roblox_asset_id", "upload_owner", "uploaded_revision", "sha256")}
                for asset in manifest["assets"] if asset.get("roblox_asset_id")]
    return {
        "schemaVersion": 2,
        "referenceProductionCommit": PRODUCT_COMMIT,
        "referenceProductionTree": PRODUCT_TREE,
        "productionFingerprintSha256": digest(canonical(production)),
        "harnessFingerprintSha256": digest(canonical(fixtures)),
        "productionInputs": production,
        "harnessInputs": fixtures,
        "approvedAssetBindings": bindings,
        "privateImportWorkspace": {"universeId": "10776653720", "placeId": "72732833195348", "owner": "2227341845"},
        "expectedFullMaterialCases": 10,
        "requestedActualClients": 2,
        "manualFixtureVersion": FIXTURE_VERSION,
        "serverProbeSha256": fixtures[SERVER_PROBE],
        "clientProbeSha256": fixtures[CLIENT_PROBE],
        "status": "historical pre-P18 fixture; current entry rejects, use P18",
    }


def render(value: dict) -> str:
    """Render trusted generated provenance; it does not claim tables are immutable."""
    return ('--!strict\n-- Generated test-only provenance by scripts/p17_harness.py --write.\n'
            '-- Trusted source data; no acceptance result or future commit is embedded.\n'
            'return game:GetService("HttpService"):JSONDecode(\n    [==[' + canonical(value).decode() + ']==]\n)\n')


def verify(root: Path = ROOT) -> dict:
    """Reject stale generated metadata before any Studio or world mutation."""
    expected = metadata(root)
    path = root / OUTPUT
    if not path.is_file():
        raise ValueError("P17 harness metadata is missing")
    text = path.read_text()
    try:
        stored = json.loads(text.split("[==[", 1)[1].rsplit("]==]", 1)[0])
        check_inputs(root, stored["productionInputs"], expected["productionInputs"])
        check_inputs(root, stored["harnessInputs"], expected["harnessInputs"])
    except (IndexError, KeyError, TypeError, json.JSONDecodeError) as error:
        raise ValueError("P17 harness metadata is malformed") from error
    if text != render(expected):
        raise ValueError("P17 harness metadata is stale; review source and run scripts/p17_harness.py --write")
    return expected


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="refresh the test-only provenance module")
    arguments = parser.parse_args()
    if arguments.write:
        (ROOT / OUTPUT).write_text(render(metadata()))
    value = verify()
    print(f"P17 harness binding passed: {len(value['productionInputs'])} current production inputs, "
          f"{len(value['harnessInputs'])} fixture inputs; {FIXTURE_VERSION} bodies exact, no native execution.")


if __name__ == "__main__":
    main()
