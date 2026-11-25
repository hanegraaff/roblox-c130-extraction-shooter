"""Launch a local place once on macOS, only when Roblox Studio is fully closed.

Existing documents are updated with Rojo and operated through their MCP studio_id.
This helper never opens another process to refresh an existing document, closes an
application, changes Studio settings, or publishes a place. Launch logs are ignored
build artifacts. Run from any directory; relative place paths use the current one.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent


def studio_processes() -> list[int]:
    """Read exact-name Studio PIDs; fail closed on an unexpected process-query error."""
    result = subprocess.run(["/usr/bin/pgrep", "-x", "RobloxStudio"], capture_output=True, text=True)
    if result.returncode == 1:
        return []
    if result.returncode != 0:
        raise RuntimeError("Cannot determine whether Studio is running; no launch attempted")
    observed = [int(value) for value in result.stdout.split()]
    if not observed or any(pid <= 0 for pid in observed):
        raise RuntimeError("Invalid Studio process result; no launch attempted")
    return observed


def launch(place: Path) -> int:
    """Start one documented EditFile launch, or return 2 without launching if occupied."""
    if sys.platform != "darwin":
        raise RuntimeError("This launch helper supports macOS only")
    import fcntl
    place = place.resolve(strict=True)
    if not place.is_file() or place.suffix.lower() not in {".rbxl", ".rbxlx"}:
        raise RuntimeError("Choose an existing .rbxl or .rbxlx place file")
    applications = (Path("/Applications/RobloxStudio.app"), Path.home() / "Applications/RobloxStudio.app")
    executable = next((app / "Contents/MacOS/RobloxStudio" for app in applications
                       if (app / "Contents/MacOS/RobloxStudio").is_file()), None)
    if executable is None:
        raise RuntimeError("Roblox Studio is not installed in a supported Applications directory")
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    # Concurrent agents must not both observe an empty process list and launch.
    with (build / ".studio-launch.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("Another Studio launch is in progress; no launch attempted", file=sys.stderr)
            return 2
        existing = studio_processes()
        if existing:
            print(f"Studio is already running (PIDs {existing}); no launch attempted. "
                  "Reuse its MCP studio_id and Rojo sync.", file=sys.stderr)
            return 2
        log_path = build / "studio-launch.log"
        with log_path.open("ab") as log:
            process = subprocess.Popen(
                [str(executable), "--task", "EditFile", "--localPlaceFile", str(place)],
                stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            observed = studio_processes()
            if observed:
                if len(observed) != 1:
                    raise RuntimeError(f"Launch observed multiple Studio PIDs {observed}; do not retry")
                print(f"Launched {place.name}; Studio PID {observed[0]}. "
                      "Confirm the document through MCP before operating it.")
                print(f"Launch log: {log_path}")
                return 0
            if process.poll() is not None:
                raise RuntimeError(f"Studio exited during launch; inspect {log_path}; do not retry automatically")
            time.sleep(0.1)
        raise RuntimeError(f"Launch was issued but Studio is not observable; inspect {log_path}; do not retry")


def main() -> int:
    """Validate a local place argument; report a bounded failure without a fallback launch."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", type=Path, help="Local .rbxl or .rbxlx file")
    arguments = parser.parse_args()
    try:
        return launch(arguments.place)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Studio launch refused or failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
