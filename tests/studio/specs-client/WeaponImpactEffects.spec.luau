--!strict
-- P19 A3: native client emitters, presentation-only attachment, capped work
-- and generation cleanup. Contacts are injected here, transport is separate.
type API = typeof(require(game.StarterPlayer.StarterPlayerScripts.Client.WeaponImpactEffects))

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P19 local impact admission preserves distinct contacts and reset clears bounded effects", function()
        local scripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts", 10)
        local client = if scripts then scripts:WaitForChild("Client", 15) else nil
        local module = if client then client:WaitForChild("WeaponImpactEffects", 10) else nil
        assert(module and module:IsA("ModuleScript"), "impact effect client module unavailable")
        local Effects = require(module) :: API
        local state = Instance.new("Folder")
        local owner = Effects.new(state)
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
            assert(owner.show("M102", 2, "a", point, Vector3.yAxis, "Ground", 10.2))
            owner.update(2, "Lobby", 1, false, 10.3)
            assert(#holder:GetChildren() == 0 and holder.Parent == nil, "lobby left active effects")
        end)
        owner.stop()
        owner.stop()
        state:Destroy()
        assert(ok, tostring(failure))
    end)
end
