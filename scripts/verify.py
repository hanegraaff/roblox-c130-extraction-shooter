"""Run the current scaffold gate and build both Rojo place mappings.

Plan 01 expands this entrypoint with static analysis and executable Luau tests.
Missing tools and failed commands always fail the gate; no checks are skipped.
"""

from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    """Validate repository inputs and build with the exact pinned Rojo version."""
    subprocess.run([sys.executable, "scripts/check_repository.py"], cwd=ROOT, check=True)
    rojo = shutil.which("rojo")
    if rojo is None:
        raise RuntimeError("Rojo is missing. Install Rokit, then run 'rokit install'.")
    pin_match = re.search(r'rojo-rbx/rojo@([\d.]+)', (ROOT / "rokit.toml").read_text())
    if pin_match is None:
        raise RuntimeError("rokit.toml must contain an exact Rojo version pin.")
    pin = pin_match.group(1)
    version = subprocess.run([rojo, "--version"], check=True, text=True, capture_output=True).stdout.strip()
    if version != f"Rojo {pin}":
        raise RuntimeError(f"Expected Rojo {pin}; found {version}. Run 'rokit install'.")
    (ROOT / "build").mkdir(exist_ok=True)
    for project, artifact in (("default.project.json", "game"), ("test.project.json", "tests")):
        subprocess.run([rojo, "build", project, "--output", f"build/{artifact}.rbxlx"], cwd=ROOT, check=True)
    print("Scaffold gate passed. Gameplay tests are introduced in Plan 01; none ran here.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Verification failed: {error}", file=sys.stderr)
        sys.exit(1)
