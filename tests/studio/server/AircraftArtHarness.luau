--!strict
--[=[
    AircraftArtHarness extends the two-client arrival fixture for P28.
    It observes one real orbit and exercises production gunship and rifle intents.
    Destruction uses the runtime's native server rocket sweep, with no health writes.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Server = game:GetService("ServerScriptService").Server
local GameRuntime = require(Server.GameRuntime)
local MatchService = require(Server.MatchService)
local AircraftArtHarness = {}

type Record = { [string]: unknown }
export type Fixture = {
    runtime: GameRuntime.Controller,
    state: MatchService.Snapshot,
    operator: Player,
    ground: Player,
    equip: (Player, string) -> Tool,
    place: (Player, Vector3) -> (),
    probe: (Player, string, Record) -> unknown,
    intent: (Player, string, string, Record) -> (),
    operatorPayload: (number, number, Vector3, string?) -> Record,
    waitFor: (() -> boolean, string, number?) -> (),
    check: (string, () -> ()) -> (),
    observations: { unknown },
}

local function plane(): (Model, BasePart)
    local model = workspace:FindFirstChild("Aircraft")
    local root = if model then model:FindFirstChild("Hitbox") else nil
    assert(model and model:IsA("Model") and root and root:IsA("BasePart"), "aircraft rig unavailable")
    return model, root
end

local function onePlane(): boolean
    local count = 0
    for _, child in workspace:GetChildren() do
        if child.Name == "Aircraft" then
            count += 1
        end
    end
    return count == 1
end

-- Both clients observe the matching generation. Only the first round needs
-- an entire orbit; the second exercises the normal fresh replay presentation.
function AircraftArtHarness.run(fixture: Fixture, replay: boolean)
    local runtime, roundId = fixture.runtime, fixture.state.roundId
    local status = ReplicatedStorage.AircraftState
    local epoch = status:GetAttribute("EpochSeconds")
    assert(type(epoch) == "number", "missing aircraft arrival epoch")
    local function view(player: Player, role: string, fov: number, track: boolean): unknown
        return fixture.probe(player, "AircraftArt", {
            roundId = roundId,
            role = role,
            fov = fov,
            track = track,
        })
    end
    local function append(observation: unknown)
        table.insert(fixture.observations, observation)
    end
    fixture.check(
        if replay
            then "P28 A3 fresh artwork and both roles replay at full health"
            else "P28 A2 authored aircraft reveals once on both actual clients",
        function()
            local model, root = plane()
            local expected = runtime.aircraft.sample(workspace:GetServerTimeNow() - epoch)
            assert(
                onePlane() and model:GetAttribute("RoundId") == roundId,
                "wrong revealed aircraft generation"
            )
            assert(
                (root.Position - expected.Position).Magnitude < 3,
                "reveal does not match the canonical orbit"
            )
            assert(
                status:GetAttribute("Health") == 1000 and status:GetAttribute("MaxHealth") == 1000,
                "aircraft did not reset to roster health"
            )
            append(view(fixture.ground, "Ground", 0, not replay))
            append(view(fixture.operator, "Gunship", 30, false))
        end
    )
    if replay then
        return
    end

    fixture.check("P28 A2 both zooms mask the rig and fire from the matching visible bore", function()
        local model, root = plane()
        local airframe = model:FindFirstChild("Airframe")
        assert(airframe and airframe:IsA("Model"), "authored airframe missing")
        local muzzleProbe = workspace:FindFirstChild("CombatMuzzleProbe", true)
        assert(muzzleProbe and muzzleProbe:IsA("BasePart"), "production muzzle probe missing")
        for sequence, weapon in { "GAU23", "M102" } do
            fixture.intent(fixture.operator, "AircraftState", "SelectWeapon", {
                roundId = roundId,
                sequence = sequence,
                weapon = weapon,
            })
            fixture.waitFor(function()
                return runtime.aircraft.weapon() == weapon
            end, "selected " .. weapon, 4)
            append(view(fixture.operator, "Gunship", if weapon == "GAU23" then 30 else 40, false))
            local bore = airframe:FindFirstChild(weapon .. " dark bore")
            local muzzle = runtime.aircraft.muzzle(weapon)
            assert(
                bore and bore:IsA("BasePart") and muzzle and (bore.Position - muzzle).Magnitude < 0.02,
                "muzzle does not match authored visible bore"
            )
            local localBore = root.CFrame:PointToObjectSpace(bore.Position)
            local previousProbe = muzzleProbe.Position
            local fireStart = workspace:GetServerTimeNow()
            fixture.intent(
                fixture.operator,
                "AircraftState",
                "FireWeapon",
                fixture.operatorPayload(roundId, sequence, root.Position, weapon)
            )
            fixture.waitFor(function()
                return (muzzleProbe.Position - previousProbe).Magnitude > 0.5
            end, "production shot left " .. weapon, 5)
            local now = workspace:GetServerTimeNow()
            local nearest = math.huge
            for index = 0, 20 do
                local pose = runtime.aircraft.sample(fireStart - epoch + (now - fireStart) * index / 20)
                nearest =
                    math.min(nearest, (pose:PointToWorldSpace(localBore) - muzzleProbe.Position).Magnitude)
            end
            assert(nearest < 2, "shot was spawned away from the orbiting " .. weapon .. " bore")
            append({ weapon = weapon, matchedMuzzleErrorStuds = nearest })
        end
    end)

    fixture.check(
        "P28 A2 real Ground client sees four moving rotors and the entire 90-second orbit",
        function()
            local period = status:GetAttribute("PeriodSeconds")
            assert(period == 90, "canonical orbit period changed")
            for segment = 1, 6 do
                fixture.waitFor(function()
                    return workspace:GetServerTimeNow() - epoch >= segment * period / 6
                end, "orbit sector " .. tostring(segment), 17)
                local model, root = plane()
                assert(
                    onePlane() and model:GetAttribute("RoundId") == roundId,
                    "aircraft duplicated during orbit"
                )
                local elapsed = workspace:GetServerTimeNow() - epoch
                local expected = runtime.aircraft.sample(elapsed)
                assert(
                    (root.Position - expected.Position).Magnitude < 4
                        and root.CFrame.LookVector:Dot(expected.LookVector) > 0.995,
                    "orbit or heading drifted"
                )
                append(view(fixture.ground, "Ground", 0, true))
            end
            fixture.probe(fixture.ground, "ReleaseAircraftArt", {})
        end
    )

    fixture.check(
        "P28 A2 real Ground rifle damages a visible solid and misses outside the silhouette",
        function()
            local _, root = plane()
            local radial = Vector3.new(root.Position.X, 0, root.Position.Z).Unit
            fixture.place(fixture.ground, radial * 330 + Vector3.yAxis * 45)
            fixture.equip(fixture.ground, "M-7 rifle")
            local function fire(sequence: number, offset: Vector3): Record
                local now = workspace:GetServerTimeNow()
                local pose = runtime.aircraft.sample(now - epoch + 0.05)
                local target = pose:PointToWorldSpace(offset)
                fixture.intent(fixture.ground, "AircraftState", "GroundFire", {
                    roundId = roundId,
                    sequence = sequence,
                    weapon = "M7",
                    x = target.X,
                    y = target.Y,
                    z = target.Z,
                })
                local shot: Record? = nil
                fixture.waitFor(function()
                    local raw = status:GetAttribute("GroundShot")
                    if type(raw) ~= "string" then
                        return false
                    end
                    local data = HttpService:JSONDecode(raw) :: Record
                    if data.sequence == sequence and data.roundId == roundId then
                        shot = data
                        return true
                    end
                    return false
                end, "authoritative M-7 shot " .. tostring(sequence), 5)
                return assert(shot, "shot observation missing")
            end
            assert(
                fire(1, Vector3.zero).aircraftHit == true and status:GetAttribute("Health") == 995,
                "real rifle shot on the visible hull did not deal five damage"
            )
            task.wait(0.25)
            assert(
                fire(2, Vector3.new(35, 0, 0)).aircraftHit == false and status:GetAttribute("Health") == 995,
                "rifle shot outside the wingtip awarded damage"
            )
        end
    )

    fixture.check("P28 A3 native rocket sweeps destroy the aircraft and commit Ground victory", function()
        local _, root = plane()
        local original = root.CFrame
        local start = original:PointToWorldSpace(Vector3.new(0, -14, 0))
        local sweep = original.UpVector * 29
        for index = 1, 7 do
            local contact, applied = runtime.groundCombat.rocketCast(
                roundId,
                "P28ArtSweep:" .. tostring(index),
                start,
                sweep,
                fixture.ground.UserId
            )
            assert(contact and applied, "native direct rocket sweep failed at hit " .. tostring(index))
        end
        fixture.waitFor(function()
            return runtime.rounds.match.snapshot().phase == "Results"
        end, "aircraft destroyed", 5)
        local result = assert(runtime.rounds.match.snapshot().result, "missing aircraft destruction result")
        assert(
            result.reason == "AircraftDestroyed" and status:GetAttribute("Health") == 0,
            "aircraft depletion did not commit the expected result"
        )
        append({ reason = result.reason, health = status:GetAttribute("Health") })
    end)
end
return AircraftArtHarness
