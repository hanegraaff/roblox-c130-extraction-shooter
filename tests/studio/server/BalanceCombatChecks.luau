--!strict
--[=[
    Test-only P26 native weapon and panel checks. Drives mapped game remotes from
    actual clients. Trusted avatar placement and direct structural outcomes isolate
    the map, material and persistence checks from gunship flight and camera input.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Server = game:GetService("ServerScriptService").Server
local Runtime = require(Server.GameRuntime)
local Schema = require(ReplicatedStorage.Shared.BalanceSchema)
local Presentation = require(ReplicatedStorage.Shared.PlayerPresentation)
local Fixture = require(script.Parent.P11CombatFixture)
local Checks = {}
type Bag = { [string]: unknown }
type Probe = (Player, string, Bag) -> unknown
type Context = {
    runtime: Runtime.Controller,
    owner: Player,
    tester: Player,
    probe: Probe,
    waitFor: (() -> boolean, string, number?) -> (),
    values: Schema.Values,
}

-- Structural probes start on fresh registry state. All damage, material changes
-- and replicated appearances come from the real server DestructionRuntime.
function Checks.panels(ctx: Context)
    local runtime, values = ctx.runtime, ctx.values
    local panelList = Fixture.outpost()
    local wall, roof = panelList[1], panelList[2]
    assert(wall and roof and wall ~= roof, "two Outpost panel identities required")
    local round = runtime.rounds.match.snapshot().roundId
    local shot = 0
    local firedAt = workspace:GetServerTimeNow()
    local function impact(panel: Instance, weapon: string)
        shot += 1
        assert(
            runtime.destruction.resolve({
                roundId = round,
                shotId = shot,
                weapon = weapon,
                firedAt = firedAt,
                panelId = panel.Name,
            }),
            "panel contact rejected"
        )
        runtime.destruction.flush(workspace:GetServerTimeNow())
    end
    local function clients(panel: Instance, tier: string)
        ctx.waitFor(function()
            return ctx.probe(ctx.owner, "Panel", { name = panel.Name }) == tier
                and ctx.probe(ctx.tester, "Panel", { name = panel.Name }) == tier
        end, "replicated " .. values.panelDamage .. " / " .. tier)
    end
    impact(wall, "M102")
    if values.panelDamage == "Low" then
        clients(wall, "Heavy")
        impact(wall, "M102")
    end
    clients(wall, "Total")
    local fullSeconds = if values.panelDamage == "Low" then 4 elseif values.panelDamage == "High" then 1 else 2
    impact(roof, "GAU23")
    firedAt += values.gauCadence
    impact(roof, "GAU23")
    clients(roof, "Light")
    local before = assert(runtime.destruction.snapshot(roof.Name), "missing damaged panel")
    runtime.destruction.interrupt()
    firedAt += 10
    impact(roof, "GAU23")
    local after = assert(runtime.destruction.snapshot(roof.Name), "missing interrupted panel")
    assert(after.sustainedSeconds == before.sustainedSeconds, "interruption healed or credited paused time")
    for interval = 2, math.ceil(fullSeconds / values.gauCadence) do
        firedAt += values.gauCadence
        impact(roof, "GAU23")
        local earned = interval * values.gauCadence
        local expected = if earned >= fullSeconds
            then "Total"
            elseif earned >= fullSeconds / 2 then "Heavy"
            else "Light"
        assert(roof:GetAttribute("DamageAppearance") == expected, "wrong tuned 30mm threshold")
    end
    clients(roof, "Total")
end

-- Exercises both Ground weapons and both aircraft weapons at non-default
-- settings. Actual HP, weapon deadlines and role HUD text are the witnesses.
function Checks.weapons(ctx: Context)
    local runtime, values, probe = ctx.runtime, ctx.values, ctx.probe
    local round = runtime.rounds.match.snapshot().roundId
    local gunner = if ctx.owner:GetAttribute("Role") == "Gunship" then ctx.owner else ctx.tester
    local ground = if gunner == ctx.owner then ctx.tester else ctx.owner
    local function send(player: Player, remote: string, body: Bag)
        probe(player, "Weapon", { remote = remote, body = body })
    end
    local function aircraftHP(hp: number)
        local text = Presentation.aircraftText(hp, values.aircraftHealthPerGround, false)
        ctx.waitFor(function()
            for _, p in { gunner, ground } do
                local view = probe(p, "Observe", {}) :: Bag
                if view.aircraftCurrent ~= hp or view.aircraftHUD ~= text then
                    return false
                end
            end
            return true
        end, "both health bars at " .. tostring(hp))
    end
    local character = assert(ground.Character, "missing Ground avatar")
    local hum = assert(character:FindFirstChildOfClass("Humanoid"), "missing Ground humanoid")
    local regen = character:FindFirstChild("Health")
    if regen and regen:IsA("BaseScript") then
        regen.Disabled = true
    end
    local exposed = Vector3.new(0, 30, 0)
    Fixture.pose(runtime, ground, exposed)
    local root = character:FindFirstChild("HumanoidRootPart")
    assert(root and root:IsA("BasePart"), "missing Ground root")
    local rifle = character:FindFirstChild("M-7 rifle")
    if not rifle then
        Fixture.equip(ground, "M-7 rifle")
    end
    local before = values.aircraftHealthPerGround
    local rifleIntent = Fixture.rifle(round, 1, runtime.aircraft.position())
    send(ground, rifleIntent.remote, rifleIntent.body)
    before -= values.m7Damage
    aircraftHP(before)
    local reloadStart = workspace:GetServerTimeNow()
    send(ground, "GroundReload", { roundId = round, sequence = 2 })
    local reloadDeadline = 0
    ctx.waitFor(function()
        reloadDeadline = runtime.groundCombat.readiness(ground).reloadUntil
        return reloadDeadline > 0
    end, "M-7 reload starts")
    assert(
        reloadDeadline >= reloadStart + values.m7Reload - 0.05
            and reloadDeadline <= workspace:GetServerTimeNow() + values.m7Reload + 0.05,
        "wrong M-7 reload"
    )
    local function gun(weapon: string, sequence: number)
        send(gunner, "SelectWeapon", { roundId = round, sequence = sequence, weapon = weapon })
        ctx.waitFor(function()
            return runtime.aircraft.weapon() == weapon
        end, "selected " .. weapon)
        local intent = assert(Fixture.pointShot(runtime, weapon, root.Position, sequence), "no exposed aim")
        send(gunner, intent.remote, intent.body)
    end
    gun("GAU23", 1)
    ctx.waitFor(function()
        return hum.Health == values.groundHealth - values.gauDamage
    end, "actual tuned 30mm damage", 6)
    gun("M102", 2)
    ctx.waitFor(function()
        return hum.Health == values.groundHealth - values.gauDamage - values.m102Damage
    end, "actual tuned 105mm damage", 6)
    ctx.waitFor(function()
        local data = ReplicatedStorage.AircraftState:GetAttribute("Readiness")
        if type(data) ~= "string" then
            return false
        end
        local status = HttpService:JSONDecode(data).M102
        return status.ammo == 0
            and math.abs(status.reloadUntil - status.nextFire + values.m102Cadence - values.m102Reload)
                < 1e-5
    end, "M102 independent cooldown")
    local function launcher(site: string, op: string, sequence: number, target: Vector3?)
        local slot = runtime.launcher.snapshot(site)
        local body: Bag = { roundId = round, launcherId = slot.launcherId, sequence = sequence }
        if target then
            body.x, body.y, body.z = target.X, target.Y, target.Z
        end
        send(ground, op, body)
    end
    local slot = runtime.launcher.snapshot("Hangar")
    Fixture.pose(runtime, ground, Vector3.new(slot.position.x, slot.position.y + 2, slot.position.z))
    launcher("Hangar", "Pickup", 1)
    ctx.waitFor(function()
        return runtime.launcher.snapshot("Hangar").ownerId == ground.UserId
    end, "launcher pickup")
    if not character:FindFirstChild("Rocket launcher") then
        Fixture.equip(ground, "Rocket launcher")
    end
    local origin = Vector3.new(330, 30, 0)
    Fixture.pose(runtime, ground, origin)
    local acceptedAfter = workspace:GetServerTimeNow()
    launcher("Hangar", "Fire", 2, origin + Vector3.yAxis * 300)
    ctx.waitFor(function()
        return runtime.launcher.snapshot("Hangar").ammo == 0
    end, "launcher fired")
    local deadline = runtime.launcher.snapshot("Hangar").readyAt
    assert(
        deadline >= acceptedAfter + values.launcherReload - 0.05
            and deadline <= workspace:GetServerTimeNow() + values.launcherReload + 0.05,
        "wrong launcher reload"
    )
    local idle = runtime.launcher.snapshot("Radar")
    assert(idle.ammo == 1 and idle.readyAt == 0, "independent launcher cooled down")
    local pos = runtime.aircraft.position()
    assert(
        runtime.groundCombat.rocketSweep(round, "p26-rocket", pos + Vector3.yAxis * 50, -Vector3.yAxis * 100),
        "native rocket sweep missed"
    )
    aircraftHP(before - values.rocketDamage)
end
return Checks
