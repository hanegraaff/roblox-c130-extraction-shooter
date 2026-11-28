--!strict
-- P30 A1 deterministic healing rules and one ledger per deployment.
type API = typeof(require(game:GetService("ServerScriptService").Server.MedkitService))

return function(test: (string, () -> ()) -> (), candidate: unknown)
    local medkit = candidate :: API
    local alive = { connected = true, role = "Ground", life = "Alive" }
    local function attempt()
        return {
            roundId = 1,
            siteId = "Bunker",
            member = alive :: typeof(alive)?,
            withinReach = true,
            clearSight = true,
            health = 50,
            maxHealth = 100,
        }
    end
    local function active(roundId: number): { roundId: number, phase: "Active", deadlineSeconds: number }
        return { roundId = roundId, phase = "Active", deadlineSeconds = 90 }
    end
    test(
        "P30 A1 partial and capped heals use the deployed amount and reset each site independently",
        function()
            local round = active(1)
            local request = attempt()
            local kit = medkit.new(1, 25, { "Bunker", "Hangar" })
            assert(
                kit.use(round, 3, request) == 75 and not kit.available("Bunker"),
                "partial heal did not spend the bunker kit"
            )
            request.siteId, request.health = "Hangar", 91
            assert(
                kit.use(round, 4, request) == 100 and not kit.available("Hangar"),
                "cap did not spend the independent hangar kit"
            )
            local next = medkit.new(2, 42, { "Bunker", "Hangar" })
            assert(
                next.available("Bunker") and next.available("Hangar"),
                "replay failed to restore both sites"
            )
            request.siteId, request.health = "Bunker", 20
            assert(next.use(active(2), 11, request) == nil, "old round request survived reset")
            request.roundId = 2
            assert(next.use(active(2), 11, request) == 62, "replay did not use the new healing amount")
        end
    )
    test("P30 A1 full/dead/invalid health and obstructed or distant uses leave the kit available", function()
        local kit = medkit.new(1, 25, { "Bunker" })
        local request = attempt()
        local round = active(1)
        for _, hp in { 100, 120, 0, -1, 0 / 0, math.huge } do
            request.health = hp
            assert(
                kit.use(round, 3, request) == nil and kit.available("Bunker"),
                "invalid current health used the kit"
            )
        end
        request.health = 50
        for _, maxHealth in { 0, 0 / 0, math.huge } do
            request.maxHealth = maxHealth
            assert(
                kit.use(round, 3, request) == nil and kit.available("Bunker"),
                "invalid maximum health used the kit"
            )
        end
        request.maxHealth, request.withinReach = 100, false
        assert(kit.use(round, 3, request) == nil and kit.available("Bunker"), "distant request used the kit")
        request.withinReach, request.clearSight = true, false
        assert(
            kit.use(round, 3, request) == nil and kit.available("Bunker"),
            "obstructed request used the kit"
        )
        request.clearSight, request.siteId = true, "Other"
        assert(
            kit.use(round, 3, request) == nil and kit.available("Bunker"),
            "unknown site changed the kit ledger"
        )
    end)
    test(
        "P30 A1 denies an absent, dead, departed, spectator or operator life and committed/deadline use",
        function()
            local request = attempt()
            local kit = medkit.new(1, 25, { "Bunker" })
            local round = active(1)
            request.member = nil
            assert(kit.use(round, 3, request) == nil, "unassigned actor used the kit")
            for _, member in
                {
                    { connected = true, role = "Ground", life = "Eliminated" },
                    { connected = false, role = "Ground", life = "Alive" },
                    { connected = true, role = "Spectator", life = "Spectating" },
                    { connected = true, role = "Gunship", life = "Alive" },
                }
            do
                request.member = member
                assert(
                    kit.use(round, 3, request) == nil and kit.available("Bunker"),
                    "ineligible participant used the kit"
                )
            end
            request.member = alive
            assert(
                kit.use(round, 90, request) == nil and kit.available("Bunker"),
                "deadline use spent the kit"
            )
            assert(
                kit.use({ roundId = 1, phase = "Results", deadlineSeconds = 90 }, 89, request) == nil,
                "terminal request used the kit"
            )
            assert(
                kit.use({ roundId = 1, phase = "Deploying", deadlineSeconds = 0 }, 0, request) == nil,
                "deployment request used the kit"
            )
            assert(kit.use(round, 89.999, request) == 75, "pre-deadline use was denied")
        end
    )
    test(
        "P30 A1 one contender heals during Scatter and elapsed legacy interval never restores the kit",
        function()
            local kit = medkit.new(1, 25, { "Bunker", "Hangar" })
            local one, two = attempt(), attempt()
            two.health, two.member = 60, table.clone(alive)
            local scatter = { roundId = 1, phase = "Scatter" :: "Scatter", deadlineSeconds = 2 }
            assert(kit.use(scatter, 1, one) == 75, "first contender was denied in Scatter")
            assert(
                kit.use(scatter, 1, two) == nil and kit.available("Hangar"),
                "second contender healed or spent another site"
            )
            assert(kit.use(active(1), 32, two) == nil, "legacy timeout restored the kit")
            assert(
                kit.use(active(1), 89, two) == nil and not kit.available("Bunker"),
                "consumed kit returned before round reset"
            )
        end
    )
end
