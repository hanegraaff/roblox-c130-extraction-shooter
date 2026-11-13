--!strict
-- P07 A1/A2/A6: real pure orchestration ledger, accepted shot identity/firedAt,
-- ordered completion, rejection and generation cleanup. Engine queries are separate.
type API = typeof(require(game:GetService("ServerScriptService").Server.DestructionService))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Service = candidate :: API
    local function fixture()
        local owner = Service.new()
        owner.reset(1, { "wall", "roof" })
        owner.changed()
        return owner
    end
    local function shot(
        owner: typeof(Service.new()),
        id: number,
        time: number,
        panel: string?,
        weapon: string?
    )
        assert(
            owner.resolve({
                roundId = 1,
                shotId = id,
                firedAt = time,
                panelId = panel,
                weapon = weapon or "GAU23",
            }),
            'Expected owner.resolve({ roundId = 1, shotId = id, firedAt = time, panelId = panel, weapon = weapon or "GAU23", })'
        )
    end
    test(
        "SustainedPanelFire first hit earns zero and exact cadence reaches nine then eighteen seconds",
        function()
            local owner = fixture()
            shot(owner, 1, 100, "wall")
            assert(
                assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")').progress == 0,
                "pre-first-hit credit"
            )
            for id = 2, 60 do
                shot(owner, id, 100 + (id - 1) * 0.15, "wall")
            end
            assert(
                assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")').stage == 0,
                "before nine seconds"
            )
            shot(owner, 61, 109, "wall")
            assert(
                assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")').stage == 1,
                "exact nine seconds"
            )
            for id = 62, 120 do
                shot(owner, id, 100 + (id - 1) * 0.15, "wall")
            end
            assert(
                assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")').stage == 1,
                "before second nine seconds"
            )
            shot(owner, 121, 118, "wall")
            assert(assert(owner.snapshot("wall"), "wall missing").stage == 2, "destroyed state regressed")
        end
    )
    test("SustainedPanelFire cadence gap boundary tolerates spacing and resets above it", function()
        for _, gap in { 0.225, 0.22501 } do
            local owner = fixture()
            shot(owner, 1, 0, "wall")
            shot(owner, 2, 0.15, "wall")
            shot(owner, 3, 0.15 + gap, "wall")
            local state = assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")')
            assert(
                math.abs(state.sustainedSeconds - (if gap == 0.225 then 0.375 else 0)) < 1e-8,
                "gap policy"
            )
        end
    end)
    test(
        "SustainedPanelFire misses blocked targets switches reload and operator loss clear only uncommitted work",
        function()
            for _, interruption in { "miss", "target", "switch", "reload", "disconnect" } do
                local owner = fixture()
                shot(owner, 1, 0, "wall", "M102")
                shot(owner, 2, 1, "wall")
                shot(owner, 3, 1.15, "wall")
                if interruption == "miss" then
                    shot(owner, 4, 1.3, nil)
                elseif interruption == "target" then
                    shot(owner, 4, 1.3, "roof")
                elseif interruption == "switch" then
                    shot(owner, 4, 1.3, "roof", "M102")
                elseif interruption == "reload" then
                    shot(owner, 4, 7, "wall")
                else
                    owner.interrupt()
                end
                local state = assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")')
                assert(
                    state.heavySeconds == 3 and state.sustainedSeconds == 0 and state.stage == 0,
                    interruption
                )
            end
        end
    )
    test(
        "SustainedPanelFire rejected malformed stale duplicate and unknown-panel outcomes do not mutate",
        function()
            local owner = fixture()
            shot(owner, 1, 0, "wall")
            shot(owner, 2, 0.15, "wall")
            local before = assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")').sustainedSeconds
            local invalid = {
                { roundId = 0, shotId = 3, firedAt = 0.3, weapon = "GAU23", panelId = "wall" },
                { roundId = 1, shotId = 2, firedAt = 0.3, weapon = "GAU23", panelId = "wall" },
                { roundId = 1, shotId = 3, firedAt = 0 / 0, weapon = "GAU23", panelId = "wall" },
                { roundId = 1, shotId = 3, firedAt = 0.3, weapon = "M7", panelId = "wall" },
                { roundId = 1, shotId = 3, firedAt = 0.3, weapon = "GAU23", panelId = "static" },
                { roundId = 1, shotId = 10000, firedAt = 0.3, weapon = "GAU23", panelId = "wall" },
            }
            for _, value in invalid do
                assert(not owner.resolve(value), "Expected not owner.resolve(value)")
                assert(
                    assert(owner.snapshot("wall"), "wall missing").sustainedSeconds == before,
                    "rejection changed progress"
                )
            end
            assert(
                owner.resources().pending == 0 and owner.snapshot("static") == nil,
                'Expected owner.resources().pending == 0 and owner.snapshot("static") == nil'
            )
            shot(owner, 3, 0.3, "wall")
            assert(
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.3) < 1e-8,
                "valid retry failed"
            )
        end
    )
    test(
        "SustainedPanelFire out-of-order same-step impacts await misses and deduplicate after drain",
        function()
            local owner = fixture()
            shot(owner, 3, 0.3, "wall")
            shot(owner, 2, 0.15, "wall")
            assert(
                owner.resources().pending == 2
                    and assert(owner.snapshot("wall"), "wall missing").progress == 0,
                "gap frontier advanced"
            )
            shot(owner, 1, 0, nil)
            assert(owner.resources().pending == 0, "Expected owner.resources().pending == 0")
            assert(
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.15) < 1e-8,
                "reordered span changed"
            )
            assert(
                not owner.resolve({
                    roundId = 1,
                    shotId = 3,
                    weapon = "GAU23",
                    firedAt = 0.3,
                    panelId = "wall",
                }),
                'Expected not owner.resolve({ roundId = 1, shotId = 3, weapon = "GAU23", firedAt = 0.3, panelId = "wall", })'
            )
        end
    )
    test(
        "SustainedPanelFire interruption cutoff prevents old in-flight outcomes restoring cleared work",
        function()
            local owner = fixture()
            shot(owner, 1, 1, "wall")
            shot(owner, 2, 1.15, "wall")
            owner.interrupt(2)
            shot(owner, 3, 1.3, "wall")
            shot(owner, 4, 1.45, "wall")
            assert(
                assert(owner.snapshot("wall"), "wall missing").progress == 0,
                "old flight restored interrupted work"
            )
            shot(owner, 5, 3, "wall")
            shot(owner, 6, 3.15, "wall")
            assert(
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.15) < 1e-8,
                "new stream failed"
            )
        end
    )
    test("SustainedPanelFire stale-round cancellation resets stream pending and heavy history", function()
        local owner = fixture()
        shot(owner, 1, 0, "wall", "M102")
        shot(owner, 3, 0.3, "wall")
        owner.reset(2, { "wall", "roof" })
        assert(
            owner.resources().pending == 0 and assert(owner.snapshot("wall"), "wall missing").progress == 0,
            "reset retained history"
        )
        assert(
            not owner.resolve({ roundId = 1, shotId = 2, weapon = "GAU23", firedAt = 0.15, panelId = "wall" }),
            'Expected not owner.resolve({ roundId = 1, shotId = 2, weapon = "GAU23", firedAt = 0.15, panelId = "wall" })'
        )
        assert(
            owner.resolve({ roundId = 2, shotId = 1, weapon = "M102", firedAt = 10, panelId = "wall" }),
            'Expected owner.resolve({ roundId = 2, shotId = 1, weapon = "M102", firedAt = 10, panelId = "wall" })'
        )
        assert(assert(owner.snapshot("wall"), "wall missing").heavySeconds == 3, "fresh generation failed")
    end)
    test(
        "SustainedPanelFire heavy six direct hits preserve monotonic state and immutable snapshots",
        function()
            local owner = fixture()
            for id = 1, 6 do
                shot(owner, id, (id - 1) * 4, "wall", "M102")
                local state = assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")')
                assert(state.stage == math.floor(id / 3), "Expected state.stage == math.floor(id / 3)")
                state.stage = 0
            end
            shot(owner, 7, 24, "wall", "M102")
            assert(assert(owner.snapshot("wall"), "wall missing").stage == 2, "destroyed state regressed")
        end
    )
end
