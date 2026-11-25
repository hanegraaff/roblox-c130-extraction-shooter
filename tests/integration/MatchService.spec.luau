--!strict
-- P03 A2-A4/A6 and P09 A1-A4/A6: controlled monotonic time and equipment release.
type ConfigModule = typeof(require(game:GetService("ReplicatedStorage").Shared.Config))
local loadModule = (require :: unknown) :: (string) -> unknown
local Config = if script
    then require(game:GetService("ReplicatedStorage").Shared.Config)
    else loadModule("../../src/shared/Config") :: ConfigModule
type HealthModule = typeof(require(game:GetService("ServerScriptService").Server.AircraftHealth))
local AircraftHealth = if script
    then require(game:GetService("ServerScriptService").Server.AircraftHealth)
    else loadModule("../../src/server/AircraftHealth") :: HealthModule
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
    phase: "Lobby" | "Deploying" | "Scatter" | "Active" | "Results" | "Resetting",
    deadlineSeconds: number,
    members: { [number]: Member },
    result: { winner: string, reason: string, userId: number?, weapon: string?, shotId: string? }?,
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
    local function fixture(count: number?, intermissionSeconds: number?, scatterSeconds: number?)
        local seconds = 100
        local released: { { id: number, roundId: number, recover: boolean } } = {}
        local service = Match.new({
            minimumPlayers = 2,
            durationSeconds = 10,
            seed = 1,
            intermissionSeconds = intermissionSeconds,
            scatterSeconds = scatterSeconds,
        }, {
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
    test("P24 delayed readiness starts a full scatter clock and reveals exactly once at equality", function()
        local service, _, setTime = fixture(2, 120, 20)
        assert(service.deploy(), "deployment unavailable")
        local roundId = service.snapshot().roundId
        assert(service.ready(1, roundId), "first avatar not ready")
        setTime(140)
        assert(not service.activate(), "unready roster began scattering")
        service.step()
        assert(service.snapshot().deadlineSeconds == 0, "loading consumed the scatter interval")

        assert(service.ready(2, roundId) and service.activate(), "ready roster did not begin scattering")
        assert(
            service.snapshot().phase == "Scatter" and service.snapshot().deadlineSeconds == 160,
            "scatter did not begin at final readiness"
        )
        local function unexpectedDamage()
            error("pre-arrival damage callback fired")
        end
        setTime(159.999)
        assert(
            not service.damageAllowed(roundId) and not service.proposeAircraftDestroyed(roundId),
            "combat accepted before arrival"
        )
        service.step(unexpectedDamage)
        assert(service.snapshot().phase == "Scatter", "arrival preceded the deadline")

        setTime(160)
        service.step(unexpectedDamage)
        local revealed = service.snapshot()
        assert(revealed.phase == "Active" and revealed.deadlineSeconds == 170, "full combat clock missing")
        assert(service.damageAllowed(roundId), "fresh combat intent was blocked")
        assert(not service.ready(2, roundId) and not service.activate(), "stale readiness reactivated roster")
        service.step()
        assert(service.snapshot().revision == revealed.revision, "second step revealed again")
    end)
    test("P24 a delayed arrival step still grants the full combat duration", function()
        local service, deploy, setTime = fixture(2, nil, 20)
        local scattering = deploy()
        assert(scattering.phase == "Scatter" and scattering.deadlineSeconds == 120, "scatter did not start")
        setTime(123.5)
        service.step()
        assert(service.snapshot().deadlineSeconds == 133.5, "delayed frame shortened combat")
    end)
    test("P24 a scatter reset drops one recoverable life and reconnect or late join cannot deploy", function()
        local service, deploy, setTime, released = fixture(3, 120, 20)
        local state = deploy()
        local groundId = 0
        for id, member in state.members do
            if member.role == "Ground" then
                groundId = id
                break
            end
        end
        setTime(105)
        assert(service.characterRemoved(groundId, state.roundId), "reset did not consume a Ground life")
        assert(service.eliminate(groundId, state.roundId), "confirmed death did not refine reset")
        assert(not service.eliminate(groundId, state.roundId), "duplicate death consumed another life")
        service.step()
        service.step()
        assert(#released == 1 and released[1].id == groundId and released[1].recover, "wrong recovery")
        service.leave(groundId)
        service.join(groundId)
        service.join(4)
        local after = service.snapshot()
        assert(after.phase == "Scatter" and after.deadlineSeconds == 120, "roster changes moved arrival")
        assert(
            after.members[groundId].life == "Eliminated" and after.members[4].role == "Spectator",
            "roster changes granted a new life"
        )
        assert(not service.ready(4, after.roundId), "late join accepted readiness")
        assert(
            not service.command(4, { action = "Surrender", roundId = after.roundId, sequence = 1 }),
            "late join gained an action"
        )
        setTime(120)
        service.step()
        assert(service.snapshot().phase == "Active", "surviving roster did not reveal")
        assert(#released == 1, "reveal released the same life again")
    end)
    test("P24 losing either side at arrival cancels reveal and permits a clean later round", function()
        for _, expected in { "OperatorForfeit", "GroundDeparted", "GroundEliminated" } do
            local service, deploy, setTime = fixture(2, 120, 20)
            local state = deploy()
            local role = if expected == "OperatorForfeit" then "Gunship" else "Ground"
            local subject = 0
            for id, member in state.members do
                if member.role == role then
                    subject = id
                end
            end
            setTime(120)
            if expected == "GroundEliminated" then
                assert(service.eliminate(subject, state.roundId), "pre-arrival death was rejected")
            else
                service.leave(subject)
            end
            service.step(function()
                error("terminal scatter ran damage")
            end)
            local ended = service.snapshot()
            assert(
                ended.phase == "Results" and ended.result and ended.result.reason == expected,
                "scatter did not commit " .. expected
            )
            assert(ended.intermissionUntil == 240, "intermission was not anchored to the result")
            assert(not service.damageAllowed(state.roundId), "canceled reveal opened combat")
            assert(service.beginReset() and service.finishReset(), "reset failed")
            service.join(subject)
            setTime(239.999)
            assert(not service.deploy(), "intermission was bypassed")
            setTime(240)
            local nextRound = deploy()
            assert(
                nextRound.roundId > state.roundId and nextRound.deadlineSeconds == 260,
                "next scatter reused the old countdown"
            )
            service.step()
            assert(
                not service.abort(state.roundId, "Stale") and not service.ready(subject, state.roundId),
                "old callbacks were accepted"
            )
            assert(service.snapshot().phase == "Scatter", "old-round work exposed the next aircraft")
        end
    end)
    test(
        "P23 committed round outcomes gate deployment until exactly 120 server seconds have elapsed",
        function()
            for _, ending in
                { "GroundEliminated", "Timeout", "OperatorForfeit", "AircraftDestroyed", "FixtureAbort" }
            do
                local service, active, setTime = fixture(2, 120)
                local state = active()
                local groundId, operatorId = 0, 0
                for id, member in state.members do
                    if member.role == "Ground" then
                        groundId = id
                    else
                        operatorId = id
                    end
                end
                local finishAt = if ending == "Timeout" then 110 else 105
                setTime(finishAt)
                if ending == "GroundEliminated" then
                    assert(service.eliminate(groundId, state.roundId), "fixture elimination failed")
                elseif ending == "OperatorForfeit" then
                    service.leave(operatorId)
                elseif ending == "AircraftDestroyed" then
                    assert(
                        service.proposeAircraftDestroyed(state.roundId),
                        "fixture destruction was not accepted"
                    )
                elseif ending == "FixtureAbort" then
                    assert(service.abort(state.roundId, ending), "fixture abort was not accepted")
                end
                service.step(nil, finishAt)
                local terminal = service.snapshot()
                assert(
                    terminal.phase == "Results" and terminal.result and terminal.result.reason == ending,
                    "incorrect fixture result"
                )
                assert(terminal.intermissionUntil == finishAt + 120, "deadline differs from result time")
                assert(not service.abort(state.roundId, "Duplicate"), "duplicate result was accepted")
                assert(service.beginReset() and service.finishReset(), "fixture reset failed")
                assert(
                    service.snapshot().result and service.snapshot().intermissionUntil == finishAt + 120,
                    "reset discarded intermission result or deadline"
                )
                service.leave(groundId)
                setTime(finishAt + 60)
                service.join(3)
                assert(not service.deploy(), "late join bypassed intermission")
                setTime(finishAt + 119.999)
                assert(not service.deploy(), "deployed before the exact deadline")
                setTime(finishAt + 120)
                if ending == "OperatorForfeit" then
                    assert(not service.deploy(), "deployed with one eligible player")
                    setTime(finishAt + 135)
                    service.join(groundId)
                end
                assert(service.deploy(), "wait continued after deadline and sufficient population")
                local nextState = service.snapshot()
                assert(
                    nextState.result == nil
                        and nextState.intermissionUntil == 0
                        and nextState.roundId > state.roundId,
                    "previous intermission leaked into next deployment"
                )
            end
        end
    )
    test("P23 canceled deployment without a result leaves no intermission", function()
        local service = fixture(2, 120)
        assert(service.deploy())
        service.leave(1)
        local waiting = service.snapshot()
        assert(
            waiting.phase == "Lobby" and waiting.intermissionUntil == 0 and waiting.result == nil,
            "cancel left an intermission"
        )
        service.join(3)
        assert(service.deploy(), "canceled deployment set a post-round wait")
    end)
    test("P23 owner teardown clears both active-abort and post-result intermissions", function()
        for _, alreadyInLobby in { false, true } do
            local service, active = fixture(2, 120)
            local state = active()
            assert(service.abort(state.roundId, "RuntimeStopped"), "test abort failed")
            assert(service.beginReset(), "test reset failed")
            if alreadyInLobby then
                assert(service.finishReset(), "test normal reset failed")
                assert(not service.deploy(), "test finite intermission did not gate deployment")
            end
            assert(service.finishReset(true), "runtime teardown failed")
            local stopped = service.snapshot()
            assert(
                stopped.phase == "Lobby" and stopped.result == nil and stopped.intermissionUntil == 0,
                "runtime teardown retained a stale result or intermission"
            )
            assert(service.deploy(), "stale intermission blocked restart")
        end
    end)
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
    test("production defaults keep one player waiting and activate a two-player match", function()
        local service = Match.new({
            minimumPlayers = Config.defaults.minPlayers,
            durationSeconds = Config.defaults.roundDurationSeconds,
            seed = 1,
        }, {
            now = function()
                return 100
            end,
            releaseLife = function() end,
        })
        service.join(1)
        assert(not service.deploy(), "one player cannot deploy")
        local waiting = service.snapshot()
        assert(waiting.phase == "Lobby" and waiting.roundId == 0, "solo lobby advanced")

        service.join(2)
        assert(service.deploy(), "two players must deploy with production defaults")
        local deploying = service.snapshot()
        assert(service.ready(operator(deploying), deploying.roundId), "operator must be able to ready")
        assert(service.ready(ground(deploying), deploying.roundId), "Ground player must be able to ready")
        assert(service.activate(), "the two ready players must be able to start")
        local active = service.snapshot()
        assert(active.phase == "Active" and active.deadlineSeconds == 700, "wrong active phase or deadline")
    end)
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
    test("model removal during deployment follows roster cancellation or a setup abort", function()
        for _, departing in { true, false } do
            local service = fixture(2)
            assert(service.deploy(), "expected deployment")
            local state = service.snapshot()
            for id in state.members do
                assert(service.ready(id, state.roundId), "fixture member did not ready")
            end
            local id = ground(state)
            assert(service.characterRemoved(id, state.roundId), "deployment removal rejected")
            assert(not service.snapshot().members[id].ready, "removed model retained readiness")
            if departing then
                service.leave(id)
                local canceled = service.snapshot()
                assert(canceled.phase == "Lobby" and canceled.result == nil, "roster loss did not cancel")
            else
                assert(not service.activate(), "deployment activated with an invalid model")
                local failed = service.snapshot()
                local result = assert(failed.result, "deployment did not abort")
                assert(
                    failed.phase == "Results"
                        and result.winner == "None"
                        and result.reason == "CharacterRemovedDuringDeployment",
                    "invalid setup created a competitive result"
                )
            end
        end
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
    test("P25 A2 lethal mixed-damage batch preserves rocket credit across clock rollover", function()
        local service, active, advance = fixture(2)
        local state = active()
        local id = ground(state)
        local credit = { userId = id, weapon = "RocketLauncher", shotId = "rocket:1:7" }
        local health = AircraftHealth.new()
        assert(health.reset(state.roundId, 1), "one-Ground roster health")
        for index = 1, 6 do
            assert(
                health.impact(state.roundId, "rocket:1:" .. index, "RocketLauncher", true) == 150,
                "rocket prefix"
            )
        end
        advance(109.999)
        service.step(function(seconds)
            assert(seconds == 109.999, "batch time differs from deadline sample")
            -- A slow frame must resolve all accepted damage at its captured time.
            advance(110)
            assert(service.damageAllowed(state.roundId), "clock rollover rejected valid damage")
            assert(service.eliminate(id, state.roundId), "same-step ground elimination rejected")
            assert(health.impact(state.roundId, "rifle:1", "M7", true) == 5, "rifle failed in batch")
            local amount, lethal = health.impact(state.roundId, credit.shotId, "RocketLauncher", true)
            assert(amount == 95 and lethal, "rocket failed to finish the mixed-damage batch")
            assert(
                not health.impact(state.roundId, credit.shotId, "RocketLauncher", true),
                "duplicate damage"
            )
            assert(service.proposeAircraftDestroyed(state.roundId, credit), "valid lethal rocket rejected")
            assert(not service.proposeAircraftDestroyed(state.roundId), "duplicate destruction accepted")
            credit.userId = 99
        end)
        local resolved = service.snapshot()
        local result = assert(resolved.result, "the pre-deadline batch did not commit")
        assert(result.winner == "Ground" and result.reason == "AircraftDestroyed", "wrong tie result")
        assert(
            result.userId == id and result.weapon == "RocketLauncher" and result.shotId == "rocket:1:7",
            "lethal hit attribution changed"
        )
        service.step(function()
            error("terminal batch reentered")
        end)
        assert(service.snapshot().revision == resolved.revision, "committed result changed")
    end)
    test("deadline equality and later steps skip queued damage and commit timeout", function()
        for _, expiredAt in { 110, 111 } do
            local service, active, advance = fixture(2)
            local state = active()
            advance(expiredAt)
            service.step(function()
                error("expired batch ran damage")
            end)
            local ended = service.snapshot()
            local result = assert(ended.result, "deadline did not commit a result")
            assert(
                result.winner == "Gunship" and result.reason == "Timeout",
                "deadline produced the wrong result"
            )
            assert(
                result.userId == operator(state) and result.shotId == nil,
                "timeout incorrectly attributed damage"
            )
            assert(not service.damageAllowed(state.roundId), "expired round still accepts damage")
            assert(
                not service.proposeAircraftDestroyed(state.roundId),
                "expired round accepted an aircraft destruction claim"
            )
            assert(
                service.snapshot().revision == ended.revision,
                "rejected damage changed the terminal revision"
            )
        end
    end)
    test("earlier total ground elimination closes the round to later rocket damage", function()
        local service, active, advance = fixture(2)
        local state = active()
        service.step(function()
            assert(service.eliminate(ground(state), state.roundId))
        end)
        local ended = service.snapshot()
        local result = assert(ended.result, "ground elimination did not commit a result")
        assert(
            result.reason == "GroundEliminated" and result.userId == operator(state),
            "ground elimination assigned wrong reason or credit"
        )
        advance(101)
        assert(
            not service.damageAllowed(state.roundId) and not service.proposeAircraftDestroyed(state.roundId),
            "earlier elimination allowed late aircraft damage"
        )
        assert(service.snapshot().revision == ended.revision, "late damage changed the terminal revision")
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
        assert(
            result and result.winner == "Gunship" and result.reason == "GroundDeparted",
            "ground departure did not award the surviving gunship"
        )
        assert(result.userId == operator(state) and result.shotId == nil, "departure invented a hit")
        for _, release in released do
            assert(not release.recover, "expected not release.recover")
        end
    end)
    test("native model removal and roster departure can arrive in either order in one step", function()
        for _, removalFirst in { true, false } do
            local service, active, _, released = fixture(2)
            local state = active()
            local id = ground(state)
            if removalFirst then
                assert(service.characterRemoved(id, state.roundId), "model loss was rejected")
                assert(service.snapshot().members[id].life == "Eliminated", "model loss left an active life")
                assert(not service.characterRemoved(id, state.roundId), "model loss duplicated")
                assert(
                    not service.command(id, { roundId = state.roundId, sequence = 1, action = "Surrender" }),
                    "lost character retained command authority"
                )
                service.leave(id)
            else
                service.leave(id)
                assert(
                    not service.characterRemoved(id, state.roundId),
                    "departed player reported a live loss"
                )
            end
            service.step()
            local result = assert(service.snapshot().result, "departure did not commit")
            assert(result.reason == "GroundDeparted" and result.userId == operator(state), "wrong cause")
            assert(#released == 2, "roster did not release each life once")
        end
    end)
    test("confirmed death is retained across native model removal and later player departure", function()
        for _, removalFirst in { true, false } do
            local service, active = fixture(2)
            local state = active()
            local id = ground(state)
            if removalFirst then
                assert(service.characterRemoved(id, state.roundId), "model loss was rejected")
                assert(service.eliminate(id, state.roundId), "confirmed death did not refine model loss")
            else
                assert(service.eliminate(id, state.roundId), "confirmed death was rejected")
                assert(not service.characterRemoved(id, state.roundId), "model removal changed known death")
            end
            service.leave(id)
            service.leave(operator(state))
            service.step()
            local result = assert(service.snapshot().result, "death did not commit")
            assert(result.reason == "GroundEliminated" and result.winner == "Gunship", "death cause lost")
        end
    end)
    test("raw model removal alone eliminates; a later departure cannot rewrite the result", function()
        local service, active = fixture(2)
        local state = active()
        local id = ground(state)
        assert(service.characterRemoved(id, state.roundId), "model loss was rejected")
        service.step()
        local before = assert(service.snapshot().result, "raw removal did not commit")
        assert(before.reason == "GroundEliminated", "raw model removal did not eliminate")
        service.leave(id)
        service.leave(operator(state))
        service.step()
        local after = assert(service.snapshot().result, "terminal result disappeared")
        assert(
            after.reason == before.reason and after.winner == before.winner and after.userId == before.userId,
            "later departure rewrote the result"
        )
    end)
    test("empty server has no winner; a physical kill takes precedence over operator departure", function()
        local empty, deployEmpty = fixture(2)
        local emptyRound = deployEmpty()
        assert(empty.characterRemoved(ground(emptyRound), emptyRound.roundId), "departure model removal")
        empty.leave(operator(emptyRound))
        empty.leave(ground(emptyRound))
        empty.step()
        local emptyResult = assert(empty.snapshot().result, "empty server did not commit a result")
        assert(
            emptyResult.winner == "None" and emptyResult.reason == "EmptyServer",
            "empty server awarded a competitive result"
        )
        assert(
            emptyResult.userId == nil and emptyResult.shotId == nil,
            "empty-server cleanup awarded a hit or credit"
        )

        local eliminated, deployElimination = fixture(2)
        local finalRound = deployElimination()
        eliminated.leave(operator(finalRound))
        eliminated.step(function()
            assert(eliminated.eliminate(ground(finalRound), finalRound.roundId))
        end)
        local eliminationResult =
            assert(eliminated.snapshot().result, "ground elimination did not commit a result")
        assert(
            eliminationResult.winner == "Gunship" and eliminationResult.reason == "GroundEliminated",
            "ground elimination lost precedence to operator departure"
        )
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
