--!strict
-- P10 A1/R04/R12: deterministic role, cue, target, rejection and readiness views.
type API = typeof(require(game:GetService("ReplicatedStorage").Shared.PlayerPresentation))

local function expect(actual: unknown, expected: unknown)
    assert(
        actual == expected,
        string.format("expected %s, observed %s", tostring(expected), tostring(actual))
    )
end

return function(test: (string, () -> ()) -> (), candidate: unknown)
    local rules = candidate :: API

    test("Round presentation distinguishes every phase, living role and local preview", function()
        expect(rules.view("Lobby", "Waiting", "Waiting", nil), "Waiting")
        expect(rules.view("Deploying", "Ground", "Alive", nil), "Deploying")
        expect(rules.view("Active", "Ground", "Alive", nil), "Ground")
        expect(rules.view("Active", "Gunship", "Alive", nil), "Operator")
        expect(rules.view("Results", "Ground", "Alive", nil), "Results")
        expect(rules.view("Resetting", "Gunship", "Alive", nil), "Resetting")
        expect(rules.view("Lobby", nil, nil, "Ground"), "GroundPreview")
        expect(rules.view("Lobby", nil, nil, "Gunship"), "OperatorPreview")
        expect(rules.view("Active", "Spectator", "Spectating", "Gunship"), "Spectator")
    end)

    test("Elimination and late arrival keep distinct headings without active controls", function()
        local eliminated = rules.view("Active", "Ground", "Eliminated", nil)
        local late = rules.view("Active", "Spectator", "Spectating", nil)
        expect((eliminated == "Spectator" and late == "Spectator"), true)
        expect(rules.guide("Spectator", true), "ELIMINATED • SPECTATING")
        expect(rules.guide("Spectator", false), "SPECTATING")
        expect(rules.view("Active", "Gunship", "Eliminated", nil), "Spectator")
        expect(rules.view("Unknown", {}, nil, "Gunship"), "Waiting")
    end)

    test("All competitive results have plain-language winning team and reason", function()
        local cases = {
            { "Ground", "AircraftDestroyed", "Ground team wins", "The C-130 was destroyed." },
            { "Ground", "OperatorForfeit", "Ground team wins", "The C-130 operator left the round." },
            { "Gunship", "GroundEliminated", "C-130 wins", "All ground players were eliminated." },
            { "Gunship", "GroundDeparted", "C-130 wins", "The last ground player left the round." },
            { "Gunship", "Timeout", "C-130 wins", "The C-130 survived until time ran out." },
        }
        for _, case in cases do
            local result = { roundId = 2, winner = case[1], reason = case[2] }
            expect(rules.resultText(result, 2), case[3] .. "\n" .. case[4])
        end
    end)

    test(
        "Round result ignores stale commits and gives unknown or canceled reasons a readable label",
        function()
            local result = { roundId = 5, winner = "None", reason = "NoParticipants" }
            expect(rules.resultText(result, 6), "Round ended")
            expect(rules.resultText(nil, 5), "Round ended")
            expect(rules.resultText(result, 5), "Round ended\nBoth sides left the round.")
            result.reason = "Unrecognized"
            expect(rules.resultText(result, 5), "Round ended\nThe round was canceled.")
        end
    )

    test("Aircraft health and time represent depletion, destroyed state and unavailable facts", function()
        expect(rules.aircraftText(200, 300, false), "C-130 HEALTH  200 / 300")
        expect(rules.aircraftText(0, 300, false), "C-130 DESTROYED")
        expect(rules.aircraftText(nil, nil, true), "C-130 DESTROYED")
        expect(rules.aircraftText(-1, 300, false), nil)
        expect(rules.aircraftText(math.huge, 300, false), nil)
        expect(rules.aircraftText(0 / 0, 300, false), nil)
        expect(rules.remaining(30.2, 0.3), 30)
        expect(rules.remaining(10, 12), 0)
        expect(rules.remaining(math.huge, 0), nil)
        expect(rules.remaining(nil, 0), nil)
    end)

    test("Spectator cycles a stable unsorted roster in either direction and wraps", function()
        local alive = { 13, -2, 10 }
        expect(rules.spectatorTarget(alive, nil, 0), -2)
        expect(rules.spectatorTarget(alive, 13, 1), -2)
        expect(rules.spectatorTarget(alive, -2, -1), 13)
        expect(rules.spectatorTarget(alive, 10, 0), 10)
        expect(rules.spectatorTarget(alive, 10, 1), 13)
        expect(rules.spectatorTarget(alive, 10, -1), -2)
        expect((alive[1] == 13 and alive[2] == -2 and alive[3] == 10), true)
    end)

    test("A lost spectator target advances to a survivor or the no-target overview", function()
        expect(rules.spectatorTarget({ 10, 30 }, 20, 0), 30)
        expect(rules.spectatorTarget({ 10, 30 }, 30, 0), 30)
        expect(rules.spectatorTarget({ 10 }, 30, 0), 10)
        expect(rules.spectatorTarget({}, 10, 0), nil)
        expect(rules.spectatorTarget({}, 10, -1), nil)
    end)

    test("Launcher view announces availability, possession and recovery as readable text", function()
        expect(rules.launcherText("Available", false, true, nil), "LAUNCHER • E / PICK UP")
        expect(rules.launcherText("Available", false, false, nil), "LAUNCHER • available on the map")
        expect(rules.launcherText("Held", true, false, nil), "LAUNCHER • yours • G to drop")
        expect(rules.launcherText("Held", false, false, "Mira"), "LAUNCHER • carried by Mira")
        expect(rules.launcherText("Recovering", false, false, nil), "LAUNCHER • returning to the map")
        expect(rules.launcherText("Inactive", false, false, nil), "LAUNCHER • unavailable")
    end)

    test("Rejected Ground actions have corrective text without changing any state", function()
        expect(
            rules.groundRejection("Pickup", false, "Available", false, true, nil, 0),
            "Actions are available to living Ground players."
        )
        expect(
            rules.groundRejection("Pickup", true, "Available", false, false, nil, 0),
            "Move closer to pick up the launcher."
        )
        expect(
            rules.groundRejection("Pickup", true, "Held", true, false, nil, 0),
            "You already carry the launcher."
        )
        expect(rules.groundRejection("Pickup", true, "Available", false, true, nil, 0), nil)
        expect(
            rules.groundRejection("Drop", true, "Held", false, false, nil, 0),
            "You aren't carrying the launcher."
        )
        expect(rules.groundRejection("Drop", true, "Held", true, false, nil, 0), nil)
        expect(rules.groundRejection("Reload", true, nil, false, false, nil, 0), "Equip the M-7 to reload.")
        local reloading = { ammo = 29, reserve = 120, capacity = 30, reloadUntil = 4 }
        expect(
            rules.groundRejection("Reload", true, nil, false, false, reloading, 3),
            "M-7 reload is already in progress."
        )
        expect(rules.groundRejection("Reload", true, nil, false, false, reloading, 4), nil)
        expect((reloading.ammo == 29 and reloading.reloadUntil == 4 and reloading.reserve == 120), true)
        reloading.ammo = 30
        expect(
            rules.groundRejection("Reload", true, nil, false, false, reloading, 4),
            "The M-7 magazine is full."
        )
    end)

    test("Per-weapon cooldown and reload are visible at the server-clock boundary", function()
        local readiness = { ammo = 4, reloadUntil = 0, nextFire = 5.5 }
        expect(rules.weaponText(readiness, 5.0), "4 rounds • Cooldown 0.5s")
        expect(rules.weaponText(readiness, 5.5), "4 rounds ready")
        readiness.ammo = 1
        expect(rules.weaponText(readiness, 5.0), "1 round • Cooldown 0.5s")
        expect(rules.weaponText(readiness, 5.5), "1 round ready")
        readiness.ammo = 0
        expect(rules.weaponText(readiness, 5.5), "0 rounds ready")
        readiness.reloadUntil = 8
        expect(rules.weaponText(readiness, 5.0), "Reload 3.0s")
        expect(rules.weaponText(nil, 5.0), "Readiness updating")
    end)

    test("Presentation intensity changes are bounded and cyclic in both directions", function()
        expect(rules.cycleIntensity("Full", false), "Off")
        expect(rules.cycleIntensity("Off", false), "Reduced")
        expect(rules.cycleIntensity("Reduced", false), "Full")
        expect(rules.cycleIntensity("Full", true), "Reduced")
        expect(rules.cycleIntensity("Reduced", true), "Off")
        expect(rules.cycleIntensity("Off", true), "Full")
        expect((rules.intensity("Off") == 0 and rules.intensity("Full") == 1), true)
        expect((rules.intensity("Reduced") > 0 and rules.intensity("Reduced") < 1), true)
    end)
end
