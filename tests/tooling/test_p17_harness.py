"""P17 test-source provenance and release-isolation rejection checks.

These host tests prove the fixture boundary, not weapon hits, replication,
preload availability, native geometry or rendering. Those require actual clients.
"""
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


HARNESS = module("p17_harness")
BUILD = module("inspect_build")


class P17HarnessBoundaryTests(unittest.TestCase):
    def test_actual_manual_dispatch_starts_one_listener_and_ordinary_path_stays_intact(self):
        # Execute the actual narrow entrypoint blocks under Luau, replacing only
        # services/module start callbacks. This proves dispatch, not engine IO.
        client = (ROOT / "tests/studio/client/init.client.luau").read_text()
        client = client[client.index("-- One trusted server string"):client.index("local stopTestPanel")]
        server = (ROOT / "tests/studio/server/init.server.luau").read_text()
        server = server[server.index("-- Publish a single trusted selection"):server.index("-- Vendor TestEZ")]
        preflight = (ROOT / "tests/studio/server/P17ManualRunner.luau").read_text()
        preflight = preflight.split("function Runner.run()\n", 1)[1].split("    local invocation =", 1)[0]
        program = '''local client = assert(loadstring([====[return function(ReplicatedStorage, script, require, task)
CLIENT_BLOCK
end]====]))()
local server = assert(loadstring([====[return function(ServerStorage, ReplicatedStorage, game)
SERVER_BLOCK
end]====]))()
local expected = {P08="LauncherHarness",P17="P17MaterialHarness",P07="DestructionHarness",P05="CombatHarness",P14="AircraftPanHarness"}
local function published(mode, studio)
    local value = nil
    server({FindFirstChild=function() return {IsA=function() return true end,GetAttribute=function() return mode end} end},
        {SetAttribute=function(_,name,nextValue) assert(name=="ManualClientHarness") value=nextValue end},
        {GetService=function(_,name) assert(name=="RunService") return {IsStudio=function() return studio end} end})
    return value
end
local function started(mode)
    local calls={}
    client({GetAttribute=function(_,name) assert(name=="ManualClientHarness") return mode end},
        setmetatable({}, {__index=function(_,name) return name end}),
        function(name) return {run=function() table.insert(calls,name) end} end,
        {wait=function() error("published mode must not wait") end})
    return calls
end
for mode,name in expected do
    assert(published(mode,true)==mode,"trusted mode publication failed")
    local calls=started(mode)
    assert(#calls==1 and calls[1]==name,"manual mode also started another waiter: "..mode)
    assert(published(mode,false)=="","non-Studio selected a manual mode")
end
assert(published(nil,true)=="" and published("unknown",true)=="","ordinary selection changed")
local ordinary=started("")
local prior={"CombatHarness","DestructionHarness","GroundCombatHarness","LauncherHarness","RoundHarness","AircraftHarness","AircraftPanHarness","ExpandedMapHarness"}
assert(#ordinary==#prior,"ordinary listener population changed")
for i,name in prior do assert(ordinary[i]==name,"ordinary listener ordering changed") end
print("PASS actual Luau manual/ordinary dispatch control flow")
local preflight = assert(loadstring([====[return function(RunService, game, ServerStorage, ReplicatedStorage, Players, HttpService, workspace, Metadata, Instance)
PREFLIGHT_BLOCK
end]====]))()
local function attempt(actualCount, baselineCount, area, blockedName)
    local function lookup(owner,name)
        if owner==area and name==blockedName then return {} end
        return nil
    end
    local settings={IsA=function() return true end,GetAttribute=function(_,name)
        return if name=="ManualHarness" then "P17" else string.rep("a",40)
    end}
    return pcall(preflight,
        {IsStudio=function() return true end}, {PlaceId=0,GameId=0},
        {FindFirstChild=function(_,name) return if name=="DevelopmentSettings" then settings else lookup("server",name) end},
        {FindFirstChild=function(_,name) return lookup("replicated",name) end},
        {GetPlayers=function() return table.create(actualCount,true) end},
        {JSONDecode=function() return {discovered=173,passed=173,failed=0,errors=0,skipped=0,clientCount=baselineCount} end},
        {GetAttribute=function() return "baseline" end,FindFirstChild=function(_,name) return lookup("world",name) end,
            SetAttribute=function() error("preflight mutated status") end},
        {expectedServerSmoke=173}, {new=function() error("preflight allocated resource") end})
end
-- A valid positive control must finish with no status writes/allocations.
assert(attempt(2,2),"valid retained-session preflight rejected")
for _,counts in {{3,2},{2,3},{1,2},{2,1}} do
    local ok,why=attempt(counts[1],counts[2])
    assert(not ok and string.find(tostring(why),"fresh two%-client server baseline"),"stale/wrong roster not rejected")
end
for area,names in {
    replicated={"RoundState","AircraftState","LauncherState","StudioTestControls","P17ManualHarness","P17PerformanceTransport"},
    world={"Aircraft","CombatEffects","GroundCombatEffects","PanelFragments"},
    server={"LocalTestControls","P17UserPreviewStop"},
} do
    for _,name in names do
        local ok,why=attempt(2,2,area,name)
        assert(not ok and string.find(tostring(why),"active "),"competing owner not rejected: "..name)
    end
end
print("PASS actual Luau runner preflight rejects stale roster/owners without resources")
'''.replace("CLIENT_BLOCK", client).replace("SERVER_BLOCK", server).replace("PREFLIGHT_BLOCK", preflight)
        executable = shutil.which("lune") or str(Path.home() / ".rokit/bin/lune")
        with tempfile.TemporaryDirectory(prefix="p17-dispatch-") as directory:
            path = Path(directory) / "probe.luau"
            path.write_text(program)
            result = subprocess.run([executable, "run", str(path)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("PASS actual Luau manual/ordinary dispatch", result.stdout)

    def test_frozen_v7_bodies_accept_then_reject_changed_gameplay(self):
        with tempfile.TemporaryDirectory(prefix="p17-body-") as directory:
            for relative, expected in HARNESS.FROZEN_BODIES.items():
                source = ROOT / relative
                HARNESS.check_frozen_body(source, expected)
                altered = Path(directory) / source.name
                body = source.read_bytes()
                self.assertTrue(b"AssetMesh.validate" in body, "native constructor guard missing")
                altered.write_bytes(body.replace(b"AssetMesh.validate", b"AssetMesh.invalid", 1))
                with self.assertRaisesRegex(ValueError, "frozen v7 gameplay body differs"):
                    HARNESS.check_frozen_body(altered, expected)

    def test_bound_runtime_native_bank_and_fixture_drift_reject(self):
        with tempfile.TemporaryDirectory(prefix="p17-inputs-") as directory:
            root = Path(directory)
            names = ("src/server/owner.luau", "assets/imports/native.rbxm", "tests/studio/probe.luau")
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"original bound bytes")
            expected = {name: HARNESS.digest((root / name).read_bytes()) for name in names}
            HARNESS.check_inputs(root, expected, dict(expected))
            for name in names:
                path = root / name
                path.write_bytes(b"changed bytes")
                changed = {entry: HARNESS.digest((root / entry).read_bytes()) for entry in names}
                with self.assertRaisesRegex(ValueError, "source fingerprint differs: " + name):
                    HARNESS.check_inputs(root, expected, changed)
                path.write_bytes(b"original bound bytes")
            for changed in ({key: value for key, value in expected.items() if key != names[0]},
                            dict(expected, unexpected="f" * 64)):
                with self.assertRaisesRegex(ValueError, "source input coverage differs"):
                    HARNESS.check_inputs(root, expected, changed)

    def test_p17_artifact_isolation_positive_and_each_missing_leaked_module(self):
        valid = {name: "ModuleScript" for name in BUILD.MANUAL_P17_TEST_ONLY}
        BUILD.check_manual_p17_isolation({}, valid)
        for name in valid:
            missing = dict(valid)
            del missing[name]
            with self.assertRaisesRegex(RuntimeError, "P17 fixture missing from tests or leaked"):
                BUILD.check_manual_p17_isolation({}, missing)
            with self.assertRaisesRegex(RuntimeError, "P17 fixture missing from tests or leaked"):
                BUILD.check_manual_p17_isolation({name: "ModuleScript"}, valid)


if __name__ == "__main__":
    unittest.main()
