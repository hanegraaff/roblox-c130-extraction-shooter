--!strict
-- P19 A3: native client emitters, presentation-only attachment, capped work
-- and generation cleanup. Contacts are injected here, transport is separate.
type API = typeof(require(game.StarterPlayer.StarterPlayerScripts.Client.WeaponImpactEffects))

local function getEffects(): API
    local scripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts", 10)
    local client = if scripts then scripts:WaitForChild("Client", 15) else nil
    local module = if client then client:WaitForChild("WeaponImpactEffects", 10) else nil
    assert(module and module:IsA("ModuleScript"), "impact effect client module unavailable")
    return require(module) :: API
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P19 local impact admission preserves distinct contacts and reset clears bounded effects", function()
        local state = Instance.new("Folder")
        local owner = getEffects().new(state)
        local ok, failure = pcall(function()
            local camera = assert(workspace.CurrentCamera, "current camera missing")
            local point = camera.CFrame.Position + camera.CFrame.LookVector * 30
            owner.update(1, "Active", 1, false, 10)
            assert(owner.show("M102", 1, "a", point, Vector3.yAxis, "Ground", 10))
            assert(owner.show("GAU23", 1, "b", point + Vector3.xAxis, Vector3.yAxis, "Solid", 10))
            assert(owner.show("Rocket", 1, "a", point, Vector3.yAxis, "Metal", 10))
            assert(
                not owner.show("M102", 1, "a", point, Vector3.yAxis, "Ground", 10),
                "duplicate contact rendered twice"
            )
            assert(not owner.show("M102", 0, "c", point, Vector3.yAxis, "Ground", 10), "stale round rendered")
            assert(
                not owner.show("M102", 1, "c", point, Vector3.zero, "Ground", 10),
                "invalid surface normal rendered"
            )
            assert(
                not owner.show("M102", 1, "c", point, Vector3.yAxis, "Ground", 9.24),
                "stale impact rendered"
            )
            local holder =
                assert(workspace:FindFirstChild("LocalWeaponImpacts"), "client did not create impact visuals")
            assert(#holder:GetChildren() == 3, "impact multiplicity wrong")
            for index = 1, 32 do
                owner.show("GAU23", 1, tostring(index), point, Vector3.yAxis, "Solid", 10)
            end
            assert(#holder:GetChildren() == 12, "impact pool not bounded")
            local hasHeavy = false
            for _, instance in holder:GetChildren() do
                assert(
                    instance:IsA("BasePart")
                        and not instance.CanQuery
                        and not instance.CanTouch
                        and not instance.CanCollide,
                    "client visual can contact world"
                )
                if instance:GetAttribute("Weapon") == "M102" then
                    hasHeavy = true
                    assert(instance:GetAttribute("ImpactPoint") == point, "burst lost world contact point")
                end
            end
            assert(hasHeavy, "sustained light fire displaced the heavy visual")
            owner.update(1, "Active", 0, false, 10.1)
            assert(#holder:GetChildren() == 0, "zero effects retained active particles")
            assert(
                not owner.show("M102", 1, "muted", point, Vector3.yAxis, "Ground", 10.1),
                "muted controller created a burst"
            )
            owner.update(2, "Active", 1, true, 10.2)
            local orbitalContact = camera.CFrame.Position + camera.CFrame.LookVector * 580
            local normal = Vector3.xAxis
            assert(owner.show("M102", 2, "a", orbitalContact, normal, "Ground", 10.2))
            local function layers(id: string): (BasePart, Attachment, ParticleEmitter, ParticleEmitter)
                for _, item in holder:GetChildren() do
                    if item:IsA("BasePart") and item:GetAttribute("ShotId") == id then
                        local socket = item:FindFirstChildWhichIsA("Attachment")
                        assert(socket, "missing contact socket")
                        local fire, smoke = socket:FindFirstChild("Fireball"), socket:FindFirstChild("Smoke")
                        assert(fire and fire:IsA("ParticleEmitter"), "missing fireball")
                        assert(smoke and smoke:IsA("ParticleEmitter"), "missing smoke")
                        return item, socket, fire, smoke
                    end
                end
                error("missing live impact " .. id)
            end
            local flash, socket, fire, smoke = layers("a")
            local initialSize, initialAlpha = flash.Size.X, flash.Transparency
            assert(initialSize >= 7.5 and initialAlpha < 0.2, "Full orbital flash remained subdued")
            assert((flash.Position - orbitalContact):Dot(normal) > 5, "flash did not expand outward")
            assert(
                (socket.WorldPosition - (orbitalContact + normal * 0.1)).Magnitude < 0.01,
                "outward flash moved particles away from the real contact"
            )
            assert(fire.Size.Keypoints[2].Value >= 20, "orbital fireball lost visible extent")
            assert(smoke.Size.Keypoints[2].Value >= 20, "orbital smoke lost visible extent")
            assert(smoke.Transparency.Keypoints[2].Value < 0.6, "orbital plume lacks visible peak opacity")
            owner.update(2, "Active", 1, true, 10.28)
            assert(
                flash.Size.X > initialSize and flash.Transparency > initialAlpha,
                "flash did not expand and fade"
            )
            owner.update(2, "Active", 0.45, true, 10.3)
            assert(owner.show("M102", 2, "reduced", orbitalContact, normal, "Ground", 10.3))
            local small, _, shortFire, shortSmoke = layers("reduced")
            assert(
                small.Size.X < initialSize and small.Transparency > initialAlpha,
                "Reduced used Full flash"
            )
            assert(shortFire.Lifetime.Max < fire.Lifetime.Max, "Reduced kept Full fireball lifetime")
            assert(shortSmoke.Lifetime.Max < smoke.Lifetime.Max, "Reduced kept Full plume lifetime")
            owner.update(2, "Active", 0, true, 10.4)
            assert(#holder:GetChildren() == 0, "Off retained the more pronounced heavy burst")
            owner.update(2, "Lobby", 1, false, 10.5)
            assert(#holder:GetChildren() == 0 and holder.Parent == nil, "lobby left active effects")
        end)
        owner.stop()
        owner.stop()
        state:Destroy()
        assert(ok, tostring(failure))
    end)

    test("P19 rocket trail follows replicated children and expires after removal", function()
        local state = Instance.new("Folder")
        local owner = getEffects().new(state)
        local existing = workspace:FindFirstChild("LauncherEffects")
        local folder = existing or Instance.new("Folder")
        if not existing then
            folder.Name, folder.Parent = "LauncherEffects", workspace
        end
        local rocket = Instance.new("Part")
        rocket.Name = "Rocket"
        rocket.Anchored, rocket.CanCollide, rocket.CanQuery, rocket.CanTouch = true, false, false, false
        rocket.Transparency = 1
        local ok, failure = pcall(function()
            local camera = assert(workspace.CurrentCamera, "current camera missing")
            local near = camera.CFrame * CFrame.new(0, 0, -20)
            local far = camera.CFrame * CFrame.new(0, 0, -600)
            rocket.CFrame, rocket.Parent = near, folder
            task.wait()
            owner.update(3, "Active", 1, false, 4)
            assert(not workspace:FindFirstChild("LocalWeaponImpacts"), "unknown round started a trail")
            rocket.CFrame = far
            rocket:SetAttribute("FlightRoundId", 3)
            owner.update(3, "Active", 1, false, 4.02)
            assert(not workspace:FindFirstChild("LocalWeaponImpacts"), "far rocket started a trail")

            rocket.CFrame = near
            owner.update(3, "Active", 1, false, 4.04)
            local holder = assert(workspace:FindFirstChild("LocalWeaponImpacts"), "near rocket was missed")
            local anchor = holder:FindFirstChild("RocketSmoke")
            assert(anchor and anchor:IsA("BasePart"), "missing smoke anchor")
            local smoke = assert(anchor:FindFirstChildWhichIsA("ParticleEmitter", true), "missing emitter")
            owner.update(3, "Active", 1, false, 4.06)
            assert(smoke.Enabled and smoke.Rate == 28, "Full smoke did not follow the local rocket")
            assert(
                (anchor.Position - (near * CFrame.new(0, 0, 0.9)).Position).Magnitude < 0.01,
                "smoke anchor did not follow the exhaust offset"
            )
            owner.update(3, "Active", 0.45, false, 4.08)
            assert(smoke.Enabled and smoke.Rate == 12, "Reduced smoke did not change emission")
            rocket.CFrame = far
            owner.update(3, "Active", 0.45, false, 4.1)
            assert(not smoke.Enabled and anchor.Parent == holder, "far trail failed to pause emission")

            rocket:Destroy()
            task.wait()
            owner.update(3, "Active", 1, false, 4.12)
            assert(not smoke.Enabled and anchor.Parent == holder, "removed rocket failed to start trail fade")
            owner.update(3, "Active", 1, false, 4.8)
            assert(anchor.Parent == nil, "finished trail retained its anchor")
        end)
        owner.stop()
        rocket:Destroy()
        if not existing then
            folder:Destroy()
        end
        state:Destroy()
        assert(ok, tostring(failure))
    end)
end
