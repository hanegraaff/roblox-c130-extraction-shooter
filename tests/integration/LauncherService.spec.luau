--!strict
-- P08 A1–A4/A6, R08/R10/R13: actual deterministic identity/transfer/reload service.
-- Runtime eligibility includes MatchService's reconnect tombstone, body, movement,
-- reach, equipped Tool and deadline; those engine boundaries have separate suites.
type API = typeof(require(game:GetService("ServerScriptService").Server.LauncherService))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API
    local anchor = { x = 0, y = 3, z = 0 }
    local function request(sequence: number, roundId: number?): { [string]: unknown }
        local id = roundId or 1
        return { roundId = id, sequence = sequence, launcherId = "launcher:" .. tostring(id) }
    end
    local function shot(sequence: number, roundId: number?): { [string]: unknown }
        local payload = request(sequence, roundId)
        payload.x, payload.y, payload.z = 360, 140, 0
        return payload
    end
    local function owner(): typeof(rules.new())
        local service = rules.new()
        service.reset(1, anchor)
        return service
    end
    test("P08 A1 raced pickup and snapshots retain one stable identity", function()
        local service = owner()
        assert(service.pickup(1, request(1), true, true, 0), "first claim failed")
        assert(not service.pickup(2, request(1), true, true, 0), "second owner accepted")
        assert(not service.pickup(1, request(1), true, true, 0), "duplicate accepted")
        local state = service.snapshot(0)
        assert(
            state.ownerId == 1 and state.state == "Held" and state.launcherId == "launcher:1",
            "identity changed"
        )
        state.position.x = 999
        assert(service.snapshot(0).position.x == 0, "snapshot mutated service")
    end)
    test("P08 A2 malformed forged oversized nonfinite and stale intents leave readiness unchanged", function()
        local service = owner()
        local invalid: { unknown } = {
            {},
            "bad",
            { roundId = 1, sequence = 1, launcherId = string.rep("x", 65) },
            { roundId = 1, sequence = 1, launcherId = "unknown" },
            request(1, 2),
            request(0),
            request(1.5),
            { roundId = 1, sequence = math.huge, launcherId = "launcher:1" },
            { roundId = 1, sequence = 0 / 0, launcherId = "launcher:1" },
            { roundId = 1, sequence = 1, launcherId = "launcher:1", ownerId = 5 },
            { roundId = 1, sequence = 1, launcherId = "launcher:1", nested = {} },
        }
        for _, payload in invalid do
            assert(not service.pickup(1, payload, true, true, 0), "invalid claim accepted")
            assert(
                service.snapshot(0).state == "Available" and service.snapshot(0).ammo == 1,
                "invalid mutation"
            )
        end
        assert(service.pickup(1, request(1), true, true, 0), "valid claim poisoned")
    end)
    test("P08 A2 authority and reach rejection preserve valid retry and replay state", function()
        local service = owner()
        assert(not service.pickup(1, request(100), false, true, 0), "dead/wrong-role claim")
        assert(not service.pickup(1, request(100), true, false, 0), "unreachable claim")
        assert(service.pickup(1, request(1), true, true, 0), "valid low sequence was poisoned")
        assert(not service.fire(2, shot(1), true, 0, anchor), "unowned fire")
        assert(not service.drop(2, request(1), true, 0), "unowned drop")
        assert(not service.fire(1, shot(2), false, 0, anchor), "ineligible fire")
        assert(service.snapshot(0).ammo == 1, "rejection spent ammunition")
    end)
    test("P08 A3 drop transfers preserve exact reload deadline and no reserve items", function()
        local service = owner()
        assert(service.pickup(1, request(1), true, true, 0), "claim")
        local _, first = service.fire(1, shot(2), true, 0, anchor)
        assert(first and service.snapshot(0).ammo == 0, "shot")
        assert(service.drop(1, request(3), true, 0.1), "drop")
        assert(service.snapshot(1).state == "Recovering" and service.snapshot(1).ownerId == nil, "recovering")
        assert(not service.pickup(2, request(1), true, true, 1), "claim before placement")
        assert(service.place({ x = 10, y = 3, z = 0 }), "place")
        assert(service.pickup(2, request(1), true, true, 1), "teammate claim")
        assert(service.snapshot(1).readyAt == rules.reloadSeconds, "transfer refreshed reload")
        assert(not service.fire(2, shot(2), true, rules.reloadSeconds - 1e-6, anchor), "early shot")
        local _, second = service.fire(2, shot(2), true, rules.reloadSeconds, anchor)
        assert(second and second ~= first, "reload boundary/shot identity")
    end)
    test("P08 A3 death reset and disconnect recovery is idempotent and preserves per-user replay", function()
        local service = owner()
        assert(service.pickup(1, request(1), true, true, 0), "claim")
        assert(service.fire(1, shot(2), true, 0, anchor), "fire")
        for _, userId in { 1, 2, 3 } do
            assert(service.recover(userId), "carrier recovery")
            assert(not service.recover(userId), "duplicate recovery")
            assert(not service.place({ x = math.huge, y = 0, z = 0 }), "invalid drop accepted")
            assert(service.place(anchor), "anchor recovery")
            assert(not service.place(anchor), "duplicate placement")
            assert(service.pickup(userId + 1, request(1), true, true, 1), "recoverable weapon")
            assert(service.snapshot(1).readyAt == rules.reloadSeconds, "reload lost")
        end
    end)
    test("P08 A3 re-picking and same-round reset cannot refill or replay a prior holder's command", function()
        local service = owner()
        assert(service.pickup(1, request(1), true, true, 0), "claim")
        assert(service.fire(1, shot(2), true, 0, anchor), "fire")
        service.reset(1, anchor)
        assert(
            service.snapshot(1).ammo == 0 and service.snapshot(1).ownerId == 1,
            "same round reset refilled"
        )
        assert(service.recover(1) and service.place(anchor), "recover")
        assert(not service.pickup(1, request(1), true, true, 1), "old holder sequence replay")
        assert(service.pickup(1, request(3), true, true, 1), "new holder sequence")
        assert(not service.fire(1, shot(4), true, 3.9, anchor), "switch/re-pick bypass")
    end)
    test("P08 A4 fire preflight and exact range are nonmutating until accepted", function()
        local service = owner()
        assert(service.pickup(1, request(1), true, true, 0), "claim")
        assert(service.preflight(1, shot(2), "Fire", true, 0), "preflight")
        assert(service.snapshot(0).ammo == 1, "preflight spent ammo")
        for _, x in { 0, 1200.001, math.huge, 0 / 0 } do
            local payload = shot(2)
            payload.x, payload.y, payload.z = x, 3, 0
            assert(not service.fire(1, payload, true, 0, anchor), "invalid range accepted")
            assert(service.snapshot(0).ammo == 1, "range rejection spent ammo")
        end
        local payload = shot(2)
        payload.x, payload.y, payload.z = 1200, 3, 0
        assert(service.fire(1, payload, true, 0, anchor), "exact range rejected")
        assert(not service.fire(1, payload, true, 4, anchor), "duplicate shot accepted")
    end)
    test("P08 A4 replenishment permits three shots well within the normal round", function()
        local service = owner()
        assert(service.pickup(1, request(1), true, true, 0), "claim")
        for index = 1, 3 do
            assert(
                service.fire(1, shot(index + 1), true, (index - 1) * rules.reloadSeconds, anchor),
                "three-shot timing"
            )
        end
        assert(2 * rules.reloadSeconds + rules.lifetimeSeconds < 600, "normal round cannot fit three shots")
        assert(
            rules.speedStudsPerSecond * rules.lifetimeSeconds == rules.rangeStuds,
            "flight range/lifetime drift"
        )
    end)
    test("P08 A6 terminal cleanup beats recovery and next round rejects old callbacks", function()
        local service = owner()
        assert(service.pickup(1, request(1), true, true, 0), "claim")
        assert(service.fire(1, shot(2), true, 0, anchor), "fire")
        service.clear()
        service.clear()
        assert(not service.recover(1) and not service.place(anchor), "terminal recovery")
        assert(not service.pickup(2, request(1), true, true, 5), "terminal pickup")
        service.reset(2, anchor)
        assert(not service.fire(1, shot(3), true, 5, anchor), "stale fire")
        assert(not service.pickup(1, request(3), true, true, 5), "stale pickup")
        local state = service.snapshot(5)
        assert(
            state.ownerId == nil and state.state == "Available" and state.ammo == 1 and state.readyAt == 0,
            "new round not pristine"
        )
        assert(service.pickup(1, request(1, 2), true, true, 5), "fresh pickup")
    end)
    test("P08 A3/A5 composed match tombstones prevent reconnect life or launcher restoration", function()
        local loadPath = (require :: unknown) :: (string) -> unknown
        local Match = (
            if script
                then require(game:GetService("ServerScriptService").Server.MatchService)
                else loadPath("../../src/server/MatchService")
        ) :: typeof(require(game:GetService("ServerScriptService").Server.MatchService))
        local service = owner()
        local match = Match.new({ minimumPlayers = 2, durationSeconds = 600, seed = 1 }, {
            now = function()
                return 10
            end,
            releaseLife = function(id, _roundId, recover)
                if recover then
                    if service.recover(id) then
                        assert(service.place(anchor), "recover placement")
                    end
                else
                    service.clear()
                end
            end,
        })
        for id = 1, 3 do
            match.join(id)
        end
        assert(match.deploy(), "deploy")
        local initial = match.snapshot()
        local groundIds: { number } = {}
        for id, member in initial.members do
            assert(match.ready(id, initial.roundId), "ready")
            if member.role == "Ground" then
                table.insert(groundIds, id)
            end
        end
        assert(match.activate(), "activate")
        local departed, teammate = groundIds[1], groundIds[2]
        assert(service.pickup(departed, request(1), true, true, 10), "pickup")
        assert(service.fire(departed, shot(2), true, 10, anchor), "fire")
        match.leave(departed)
        match.step()
        match.join(departed)
        local member = match.snapshot().members[departed]
        local eligible = member.connected and member.role == "Ground" and member.life == "Alive"
        assert(
            not eligible and not service.pickup(departed, request(3), eligible, true, 11),
            "reconnected carrier restored"
        )
        assert(service.pickup(teammate, request(1), true, true, 11), "teammate recovery")
        assert(service.snapshot(11).readyAt == 10 + rules.reloadSeconds, "disconnect refreshed reload")
        assert(match.eliminate(teammate, initial.roundId), "last elimination")
        match.step()
        assert(
            match.snapshot().phase == "Results" and service.snapshot(11).state == "Inactive",
            "terminal recovery took precedence"
        )
        assert(not service.recover(teammate), "result resurrected weapon")
    end)
end
