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
        "SustainedPanelFire exact nine-second accepted prefix survives 0.6-second flight and idle barrier",
        function()
            local owner = fixture()
            local accepted = 0
            local delivered = 0
            local lastAcceptedAt = -math.huge
            -- Controlled flight adapter reproduces actual .15s authorization and .6s
            -- travel. Idle begins while the final four valid outcomes remain in flight.
            for frame = 0, 204 do
                local now = frame * 0.05
                while accepted < 61 and accepted * 0.15 <= now + 1e-8 do
                    lastAcceptedAt = accepted * 0.15
                    accepted += 1
                end
                if now - lastAcceptedAt > 0.225 then
                    owner.interrupt(accepted)
                end
                while delivered < accepted and delivered * 0.15 + 0.6 <= now + 1e-8 do
                    delivered += 1
                    shot(owner, delivered, (delivered - 1) * 0.15, "wall")
                end
            end
            local state = assert(owner.snapshot("wall"), "wall missing")
            assert(
                accepted == 61 and delivered == 61 and state.stage == 1,
                "idle cancelled exact valid nine-second tail"
            )
            assert(
                state.sustainedSeconds == 0 and owner.resources().barriers == 0,
                "completed prefix or interruption leaked"
            )
        end
    )
    test(
        "SustainedPanelFire queued interruption clears partial prefix before later shots without resurrection",
        function()
            local owner = fixture()
            for id = 1, 17 do
                shot(owner, id, (id - 1) * 0.15, "wall")
            end
            owner.interrupt(21)
            -- A later shot may collide first, but cannot score before older outcomes
            -- and the accepted-prefix barrier have drained.
            shot(owner, 22, 4, "wall")
            for id = 18, 21 do
                shot(owner, id, (id - 1) * 0.15, "wall")
            end
            assert(
                assert(owner.snapshot("wall"), "wall missing").progress == 0,
                "partial pre-barrier credit survived"
            )
            shot(owner, 23, 4.15, "wall")
            owner.interrupt(21)
            owner.interrupt(22) -- an unissued historical boundary is stale too
            assert(
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.15) < 1e-8,
                "stale barrier cleared new valid stream"
            )
            assert(
                owner.resources().pending == 0 and owner.resources().barriers == 0,
                "ordered interruption work leaked"
            )
        end
    )
    test(
        "SustainedPanelFire terminal cancellation rejects old outcomes and clears pending barriers",
        function()
            local owner = fixture()
            for id = 1, 3 do
                shot(owner, id, id * 4, "wall", "M102")
            end
            shot(owner, 4, 13, "wall")
            shot(owner, 5, 13.15, "wall")
            owner.interrupt(7)
            shot(owner, 7, 13.45, "wall")
            owner.cancel()
            assert(owner.resources().pending == 0 and owner.resources().barriers == 0, "terminal work leaked")
            assert(not owner.resolve({
                roundId = 1,
                shotId = 6,
                weapon = "GAU23",
                firedAt = 13.3,
                panelId = "wall",
            }), "closed generation accepted old flight")
            assert(
                assert(owner.snapshot("wall"), "wall missing").stage == 1
                    and assert(owner.snapshot("wall"), "wall missing").sustainedSeconds == 0,
                "cancel regressed completed stage or kept partial work"
            )
            owner.reset(2, { "wall" })
            assert(
                owner.resolve({ roundId = 2, shotId = 1, weapon = "M102", firedAt = 20, panelId = "wall" }),
                "new generation did not reopen"
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
