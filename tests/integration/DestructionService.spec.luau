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
    test("SustainedPanelFire cadence gap boundary preserves earned work and excludes elapsed gaps", function()
        for _, gap in { 0.225, 0.22501 } do
            local owner = fixture()
            shot(owner, 1, 0, "wall")
            shot(owner, 2, 0.15, "wall")
            shot(owner, 3, 0.15 + gap, "wall")
            local state = assert(owner.snapshot("wall"), 'Expected owner.snapshot("wall")')
            assert(
                math.abs(state.sustainedSeconds - (if gap == 0.225 then 0.375 else 0.15)) < 1e-8,
                "gap policy"
            )
        end
    end)
    test(
        "SustainedPanelFire misses blocked targets switches reload and operator loss preserve earned damage",
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
                    state.heavySeconds == 3
                        and math.abs(state.sustainedSeconds - 0.15) < 1e-8
                        and state.stage == 0,
                    interruption
                )
                local resumed = if interruption == "disconnect" then 4 else 5
                shot(owner, resumed, 20, "wall")
                assert(
                    math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.15) < 1e-8,
                    "first resumed hit charged paused time"
                )
                shot(owner, resumed + 1, 20.15, "wall")
                assert(
                    math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.3) < 1e-8,
                    "resumed interval lost prior earned credit"
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
        "SustainedPanelFire queued interruption retains partial prefix while forbidding time across its barrier",
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
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 3) < 1e-8,
                "partial pre-barrier credit was lost or gap time awarded"
            )
            shot(owner, 23, 4.15, "wall")
            owner.interrupt(21)
            owner.interrupt(22) -- an unissued historical boundary is stale too
            assert(
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 3.15) < 1e-8,
                "stale barrier changed persistent valid stream"
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
                    and math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.15)
                        < 1e-8,
                "cancel regressed completed stage or erased earned credit"
            )
            owner.reset(2, { "wall" })
            assert(
                owner.resolve({ roundId = 2, shotId = 1, weapon = "M102", firedAt = 20, panelId = "wall" }),
                "new generation did not reopen"
            )
        end
    )
    test(
        "PersistentPanelFire three separated bursts earn nine seconds per stage without idle credit",
        function()
            local owner = fixture()
            local id = 0
            for burst = 1, 6 do
                for sample = 0, 20 do
                    id += 1
                    shot(owner, id, burst * 100 + sample * 0.15, "wall")
                end
                owner.interrupt(id)
                local state = assert(owner.snapshot("wall"), "wall missing")
                assert(
                    state.stage == math.min(2, math.floor(burst / 3)),
                    "separated bursts crossed wrong stage boundary"
                )
                assert(
                    math.abs(state.sustainedSeconds - (if burst % 3 == 0 then 0 else (burst % 3) * 3)) < 1e-7,
                    "idle barrier changed earned burst credit"
                )
            end
        end
    )
    test(
        "PersistentPanelFire alternating targets keep independent credits and resumed first hits earn zero",
        function()
            local owner = fixture()
            shot(owner, 1, 0, "wall")
            shot(owner, 2, 0.15, "wall")
            shot(owner, 3, 0.3, "roof")
            shot(owner, 4, 0.45, "roof")
            shot(owner, 5, 0.6, "wall")
            assert(
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.15) < 1e-8,
                "retargeted first hit charged elapsed gap"
            )
            shot(owner, 6, 0.75, "wall")
            shot(owner, 7, 0.9, nil)
            shot(owner, 8, 1.05, "wall")
            shot(owner, 9, 1.2, "wall")
            assert(
                math.abs(assert(owner.snapshot("wall"), "wall missing").sustainedSeconds - 0.45) < 1e-8,
                "wall credit did not persist across target/miss"
            )
            assert(
                math.abs(assert(owner.snapshot("roof"), "roof missing").sustainedSeconds - 0.15) < 1e-8,
                "other panel credit changed"
            )
            shot(owner, 10, 2, "wall", "M102")
            assert(
                assert(owner.snapshot("wall"), "wall missing").heavySeconds == 3
                    and assert(owner.snapshot("wall"), "wall missing").appearance == "Light",
                "mixed persistent appearance incorrect"
            )
            owner.reset(2, { "wall", "roof" })
            assert(
                assert(owner.snapshot("wall"), "wall missing").appearance == "Pristine"
                    and assert(owner.snapshot("roof"), "roof missing").progress == 0,
                "reset retained earned damage"
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
