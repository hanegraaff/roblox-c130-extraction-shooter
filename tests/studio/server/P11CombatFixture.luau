--!strict
-- Test-only targeting and avatar positioning over the reconstructed battlefield.
-- Helpers depend on the real GameRuntime, map rules and Workspace. All poses
-- are trusted fixture corrections; all shots still travel through live remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local GameRuntime = require(Server.GameRuntime)
local CombatViewRules = require(Server.CombatViewRules)
local Pan = require(ReplicatedStorage.Shared.AircraftPanRules)
local MapRules = require(ReplicatedStorage.Shared.MapRules)
local AircraftRules = require(ReplicatedStorage.Shared.AircraftRules)
local CombatFixture = {}
export type Intent = { owner: string, remote: string, body: { [string]: unknown }, repetitions: number? }
local aspect = 16 / 9
local map = MapRules.defaults

-- Returns a fresh transport envelope. Sequence and coordinates remain subject
-- to production authorization.
function CombatFixture.rifle(roundId: number, sequence: number, point: Vector3): Intent
    return {
        owner = "AircraftState",
        remote = "GroundFire",
        body = {
            roundId = roundId,
            sequence = sequence,
            weapon = "M7",
            x = point.X,
            y = point.Y,
            z = point.Z,
        },
    }
end

-- Freeze the actual avatar at a known, supported fixture position. Removes
-- airborne motion from repeated measurements; movement is exercised separately.
function CombatFixture.pose(runtime: GameRuntime.Controller, player: Player, point: Vector3)
    local character = assert(player.Character, "missing fixture character")
    local root = character:FindFirstChild("HumanoidRootPart")
    assert(root and root:IsA("BasePart"), "missing fixture root")
    root.Anchored = true
    character:PivotTo(CFrame.new(point))
    assert(runtime.groundCombat.trustCorrection(player), "fixture pose outside trusted bounds")
end

-- Equip the real Tool through Humanoid rather than manufacturing authority.
function CombatFixture.equip(player: Player, name: string)
    local backpack = assert(player:FindFirstChildOfClass("Backpack"), "missing fixture backpack")
    local tool = backpack:FindFirstChild(name)
    local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
    assert(humanoid and tool and tool:IsA("Tool"), "cannot equip " .. name)
    humanoid:EquipTool(tool)
    assert(tool.Parent == player.Character, "fixture equip did not finish")
end

-- Resolve only genuine solid geometry; callers use separate actual rays to
-- establish hits. Search fixed interpolation points between the geometric target
-- and validated home focus; stop at the first permitted view.
local function gunship(
    runtime: GameRuntime.Controller,
    weapon: string,
    point: Vector3,
    sequence: number
): Intent?
    local camera = runtime.aircraft.position()
    local projected = camera + (point - camera) * (camera.Y / (camera.Y - point.Y))
    local x = math.clamp(projected.X, -map.radiusStuds, map.radiusStuds)
    local z = math.clamp(projected.Z, -map.radiusStuds, map.radiusStuds)
    local preferred = assert(Pan.recenter(map, aspect, AircraftRules.defaults.fov105mm), "home focus missing")
    local body: { [string]: unknown } = {
        roundId = runtime.rounds.match.snapshot().roundId,
        sequence = sequence,
        weapon = weapon,
        x = point.X,
        y = point.Y,
        z = point.Z,
        aspect = aspect,
        cameraX = camera.X,
        cameraZ = camera.Z,
    }
    for index = 0, 16 do
        local fraction = index / 16
        body.focusX, body.focusZ = x + (preferred.x - x) * fraction, z + (preferred.z - z) * fraction
        if CombatViewRules.validate(body, map, weapon, camera.X, camera.Z) then
            return { owner = "AircraftState", remote = "FireWeapon", body = body }
        end
    end
    return nil
end

-- Stable ordered registry for deterministic panel preferences. Compatible with
-- stage swaps because panel identity Models persist until a map reset.
function CombatFixture.outpost(): { Instance }
    local outpost = workspace.World.Battlefield.Buildings.Outpost.Outpost_Panels:GetChildren()
    table.sort(outpost, function(a, b)
        return a.Name < b.Name
    end)
    return outpost
end

-- Preserve a preferred panel across shots when visible. If the orbit or an
-- opening hides it, visit the remaining current Outpost registry in stable
-- cyclic order. Engine spherecasts establish current, material-aware cover.
function CombatFixture.panelShot(
    runtime: GameRuntime.Controller,
    weapon: string,
    sequence: number,
    panels: { Instance },
    start: number
): (Intent?, number)
    local muzzle = assert(runtime.aircraft.muzzle(weapon), "missing fixture muzzle")
    local query = RaycastParams.new()
    query.FilterType = Enum.RaycastFilterType.Include
    query.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
    for offset = 0, #panels - 1 do
        local index = (start + offset - 1) % #panels + 1
        local model = panels[index]
        if model:GetAttribute("DamageAppearance") == "Total" then
            continue
        end
        for _, solid in model:GetChildren() do
            if solid:IsA("BasePart") and runtime.destruction.identify(solid) == model.Name then
                local delta = solid.Position - muzzle
                local ray = workspace:Spherecast(muzzle, 0.05, delta.Unit * (delta.Magnitude + 0.25), query)
                if ray and runtime.destruction.identify(ray.Instance) == model.Name then
                    local intent = gunship(runtime, weapon, solid.Position, sequence)
                    if intent then
                        return intent, index
                    end
                end
            end
        end
    end
    return nil, start
end

-- Keep exercising real impact work after the finite set of panels opens.
-- Authoritative flight still determines the first terrain or solid contact.
function CombatFixture.terrainShot(runtime: GameRuntime.Controller, weapon: string, sequence: number): Intent?
    local horizontal = if sequence % 2 == 0 then 70 else -70
    local query = RaycastParams.new()
    query.FilterType = Enum.RaycastFilterType.Include
    query.FilterDescendantsInstances = { workspace.World.Battlefield, workspace.Terrain }
    local hit = workspace:Raycast(Vector3.new(horizontal, 90, 60), Vector3.new(0, -110, 0), query)
    if hit then
        return gunship(runtime, weapon, hit.Position, sequence)
    end
    return nil
end

return CombatFixture
