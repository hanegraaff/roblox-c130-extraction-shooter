"""Execute actual fixture version guards and preserve source-bound P17 history."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / f"scripts/{name}.py")
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class HarnessCompatibilityTests(unittest.TestCase):
    def test_actual_version_api_rejects_every_archived_kind_before_mutation(self):
        source = (ROOT / "tests/studio/support/HarnessCompatibility.luau").read_text()
        program = '''local compatibility = assert(loadstring([====[SOURCE]====]))()
for _,kind in {"P06","P06Team","P07","Sandbreak","P08","P09","P10","P11","P14","P14ArrivalRegression","P17"} do
    local why=compatibility.reason(kind)
    assert(type(why)=="string" and why:find("historical pre%-P18") and why:find("P18 three%-client") and why:find("P05 two%-client actual%-fire")
        and why:find("ordinary Studio smoke"),"missing replacement guidance")
    local mutated=false
    local ok,problem=pcall(function()compatibility.assertCurrent(kind);mutated=true end)
    assert(not ok and not mutated and tostring(problem):find("historical pre%-P18"),"archived fixture acquired resources")
end
for _,kind in {"P18","P03","P04","P05","P13","HumanTestControls","HumanTestMultiplayer",""} do
    assert(compatibility.reason(kind)==nil,"current fixture incorrectly blocked")
    compatibility.assertCurrent(kind)
end
print("PASS actual current/historical fixture API")
'''.replace("SOURCE", source)
        executable = shutil.which("lune") or str(Path.home() / ".rokit/bin/lune")
        with tempfile.TemporaryDirectory(prefix="p18-compatibility-") as directory:
            path = Path(directory) / "probe.luau"
            path.write_text(program)
            result = subprocess.run([executable, "run", str(path)], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS actual current/historical", result.stdout)

    def test_direct_legacy_entries_guard_before_allocating_and_frozen_p17_bodies_are_identical(self):
        entries = {"GroundCombatHarness":"P06", "DestructionHarness":"P07", "LauncherHarness":"P08",
                   "MatchOutcomeHarness":"P09", "PlayerExperienceHarness":"P10",
                   "PerformanceHarness":"P11", "AircraftPanHarness":"P14"}
        for side in ("server", "client"):
            for name, kind in entries.items():
                contents = (ROOT / f"tests/studio/{side}/{name}.luau").read_text()
                body = contents.split("function ", 1)[-1]
                # Find the exported start rather than private wait helpers.
                marker = f'assertCurrent("{kind}")'
                self.assertIn(marker, body)
                after_run = contents.split("function Harness.run(", 1)[1].split("\n", 1)[1]
                self.assertTrue(after_run.lstrip().startswith('require(game:GetService("ReplicatedStorage").HarnessCompatibility)'), name)
        harness = module("p17_harness")
        for name, digest in harness.FROZEN_BODIES.items():
            contents = (ROOT / name).read_text()
            self.assertLess(contents.index('assertCurrent("P17")'), contents.index("local Players ="))
            harness.check_frozen_body(ROOT / name, digest)

    def test_current_p18_transport_and_compatibility_module_cannot_be_missing_or_leaked(self):
        build = module("inspect_build")
        fixtures = {name: "ModuleScript" for name in build.P18_TEST_ONLY}
        build.check_p18_isolation({}, fixtures)
        for name in fixtures:
            missing = dict(fixtures)
            del missing[name]
            with self.assertRaisesRegex(RuntimeError, "P18 fixture missing"):
                build.check_p18_isolation({}, missing)
            with self.assertRaisesRegex(RuntimeError, "P18 fixture missing"):
                build.check_p18_isolation({name: "ModuleScript"}, fixtures)
