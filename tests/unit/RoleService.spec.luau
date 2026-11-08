--!strict
-- P03 A1/R02: population boundaries and deterministic fair assignment of actual rules.
type API = typeof(require(game:GetService("ServerScriptService").Server.RoleService))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Roles = candidate :: API
    local function roster(count: number): { { userId: number, waitedRounds: number } }
        local values: { { userId: number, waitedRounds: number } } = {}
        for id = 1, count do
            table.insert(values, { userId = id, waitedRounds = 0 })
        end
        return values
    end
    test("production rosters reject five and eleven players without mutation", function()
        for _, count in { 5, 11 } do
            local values = roster(count)
            assert(not Roles.assign(values, 6, nil, 1), "expected not Roles.assign(values, 6, nil, 1)")
            assert(
                #values == count and values[1].waitedRounds == 0,
                "expected #values == count and values[1].waitedRounds == 0"
            )
        end
    end)
    test("six and ten players receive exactly one operator and one united ground roster", function()
        for _, count in { 6, 10 } do
            local assignment = Roles.assign(roster(count), 6, nil, 1)
            assert(
                assignment and #assignment.groundIds == count - 1,
                "expected assignment and #assignment.groundIds == count - 1"
            )
            local seen: { [number]: boolean } = { [assignment.operatorId] = true }
            for _, id in assignment.groundIds do
                assert(not seen[id], "expected not seen[id]")
                seen[id] = true
            end
        end
    end)
    test("seeded ties are repeatable independent of incoming join order", function()
        local first = Roles.assign(roster(6), 6, nil, 19)
        local reversed = roster(6)
        table.sort(reversed, function(a, b)
            return a.userId > b.userId
        end)
        local second = Roles.assign(reversed, 6, nil, 19)
        assert(
            first and second and first.operatorId == second.operatorId,
            "expected first and second and first.operatorId == second.operatorId"
        )
    end)
    test("longest waiting alternative gets operator without repeating previous operator", function()
        local values = roster(6)
        values[1].waitedRounds = 20
        values[3].waitedRounds = 19
        local assignment = Roles.assign(values, 6, 1, 42)
        assert(
            assignment and assignment.operatorId == 3,
            "expected assignment and assignment.operatorId == 3"
        )
    end)
    test("two and three player server fixtures are supported and duplicate ids reject", function()
        for _, count in { 2, 3 } do
            local assignment = Roles.assign(roster(count), 2, nil, 1)
            assert(
                assignment and #assignment.groundIds == count - 1,
                "expected assignment and #assignment.groundIds == count - 1"
            )
        end
        local values = roster(6)
        values[2].userId = values[1].userId
        assert(not Roles.assign(values, 6, nil, 1), "expected not Roles.assign(values, 6, nil, 1)")
    end)
end
