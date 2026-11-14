--!strict
-- P17: real client-only transparency ownership; rendered depth review is separate.
local Cosmetics = require(game.Players.LocalPlayer.PlayerScripts.Client.ThermalCosmetics)
local AssetMaterial = require(game.ReplicatedStorage.Shared.AssetMaterial)
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test(
        "P17MaterialMetadata ordinary client reads compiled material contract without Plugin property access",
        function()
            local outpost = workspace.World.Battlefield.Buildings:FindFirstChild("Outpost")
            local source = if outpost then outpost:FindFirstChildWhichIsA("MeshPart", true) else nil
            assert(source and source:IsA("MeshPart"), "replicated imported Outpost mesh absent")
            local material, reason = AssetMaterial.read(source)
            assert(material, reason)
            assert(
                material.colorMap:match("^rbxassetid://[1-9]%d*$") and #material.colorPngSha256 == 64,
                "compiled runtime metadata malformed"
            )
            local clone = source:Clone()
            local surface = clone:FindFirstChildOfClass("SurfaceAppearance")
            assert(surface, "replicated actual surface absent")
            surface:SetAttribute("MaterialMetadataVersion", 0)
            local ok, failure = pcall(function()
                assert(AssetMaterial.read(clone) == nil, "client accepted wrong material contract version")
            end)
            clone:Destroy()
            assert(ok, failure)
        end
    )
    test(
        "P17ThermalFragments hides owned physical debris while rejecting marker-only impostors and real cover",
        function()
            local root = Instance.new("Folder")
            root.Name = "ThermalFragmentFixture"
            root.Parent = workspace
            local fragment = Instance.new("Part")
            fragment.Position = Vector3.new(2000, 100, 2000)
            fragment.Size = Vector3.new(1, 1, 1)
            fragment.Anchored, fragment.CanCollide, fragment.CanQuery, fragment.CanTouch =
                false, true, false, false
            fragment.LocalTransparencyModifier = 0.2
            fragment:SetAttribute("ThermalNonCover", true)
            fragment:SetAttribute("PanelFragmentVisual", true)
            fragment.CollisionGroup = "PanelFragments"
            fragment.Parent = root
            local impostor = fragment:Clone()
            impostor.CollisionGroup = "Default"
            impostor.LocalTransparencyModifier = 0.2
            impostor.Parent = root
            local solid = fragment:Clone()
            solid.Anchored, solid.CanQuery = true, true
            solid.CollisionGroup = "PanelFragments"
            solid.LocalTransparencyModifier = 0.2
            solid.Parent = root
            local owner = Cosmetics.start(root)
            local ok, failure = pcall(function()
                assert(
                    fragment.LocalTransparencyModifier == 1 and fragment.CanCollide and not fragment.CanQuery,
                    "physical presentation fragment retained thermal depth or lost physics"
                )
                assert(
                    math.abs(impostor.LocalTransparencyModifier - 0.2) < 1e-6
                        and math.abs(solid.LocalTransparencyModifier - 0.2) < 1e-6,
                    "fragment exception hid non-fragment cover"
                )
                fragment.CollisionGroup = "Default"
                task.wait()
                assert(
                    math.abs(fragment.LocalTransparencyModifier - 0.2) < 1e-6,
                    "loss of owned collision group remained hidden"
                )
                fragment.CollisionGroup = "PanelFragments"
                task.wait()
                assert(
                    fragment.LocalTransparencyModifier == 1,
                    "reacquired presentation group was not observed"
                )
            end)
            owner.stop()
            owner.stop()
            assert(
                owner.resources() == 0 and math.abs(fragment.LocalTransparencyModifier - 0.2) < 1e-6,
                "fragment teardown leaked local opacity or listeners"
            )
            root:Destroy()
            assert(ok, failure)
        end
    )
    test(
        "P17ThermalNonCover hides marked art restores exact values and retains native solid cover",
        function()
            local root = Instance.new("Folder")
            root.Name = "ThermalCosmeticFixture"
            root.Parent = workspace
            local cosmetic = Instance.new("Part")
            cosmetic.Anchored = true
            cosmetic.CanCollide, cosmetic.CanQuery = false, false
            cosmetic.LocalTransparencyModifier = 0.35
            cosmetic:SetAttribute("ThermalNonCover", true)
            cosmetic.Parent = root
            local solid = Instance.new("Part")
            solid.Anchored = true
            solid.LocalTransparencyModifier = 0.17
            solid:SetAttribute("ThermalNonCover", true)
            solid.Parent = root
            local owner = Cosmetics.start(root)
            local ok, failure = pcall(function()
                assert(cosmetic.LocalTransparencyModifier == 1, "marked non-cover still writes thermal depth")
                assert(
                    math.abs(solid.LocalTransparencyModifier - 0.17) < 1e-6
                        and solid.CanQuery
                        and solid.CanCollide,
                    "solid cover changed"
                )
                cosmetic.Parent = nil
                task.wait()
                assert(
                    math.abs(cosmetic.LocalTransparencyModifier - 0.35) < 1e-6,
                    "map removal did not restore prior local value"
                )
                cosmetic.Parent = root
                task.wait()
                assert(cosmetic.LocalTransparencyModifier == 1, "fresh descendant not observed")
                cosmetic.CanQuery = true
                task.wait()
                assert(
                    math.abs(cosmetic.LocalTransparencyModifier - 0.35) < 1e-6,
                    "conversion into real cover remained hidden"
                )
                cosmetic.CanQuery = false
                cosmetic:SetAttribute("ThermalNonCover", false)
                task.wait()
                assert(
                    math.abs(cosmetic.LocalTransparencyModifier - 0.35) < 1e-6,
                    "attribute cleanup lost prior value"
                )
                cosmetic:SetAttribute("ThermalNonCover", true)
            end)
            owner.stop()
            owner.stop()
            assert(
                owner.resources() == 0 and math.abs(cosmetic.LocalTransparencyModifier - 0.35) < 1e-6,
                "stop leaked transparency/listeners"
            )
            root:Destroy()
            assert(ok, failure)
        end
    )
end
