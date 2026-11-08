"""Full non-Studio foundation gate. Every required tool/suite must execute successfully.

Run setup.py first on a clean clone. Studio server/client evidence remains a separate
gate: this script never substitutes standalone execution for engine behavior.
"""
from pathlib import Path
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

from setup import DEFINITIONS_SHA256

ROOT = Path(__file__).resolve().parent.parent
ENVIRONMENT = dict(os.environ, PATH=str(Path.home() / ".rokit/bin") + os.pathsep + os.environ.get("PATH", ""))


def run(arguments: list[str], *, cwd: Path = ROOT, expected_failure: bool = False, required_output: str | None = None) -> subprocess.CompletedProcess:
    """Run a named gate and enforce success, or an intentionally nonzero probe."""
    print("+ " + " ".join(arguments), flush=True)
    result = subprocess.run(arguments, cwd=cwd, env=ENVIRONMENT, text=True, capture_output=expected_failure)
    if expected_failure:
        output = result.stdout + result.stderr
        print(output, end="", flush=True)
        if required_output and required_output not in output:
            raise RuntimeError(f"Probe did not reach intended failure: {required_output}")
    if expected_failure:
        if result.returncode == 0:
            raise RuntimeError("Expected a nonzero exit from disposable rejection probe")
        print(f"Expected rejection observed: exit {result.returncode}", flush=True)
    else:
        result.check_returncode()
    return result


def analysis_arguments() -> list[str]:
    """Use actual pinned engine definitions and the complete test mapping."""
    return ["luau-lsp", "analyze", "--platform=roblox", "--sourcemap=build/sourcemap.json", "--definitions=@roblox=.tools/globalTypes.d.luau"]


def negative_probes() -> None:
    """Prove failures and zero discovery fail the same runner in disposable source copies."""
    with tempfile.TemporaryDirectory(prefix="c130-gate-") as directory:
        fixture = Path(directory)
        for name in ("src", "tests", "scripts"):
            shutil.copytree(ROOT / name, fixture / name)
        shutil.copy2(ROOT / "rokit.toml", fixture / "rokit.toml")
        target = fixture / "tests/unit/Validation.spec.luau"
        target.write_text('--!strict\nreturn function(test) test("injected failing fixture", function() error("deliberate failure") end) end\n')
        run(["lune", "run", "scripts/run_tests.luau", "unit"], cwd=fixture, expected_failure=True, required_output="deliberate failure")
        shutil.rmtree(fixture / "tests/unit")
        (fixture / "tests/unit").mkdir()
        run(["lune", "run", "scripts/run_tests.luau", "unit"], cwd=fixture, expected_failure=True, required_output="empty required suite: unit")
    probe = ROOT / "build/StrictTypeProbe.luau"
    try:
        probe.write_text('--!strict\nlocal part: Part = Instance.new("Part")\npart.Anchored = "invalid boolean"\nlocal seconds: number = "invalid number"\nprint(seconds)\n')
        run(analysis_arguments() + [str(probe)], expected_failure=True, required_output="Expected this to be 'boolean'")
    finally:
        probe.unlink(missing_ok=True)


def main() -> int:
    """Run repository, pinned-tool, format/lint/type, unit/service, probes and build gates."""
    run([sys.executable, "scripts/check_repository.py"])
    # Refuse accidental upgrades or tool substitutions; Rokit pins are the source of truth.
    for name, pin in re.findall(r'([\w-]+)\s*=\s*"[^"@]+@([\d.]+)"', (ROOT / "rokit.toml").read_text()):
        executable = shutil.which(name, path=ENVIRONMENT["PATH"])
        if executable is None:
            raise RuntimeError(f"Missing {name}; run python3 scripts/setup.py")
        version = subprocess.check_output([executable, "--version"], cwd=ROOT, env=ENVIRONMENT, text=True).strip()
        if not re.search(r"(?<![\d.])" + re.escape(pin) + r"(?![\d.])", version):
            raise RuntimeError(f"Expected {name} {pin}; found {version}")
        print(version, flush=True)
    definitions = ROOT / ".tools/globalTypes.d.luau"
    if not definitions.exists() or hashlib.sha256(definitions.read_bytes()).hexdigest() != DEFINITIONS_SHA256:
        raise RuntimeError("Missing/changed pinned Roblox definitions; run python3 scripts/setup.py")
    if not (ROOT / "Packages/TestEZ.lua").exists():
        raise RuntimeError("Missing Wally dependencies; run python3 scripts/setup.py")
    (ROOT / "build").mkdir(exist_ok=True)
    run(["stylua", "--check", "src", "tests", "scripts/run_tests.luau"])
    run(["selene", "src", "tests", "scripts/run_tests.luau"])
    run(["rojo", "sourcemap", "test.project.json", "--output", "build/sourcemap.json"])
    run(analysis_arguments() + ["src", "tests", "scripts/run_tests.luau"])
    for suite in ("unit", "integration"):
        run(["lune", "run", "scripts/run_tests.luau", suite])
    negative_probes()
    for project, artifact in (("default.project.json", "game"), ("test.project.json", "tests")):
        run(["rojo", "build", project, "--output", f"build/{artifact}.rbxlx"])
    run([sys.executable, "scripts/inspect_build.py"])
    print("All non-Studio gates passed. Studio server/client smoke and visual review require separate evidence.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"Verification failed: {error}", file=sys.stderr)
        sys.exit(1)
