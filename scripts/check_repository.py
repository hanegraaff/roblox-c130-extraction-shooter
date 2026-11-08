"""Check local documentation links, project mappings, and asset provenance shape.

Uses only Python's standard library. This checks a source scaffold, not gameplay,
remote URLs, or Markdown heading anchors. Run from any directory; paths resolve
relative to the repository containing this script.
"""

from __future__ import annotations

import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
IGNORED = {".git", ".tools", "build", "artifacts", "Packages", "ServerPackages", "__pycache__"}
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def source_files(suffix: str) -> list[Path]:
    """Return authored files of one suffix, excluding generated directories."""
    return sorted(
        path for path in ROOT.rglob(f"*{suffix}")
        if not IGNORED.intersection(path.relative_to(ROOT).parts)
    )


def local_target(base: Path, value: str) -> Path:
    """Resolve a local reference and reject paths outside this repository."""
    target = (base / unquote(value)).resolve()
    if not target.is_relative_to(ROOT):
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


def check_manifest(manifest: dict) -> None:
    """Validate asset identities and references; do not guess licensing rights."""
    if manifest.get("schema_version") != 1 or not isinstance(manifest.get("assets"), list):
        raise ValueError("manifest requires schema_version 1 and an assets list")
    seen: set[str] = set()
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
            local_target(ROOT, asset["local_path"])
        if asset["roblox_asset_id"] and not asset["roblox_asset_id"].isdigit():
            raise ValueError(f"asset {asset['id']} has a nonnumeric Roblox ID")

    authored = {str(path.relative_to(ROOT)) for directory in ("world", "models")
                for path in (ROOT / "assets" / directory).rglob("*")
                if path.is_file() and path.suffix != ".md"}
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
