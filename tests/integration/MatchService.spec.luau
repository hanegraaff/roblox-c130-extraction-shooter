--!strict
-- P03 A2-A4/A6: actual service with controlled monotonic time and equipment-release adapter.
type API = typeof(require(game:GetService("ServerScriptService").Server.MatchService))
type Member = {
    userId: number,
    role: string,
    life: string,
    connected: boolean,
    ready: boolean,
    sequence: number,
}
type Snapshot = {
    roundId: number,
    revision: number,
    phase: "Lobby" | "Deploying" | "Active" | "Results" | "Resetting",
    deadlineSeconds: number,
    members: { [number]: Member },
    result: { winner: string, reason: string }?,
}
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Match = candidate :: API
    test("constructor rejects overflowing seed instead of deploying a roster without operator", function()
        for _, seed in { 0 / 0, math.huge, -1, 0.5, 1e308, 2147483648 } do
            local ok = pcall(function()
                Match.new({ minimumPlayers = 2, durationSeconds = 10, seed = seed }, {
                    now = function()
                        return 0
                    end,
                    releaseLife = function() end,
                })
            end)
            assert(not ok, "unsafe service seed accepted")
        end
    end)
    local function fixture(count: number?)
        local seconds = 100
        local released: { { id: number, roundId: number, recover: boolean } } = {}
        local service = Match.new({ minimumPlayers = 2, durationSeconds = 10, seed = 1 }, {
            now = function()
                return seconds
            end,
            releaseLife = function(id, roundId, recover)
                table.insert(released, { id = id, roundId = roundId, recover = recover })
            end,
        })
        for id = 1, count or 3 do
            service.join(id)
        end
        local function active()
            assert(service.deploy(), "expected service.deploy()")
            local state = service.snapshot()
            for id in state.members do
                assert(service.ready(id, state.roundId), "expected service.ready(id, state.roundId)")
            end
            assert(service.activate(), "expected service.activate()")
            return service.snapshot()
        end
        return service, active, function(value: number)
            seconds = value
        end, released
    end
    local function ground(state: Snapshot): number
        for id, member in state.members do
            if member.role == "Ground" then
                return id
            end
        end
        error("fixture has no ground player")
    end
    local function operator(state: Snapshot): number
        for id, member in state.members do
            if member.role == "Gunship" then
                return id
            end
        end
        error("fixture has no operator")
    end
    test("deployment waits for every roster member and cancellation clears partial readiness", function()
        local service = fixture()
        assert(not service.activate(), "expected not service.activate()")
        assert(service.deploy(), "expected service.deploy()")
        local state = service.snapshot()
        assert(
            service.ready(ground(state), state.roundId),
            "expected service.ready(ground(state), state.roundId)"
        )
        assert(not service.activate(), "expected not service.activate()")
        service.leave(operator(state))
        state = service.snapshot()
        assert(
            state.phase == "Lobby" and next(state.members) == nil and state.deadlineSeconds == 0,
            'expected state.phase == "Lobby" and next(state.members) == nil and state.deadlineSeconds == 0'
        )
        assert(not service.ready(1, state.roundId), "expected not service.ready(1, state.roundId)")
    end)
    test("ground departure during deployment also cancels without partial members", function()
        local service = fixture()
        assert(service.deploy(), "expected service.deploy()")
        local state = service.snapshot()
        service.leave(ground(state))
        assert(
            service.snapshot().phase == "Lobby" and next(service.snapshot().members) == nil,
            'expected service.snapshot().phase == "Lobby" and next(service.snapshot().members) == nil'
        )
    end)
    test("exact injected deadline commits timeout once and late proposals cannot change it", function()
        local service, active, advance = fixture()
        local state = active()
        assert(state.deadlineSeconds == 110, "expected state.deadlineSeconds == 110")
        advance(109.999)
        service.step()
        assert(service.snapshot().phase == "Active", 'expected service.snapshot().phase == "Active"')
        advance(110)
        assert(
            not service.proposeAircraftDestroyed(state.roundId),
            "expected not service.proposeAircraftDestroyed(state.roundId)"
        )
        service.step()
        local ended = service.snapshot()
        assert(
            ended.result and ended.result.reason == "Timeout",
            'expected ended.result and ended.result.reason == "Timeout"'
        )
        assert(not service.abort(state.roundId, "late"), 'expected not service.abort(state.roundId, "late")')
        service.step()
        assert(
            service.snapshot().revision == ended.revision,
            "expected service.snapshot().revision == ended.revision"
        )
    end)
    test("mutual destruction batch gives ground win and terminal cleanup suppresses recovery", function()
        local service, active, _, released = fixture(2)
        local state = active()
        assert(
            service.eliminate(ground(state), state.roundId),
            "expected service.eliminate(ground(state), state.roundId)"
        )
        assert(#released == 0, "expected #released == 0")
        assert(
            service.proposeAircraftDestroyed(state.roundId),
            "expected service.proposeAircraftDestroyed(state.roundId)"
        )
        service.step()
        local result = service.snapshot().result
        assert(result and result.winner == "Ground", 'expected result and result.winner == "Ground"')
        assert(#released == 2, "expected #released == 2")
        for _, release in released do
            assert(not release.recover, "expected not release.recover")
        end
    end)
    test("aircraft destruction before last ground elimination also resolves ground win once", function()
        local service, active = fixture(2)
        local state = active()
        assert(service.proposeAircraftDestroyed(state.roundId), "aircraft proposal rejected")
        assert(service.eliminate(ground(state), state.roundId), "ground elimination rejected")
        service.step()
        local ended = service.snapshot()
        assert(ended.result and ended.result.winner == "Ground", "ground did not win the batch")
        assert(not service.proposeAircraftDestroyed(state.roundId), "terminal proposal accepted")
        service.step()
        assert(service.snapshot().revision == ended.revision, "terminal result changed")
    end)
    test("death releases one owned life once after nonterminal batch and cannot revive on rejoin", function()
        local service, active, _, released = fixture()
        local state = active()
        local id = ground(state)
        assert(service.eliminate(id, state.roundId), "expected service.eliminate(id, state.roundId)")
        assert(not service.eliminate(id, state.roundId), "expected not service.eliminate(id, state.roundId)")
        service.step()
        assert(#released == 1 and released[1].recover, "expected #released == 1 and released[1].recover")
        service.leave(id)
        service.join(id)
        assert(
            service.snapshot().members[id].life == "Eliminated",
            'expected service.snapshot().members[id].life == "Eliminated"'
        )
        assert(
            not service.command(id, { roundId = state.roundId, sequence = 1, action = "Surrender" }),
            'expected not service.command(id, { roundId = state.roundId, sequence = 1, action = "Surrender" })'
        )
        service.step()
        assert(#released == 1, "expected #released == 1")
    end)
    test("operator departure followed by immediate reconnect still forfeits assigned round", function()
        local service, active = fixture()
        local state = active()
        local id = operator(state)
        service.leave(id)
        service.join(id)
        service.step()
        local result = service.snapshot().result
        assert(
            result and result.reason == "OperatorForfeit",
            'expected result and result.reason == "OperatorForfeit"'
        )
    end)
    test("last ground departure wins for remaining operator with no weapon recovery", function()
        local service, active, _, released = fixture(2)
        local state = active()
        service.leave(ground(state))
        service.step()
        local result = service.snapshot().result
        assert(result and result.winner == "Gunship", 'expected result and result.winner == "Gunship"')
        for _, release in released do
            assert(not release.recover, "expected not release.recover")
        end
    end)
    test("both participant departures with a late spectator produce no competitive winner", function()
        local service, active = fixture(2)
        local state = active()
        service.join(99)
        assert(
            service.snapshot().members[99].role == "Spectator",
            'expected service.snapshot().members[99].role == "Spectator"'
        )
        for id in state.members do
            service.leave(id)
        end
        service.step()
        local authoritative = service.snapshot().result
        assert(
            authoritative and authoritative.winner == "None",
            'expected result and result.winner == "None"'
        )
    end)
    test(
        "wrong role stale replay malformed and spectator commands reject without revision mutation",
        function()
            local service, active = fixture()
            local state = active()
            local id = ground(state)
            service.join(99)
            local before = service.snapshot().revision
            local bad: { unknown } = {
                false,
                {},
                { roundId = state.roundId, sequence = 0 / 0, action = "Surrender" },
                { roundId = state.roundId, sequence = math.huge, action = "Surrender" },
                { roundId = state.roundId - 1, sequence = 1, action = "Surrender" },
                { roundId = state.roundId, sequence = 1, action = "Surrender", extra = true },
                { roundId = state.roundId, sequence = 1, action = string.rep("x", 10000) },
            }
            for _, payload in bad do
                assert(not service.command(id, payload), "expected not service.command(id, payload)")
            end
            local valid = { roundId = state.roundId, sequence = 1, action = "Surrender" }
            assert(
                not service.command(operator(state), valid),
                "expected not service.command(operator(state), valid)"
            )
            assert(not service.command(99, valid), "expected not service.command(99, valid)")
            assert(service.snapshot().revision == before, "expected service.snapshot().revision == before")
            assert(service.command(id, valid), "expected service.command(id, valid)")
            local accepted = service.snapshot().revision
            assert(not service.command(id, valid), "expected not service.command(id, valid)")
            assert(
                service.snapshot().revision == accepted,
                "expected service.snapshot().revision == accepted"
            )
        end
    )
    test("three accelerated rounds clear roster result and deadline while rotating operator", function()
        local service, active, advance, released = fixture()
        local previous: number? = nil
        for round = 1, 3 do
            local state = active()
            assert(
                state.roundId == round and operator(state) ~= previous,
                "expected state.roundId == round and operator(state) ~= previous"
            )
            previous = operator(state)
            advance(100 + round * 10)
            service.step()
            assert(service.snapshot().phase == "Results", 'expected service.snapshot().phase == "Results"')
            assert(service.beginReset(), "expected service.beginReset()")
            assert(not service.beginReset(), "expected not service.beginReset()")
            assert(service.finishReset(), "expected service.finishReset()")
            local reset = service.snapshot()
            assert(
                reset.phase == "Lobby"
                    and next(reset.members) == nil
                    and reset.result == nil
                    and reset.deadlineSeconds == 0,
                'expected reset.phase == "Lobby" and next(reset.members) == nil and reset.result == nil and reset.deadlineSeconds == 0'
            )
            assert(
                not service.eliminate(1, state.roundId),
                "expected not service.eliminate(1, state.roundId)"
            )
        end
        assert(#released == 9, "expected #released == 9")
    end)
    test("snapshots cannot mutate authoritative members or committed results", function()
        local service, active = fixture()
        local state = active()
        state.members[ground(state)].life = "Cheated"
        assert(
            service.snapshot().members[ground(state)].life == "Alive",
            'expected service.snapshot().members[ground(state)].life == "Alive"'
        )
        assert(
            service.abort(state.roundId, "FixtureAbort"),
            'expected service.abort(state.roundId, "FixtureAbort")'
        )
        local result = service.snapshot().result
        assert(result, "expected result")
        result.winner = "Cheated"
        local authoritative = service.snapshot().result
        assert(
            authoritative and authoritative.winner == "None",
            'expected result and result.winner == "None"'
        )
    end)
end
