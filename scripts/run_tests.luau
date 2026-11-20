--!strict
-- Standalone deterministic test runner. Each required suite must discover cases; errors/empty suites exit 1.
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local suite = process.args[1] or "all"
local passed, failed, discovered = 0, 0, 0
local function test(name: string, callback: () -> ())
    discovered += 1
    local ok, reason = pcall(function()
        callback()
        return true
    end)
    if ok then
        passed += 1
        print("PASS " .. name)
    else
        failed += 1
        print("FAIL " .. name .. ": " .. tostring(reason))
    end
end
do
    for _, category in { "unit", "integration" } do
        if suite == "all" or suite == category then
            local before = discovered
            local files = fs.readDir("tests/" .. category)
            table.sort(files)
            for _, name in files do
                if string.match(name, "%.spec%.luau$") then
                    local moduleName = string.gsub(name, "%.spec%.luau$", "")
                    -- Runtime discovery boundary; discovered first-party modules are separately typechecked.
                    local loadModule = (require :: unknown) :: (string) -> unknown
                    local cases = (
                        loadModule(
                            "../tests/" .. category .. "/" .. string.gsub(name, "%.luau$", "")
                        ) :: unknown
                    ) :: ((string, () -> ()) -> (), unknown) -> ()
                    local serverModules = {
                        PanelDamageRules = true,
                        PanelAssetRules = true,
                        DestructionService = true,
                        RoleService = true,
                        RoundRules = true,
                        MatchService = true,
                        AircraftSelection = true,
                        CombatService = true,
                        CombatViewRules = true,
                        DamageRules = true,
                        AircraftHealth = true,
                        GroundCombatService = true,
                        LauncherService = true,
                        GroundMovementGuard = true,
                    }
                    local area = if serverModules[moduleName] then "server" else "shared"
                    local rules = loadModule("../src/" .. area .. "/" .. moduleName)
                    cases(test, rules)
                end
            end
            if discovered == before then
                error("empty required suite: " .. category)
            end
        end
    end
end
local report = { suite = suite, discovered = discovered, passed = passed, failed = failed, skipped = 0 }
print(serde.encode("json", report))
if discovered == 0 or failed > 0 then
    process.exit(1)
end
