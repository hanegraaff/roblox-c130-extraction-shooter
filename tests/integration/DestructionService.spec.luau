--!strict
-- P18 A2: server-ordered short demolition, retained credit and bounded cleanup.
type API = typeof(require(game:GetService("ServerScriptService").Server.DestructionService))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Service = candidate :: API
    type Owner = typeof(Service.new())
    type Snapshot = {
        stage: number,
        heavySeconds: number,
        sustainedSeconds: number,
        progress: number,
        appearance: "Pristine" | "Light" | "Heavy" | "Total",
    }
    local function fixture(): Owner
        local owner = Service.new()
        owner.reset(1, { "wall", "roof" })
        owner.changed()
        return owner
    end
    local function state(owner: Owner, id: string): Snapshot
        return assert(owner.snapshot(id), "missing panel " .. id)
    end
    test("P19 ground contact advances one ordered blast across unique registered panels", function()
        local owner = Service.new()
        owner.reset(1, { "near", "other", "covered", "wreck" }, "wreck")
        owner.changed()
        local nearby = { "near", "near", "other" }
        assert(
            owner.resolve({ roundId = 1, shotId = 2, firedAt = 4, weapon = "M102", blastPanelIds = nearby })
        )
        assert(#owner.changed() == 0, "out-of-order blast jumped the frontier")
        nearby[1], nearby[2], nearby[3] = "covered", "covered", "covered"
        assert(owner.resolve({ roundId = 1, shotId = 1, firedAt = 0, weapon = "M102" }))
        assert(
            table.concat(owner.changed(), ",") == "near,other",
            "duplicate or mutable blast changed the wrong panels"
        )
        assert(
            state(owner, "near").stage == 2 and state(owner, "other").stage == 2,
            "exposed panels did not reach Total"
        )
        assert(state(owner, "covered").stage == 0, "excluded cover changed")
        assert(not owner.resolve({
            roundId = 1,
            shotId = 2,
            firedAt = 4,
            weapon = "M102",
            blastPanelIds = nearby,
        }), "duplicate accepted shot reached the ledger")
        assert(not owner.resolve({
            roundId = 0,
            shotId = 3,
            firedAt = 8,
            weapon = "M102",
            blastPanelIds = nearby,
        }), "stale round reached the blast ledger")
        assert(not owner.resolve({
            roundId = 1,
            shotId = 3,
            firedAt = 8,
            weapon = "GAU23",
            blastPanelIds = nearby,
        }), "light impact was allowed to demolish by splash")
        assert(not owner.resolve({
            roundId = 1,
            shotId = 3,
            firedAt = 8,
            weapon = "M102",
            blastPanelIds = { "missing" },
        }), "unregistered blast target was accepted")
        assert(not owner.resolve({
            roundId = 1,
            shotId = 3,
            firedAt = 8,
            weapon = "M102",
            blastPanelIds = { "wreck" },
        }), "nonbuilding fragile wreck accepted splash")
        assert(
            #owner.changed() == 0 and state(owner, "covered").stage == 0,
            "rejected outcomes advanced destruction"
        )
        assert(owner.resolve({
            roundId = 1,
            shotId = 3,
            firedAt = 8,
            weapon = "M102",
            panelId = "covered",
            blastPanelIds = { "covered", "near" },
        }))
        assert(table.concat(owner.changed(), ",") == "covered", "direct and splash were not idempotent")
    end)
    local function shot(owner: Owner, id: number, time: number, panel: string?, weapon: string?)
        assert(
            owner.resolve({
                roundId = 1,
                shotId = id,
                firedAt = time,
                panelId = panel,
                weapon = weapon or "GAU23",
            }),
            "valid accepted outcome rejected"
        )
    end
    test(
        "P18 one direct howitzer destroys each panel independently and snapshots cannot mutate it",
        function()
            local owner = fixture()
            shot(owner, 1, 0, "wall", "M102")
            local copy = state(owner, "wall")
            assert(copy.stage == 2 and copy.appearance == "Total", "one-shot panel threshold")
            copy.stage = 0
            assert(
                state(owner, "wall").stage == 2 and state(owner, "roof").stage == 0,
                "snapshot aliases state"
            )
            assert(
                not owner.resolve({ roundId = 1, shotId = 1, weapon = "M102", firedAt = 0, panelId = "wall" }),
                "duplicate outcome"
            )
            shot(owner, 2, 4, "wall", "M102")
            assert(state(owner, "wall").stage == 2, "terminal state regressed")
        end
    )
    test("P18 short 30mm burst reaches Heavy at one second and Total at two", function()
        local owner = fixture()
        shot(owner, 1, 100, "wall")
        assert(state(owner, "wall").progress == 0, "first impact earned elapsed time")
        for id = 2, 5 do
            shot(owner, id, 100 + (id - 1) * 0.2, "wall")
        end
        assert(state(owner, "wall").stage == 0, "Heavy advanced early")
        shot(owner, 6, 101, "wall")
        assert(state(owner, "wall").stage == 1, "Heavy threshold missed")
        for id = 7, 10 do
            shot(owner, id, 100 + (id - 1) * 0.2, "wall")
        end
        assert(state(owner, "wall").stage == 1, "Total advanced early")
        shot(owner, 11, 102, "wall")
        assert(state(owner, "wall").stage == 2, "two seconds did not destroy")
    end)
    test("P18 separated bursts retain earned Light Heavy and exclude pauses", function()
        local owner = fixture()
        local id = 0
        for burst = 1, 4 do
            for sample = 0, 2 do
                id += 1
                shot(owner, id, burst * 100 + sample * 0.2, "wall")
            end
            owner.interrupt(id)
            local earned = burst * 0.4
            local current = state(owner, "wall")
            assert(current.stage == math.floor(earned + 1e-8), "incorrect separated burst stage")
            assert(
                math.abs(current.sustainedSeconds - (earned - current.stage)) < 1e-7,
                "pause healed or earned time"
            )
            assert(
                current.appearance == (if burst < 3 then "Light" else "Heavy"),
                "persistent appearance changed"
            )
        end
        shot(owner, id + 1, 900, "wall")
        assert(state(owner, "wall").stage == 1, "resumed first shot charged idle time")
        shot(owner, id + 2, 900.2, "wall")
        shot(owner, id + 3, 900.4, "wall")
        assert(state(owner, "wall").stage == 2, "earned interrupted two seconds did not destroy")
    end)
    test("P18 continuity gap boundary preserves credit while excluding excess elapsed gap", function()
        for _, gap in { 0.225, 0.22501 } do
            local owner = fixture()
            shot(owner, 1, 0, "wall")
            shot(owner, 2, 0.15, "wall")
            shot(owner, 3, 0.15 + gap, "wall")
            assert(
                math.abs(state(owner, "wall").sustainedSeconds - (if gap == 0.225 then 0.375 else 0.15))
                    < 1e-8,
                "gap credit"
            )
        end
    end)
    test("P18 misses retarget reload switch and loss retain prior credit", function()
        for _, interruption in { "miss", "target", "switch", "reload", "loss" } do
            local owner = fixture()
            shot(owner, 1, 0, "wall")
            shot(owner, 2, 0.15, "wall")
            if interruption == "miss" then
                shot(owner, 3, 0.3, nil)
            elseif interruption == "target" then
                shot(owner, 3, 0.3, "roof")
            elseif interruption == "switch" then
                shot(owner, 3, 0.3, "roof", "M102")
            elseif interruption == "reload" then
                shot(owner, 3, 8, "wall")
            else
                owner.interrupt()
            end
            local nextId = if interruption == "loss" then 3 else 4
            shot(owner, nextId, 20, "wall")
            assert(
                math.abs(state(owner, "wall").sustainedSeconds - 0.15) < 1e-8,
                "first resumed impact changed earned credit"
            )
            shot(owner, nextId + 1, 20.15, "wall")
            assert(
                math.abs(state(owner, "wall").sustainedSeconds - 0.3) < 1e-8,
                "resumed interval lost credit"
            )
            shot(owner, nextId + 2, 21, "wall", "M102")
            assert(state(owner, "wall").stage == 2, "mixed howitzer failed")
        end
    end)
    test("P18 malformed stale replay unauthorized and unknown panels reject without mutation", function()
        local owner = fixture()
        shot(owner, 1, 0, "wall")
        shot(owner, 2, 0.15, "wall")
        for _, value in
            {
                { roundId = 0, shotId = 3, firedAt = 0.3, weapon = "GAU23", panelId = "wall" },
                { roundId = 1, shotId = 2, firedAt = 0.3, weapon = "GAU23", panelId = "wall" },
                { roundId = 1, shotId = 3, firedAt = 0 / 0, weapon = "GAU23", panelId = "wall" },
                { roundId = 1, shotId = 3, firedAt = 0.3, weapon = "M7", panelId = "wall" },
                { roundId = 1, shotId = 3, firedAt = 0.3, weapon = "GAU23", panelId = "forged" },
                { roundId = 1, shotId = 10000, firedAt = 0.3, weapon = "GAU23", panelId = "wall" },
            }
        do
            assert(not owner.resolve(value), "invalid outcome admitted")
            assert(
                math.abs(state(owner, "wall").sustainedSeconds - 0.15) < 1e-8,
                "invalid outcome mutated credit"
            )
        end
        shot(owner, 3, 0.3, "wall")
        assert(
            math.abs(state(owner, "wall").sustainedSeconds - 0.3) < 1e-8,
            "rejection prevented valid retry"
        )
    end)
    test("P18 reordered completions wait for missing outcomes and deduplicate after drain", function()
        local owner = fixture()
        shot(owner, 3, 0.3, "wall")
        shot(owner, 2, 0.15, "wall")
        assert(
            owner.resources().pending == 2 and state(owner, "wall").progress == 0,
            "frontier advanced early"
        )
        shot(owner, 1, 0, nil)
        assert(
            owner.resources().pending == 0 and math.abs(state(owner, "wall").sustainedSeconds - 0.15) < 1e-8,
            "ordered drain credit"
        )
        assert(
            not owner.resolve({ roundId = 1, shotId = 3, firedAt = 0.3, weapon = "GAU23", panelId = "wall" }),
            "drained replay admitted"
        )
    end)
    test("P18 accepted in-flight prefix survives idle barrier without counting time across it", function()
        local owner = fixture()
        for id = 1, 3 do
            shot(owner, id, (id - 1) * 0.2, "wall")
        end
        owner.interrupt(5)
        shot(owner, 6, 4, "wall")
        shot(owner, 5, 0.8, "wall")
        shot(owner, 4, 0.6, "wall")
        assert(
            math.abs(state(owner, "wall").sustainedSeconds - 0.8) < 1e-8,
            "in-flight prefix lost or pause counted"
        )
        shot(owner, 7, 4.2, "wall")
        owner.interrupt(5)
        assert(state(owner, "wall").stage == 1, "retained prefix did not reach Heavy")
        assert(owner.resources().pending == 0 and owner.resources().barriers == 0, "barriers leaked")
    end)
    test("P18 full structural window rejects overflow and drains one damage outcome", function()
        local owner = fixture()
        local cap = Service.outcomeWindow
        for id = cap + 1, 2, -1 do
            owner.interrupt(id)
            shot(owner, id, 100 + id, nil)
        end
        owner.interrupt(1)
        assert(
            owner.resources().pending == cap and owner.resources().barriers == cap + 1,
            "window capacity changed"
        )
        for _, id in { cap + 1, cap + 2 } do
            assert(not owner.resolve({
                roundId = 1,
                shotId = id,
                weapon = "M102",
                firedAt = 99,
                panelId = "wall",
            }), "overflow/replay admitted")
        end
        shot(owner, 1, 100, "wall", "M102")
        assert(
            owner.resources().pending == 0
                and owner.resources().barriers == 0
                and state(owner, "wall").stage == 2,
            "bounded drain failed"
        )
    end)
    test("P18 terminal cancellation keeps credit while fresh generation clears history", function()
        local owner = fixture()
        shot(owner, 1, 0, "wall")
        shot(owner, 2, 0.2, "wall")
        owner.interrupt(4)
        shot(owner, 4, 0.6, "wall")
        owner.cancel()
        assert(owner.resources().pending == 0 and owner.resources().barriers == 0, "terminal work leaked")
        assert(math.abs(state(owner, "wall").sustainedSeconds - 0.2) < 1e-8, "cancel erased earned credit")
        assert(
            not owner.resolve({ roundId = 1, shotId = 3, weapon = "GAU23", firedAt = 0.4, panelId = "wall" }),
            "terminal outcome admitted"
        )
        owner.reset(2, { "wall", "roof" })
        assert(state(owner, "wall").appearance == "Pristine", "reset retained damage")
        assert(
            not owner.resolve({ roundId = 1, shotId = 1, weapon = "M102", firedAt = 0, panelId = "wall" }),
            "stale generation admitted"
        )
        assert(
            owner.resolve({ roundId = 2, shotId = 1, weapon = "M102", firedAt = 0, panelId = "wall" }),
            "new generation rejected"
        )
        assert(state(owner, "wall").stage == 2, "fresh howitzer failed")
    end)
    test("Hercules wreck retains its separate three-second continuous light-cover rule", function()
        local owner = fixture()
        owner.reset(1, { "wreck", "wall" }, "wreck")
        for id = 1, 12 do
            shot(owner, id, (id - 1) * 0.15, "wreck")
        end
        shot(owner, 13, 1.8, nil)
        for id = 14, 33 do
            shot(owner, id, 1.95 + (id - 14) * 0.15, "wreck")
        end
        assert(state(owner, "wreck").appearance == "Pristine", "interruption counted toward wreck")
        shot(owner, 34, 4.95, "wreck")
        assert(state(owner, "wreck").appearance == "Total", "three-second wreck threshold")
        shot(owner, 35, 8, "wall", "M102")
        assert(state(owner, "wall").appearance == "Total", "building howitzer rule changed")
    end)
    test("P26 one ledger follows the new round and rejects contacts from the old one", function()
        local owner = Service.new()
        local resolve, snapshot = owner.resolve, owner.snapshot
        for round, mode in { "Low", "High" } do
            owner.reset(round, { "wall" }, nil, { gauCadence = 0.4, panelDamage = mode })
            local function hit(id: number): boolean
                local applied =
                    resolve({ roundId = id, shotId = 1, weapon = "M102", firedAt = 1, panelId = "wall" })
                return applied
            end
            assert(not hit(round - 1), "old impact changed the new generation")
            assert(hit(round), "current impact missed registered panel")
            local panelState = assert(snapshot("wall"), "missing current wall")
            assert(panelState.stage == (if mode == "Low" then 1 else 2), "wrong preset after deployment")
        end
    end)
end
