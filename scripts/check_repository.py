"""Check local documentation links, project mappings, and asset provenance shape.

Uses only Python's standard library. This checks a source scaffold, not gameplay,
remote URLs, or Markdown heading anchors. Run from any directory; paths resolve
relative to the repository containing this script.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
IGNORED = {".git", ".tools", "build", "artifacts", "Packages", "ServerPackages", "__pycache__"}
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
ASSET_ROOTS = ("world", "models", "blender", "exports")
MAX_AUTHORED_BINARY_BYTES = 20 * 1024 * 1024


def source_files(suffix: str) -> list[Path]:
    """Return authored files of one suffix, excluding generated directories."""
    return sorted(
        path for path in ROOT.rglob(f"*{suffix}")
        if not IGNORED.intersection(path.relative_to(ROOT).parts)
    )


def local_target(base: Path, value: str, *, root: Path = ROOT) -> Path:
    """Resolve a local reference and reject paths outside this repository."""
    root = root.resolve()
    target = (base / unquote(value)).resolve()
    if not target.is_relative_to(root):
        raise ValueError(f"reference escapes repository: {value}")
    if not target.exists():
        raise ValueError(f"missing local path: {value}")
    return target


def check_project_paths(value: object, base: Path) -> None:
    """Walk a Rojo mapping and validate its filesystem inputs recursively."""
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "$path":
                if not isinstance(child, str):
                    raise ValueError("this scaffold expects string $path values")
                local_target(base, child)
            else:
                check_project_paths(child, base)
    elif isinstance(value, list):
        for child in value:
            check_project_paths(child, base)


def check_manifest(manifest: dict, *, root: Path = ROOT) -> None:
    """Check exact authored coverage/provenance and hash-bound Blender exports.

    ``root`` permits disposable checkout fixtures. Ordinary Git stores the P16
    package; each binary must remain below 20 MiB. Hashes bind reviewed files,
    while the separate asset audit validates their geometry and dependencies.
    This performs no upload, licensing inference or Blender/engine execution.
    """
    root = root.resolve()
    if manifest.get("schema_version") != 1 or not isinstance(manifest.get("assets"), list):
        raise ValueError("manifest requires schema_version 1 and an assets list")
    seen: set[str] = set()
    seen_paths: set[str] = set()
    for asset in manifest["assets"]:
        for key in ("id", "kind", "source", "author", "license"):
            if not isinstance(asset.get(key), str) or not asset[key].strip():
                raise ValueError(f"asset requires nonempty {key}")
        if asset["id"] in seen:
            raise ValueError(f"duplicate asset id: {asset['id']}")
        seen.add(asset["id"])
        for key in ("local_path", "roblox_asset_id", "upload_owner"):
            if key not in asset or (asset[key] is not None and not isinstance(asset[key], str)):
                raise ValueError(f"asset {asset['id']} requires string or null {key}")
        if not asset["local_path"] and not asset["roblox_asset_id"]:
            raise ValueError(f"asset {asset['id']} has no source file or Roblox reference")
        if asset["local_path"]:
            path = local_target(root, asset["local_path"], root=root)
            if not path.is_file():
                raise ValueError(f"asset {asset['id']} requires a file")
            canonical_path = path.relative_to(root).as_posix()
            if canonical_path != asset["local_path"] or canonical_path in seen_paths:
                raise ValueError(f"duplicate or noncanonical asset path: {asset['local_path']}")
            seen_paths.add(canonical_path)
            is_package = canonical_path.startswith(("assets/blender/", "assets/exports/"))
            digest = asset.get("sha256")
            if is_package or digest is not None:
                if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                    raise ValueError(f"asset {asset['id']} requires a lowercase SHA-256")
                if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                    raise ValueError(f"asset hash mismatch: {canonical_path}")
            if is_package and path.stat().st_size >= MAX_AUTHORED_BINARY_BYTES:
                raise ValueError(f"asset exceeds ordinary-Git file budget: {canonical_path}")
        if asset["roblox_asset_id"] and not asset["roblox_asset_id"].isdigit():
            raise ValueError(f"asset {asset['id']} has a nonnumeric Roblox ID")

    recipes = manifest.get("runtime_recipes", [])
    if not isinstance(recipes, list):
        raise ValueError("manifest runtime_recipes must be a list")
    for recipe in recipes:
        for key in ("id", "kind", "source", "author", "license", "local_path"):
            if not isinstance(recipe.get(key), str) or not recipe[key].strip():
                raise ValueError(f"runtime recipe requires nonempty {key}")
        if recipe["id"] in seen:
            raise ValueError(f"duplicate asset/recipe id: {recipe['id']}")
        seen.add(recipe["id"])
        local_target(root, recipe["local_path"], root=root)
        if "sha256" in recipe:
            digest = recipe["sha256"]
            if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise ValueError(f"runtime recipe {recipe['id']} requires a lowercase SHA-256")
            if hashlib.sha256((root / recipe["local_path"]).read_bytes()).hexdigest() != digest:
                raise ValueError(f"runtime recipe hash mismatch: {recipe['local_path']}")

    authored = {str(path.relative_to(root)) for directory in ASSET_ROOTS
                for path in (root / "assets" / directory).rglob("*")
                if path.is_file() and path.suffix != ".md"}
    for value in authored:
        path = Path(value)
        if "__pycache__" in path.parts or re.search(r"\.blend\d+$", path.name) or path.suffix in {".pyc", ".tmp"}:
            raise ValueError(f"generated cache/backup in authored assets: {value}")
    recorded = {asset["local_path"] for asset in manifest["assets"] if asset["local_path"]}
    if authored != recorded:
        raise ValueError(f"asset manifest coverage mismatch: {authored ^ recorded}")


def main() -> int:
    """Report all discovered file-level failures and return a CI-friendly status."""
    errors: list[str] = []
    markdown_files = source_files(".md")
    json_files = source_files(".json")
    for path in markdown_files:
        for match in LINK.finditer(path.read_text(encoding="utf-8")):
            reference = match.group(1).strip().strip("<>")
            parsed = urlsplit(reference)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            try:
                local_target(path.parent, parsed.path)
            except ValueError as error:
                errors.append(f"{path.relative_to(ROOT)}: {error}")
    for path in json_files:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            if path.name.endswith(".project.json"):
                check_project_paths(value, path.parent)
            if path == ROOT / "assets/manifest.json":
                check_manifest(value)
        except (ValueError, TypeError, AttributeError) as error:
            errors.append(f"{path.relative_to(ROOT)}: {error}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Repository checks passed: {len(markdown_files)} Markdown files, {len(json_files)} JSON files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
