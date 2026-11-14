--!strict
-- P17: real client-only transparency ownership; rendered depth review is separate.
local Cosmetics = require(game.Players.LocalPlayer.PlayerScripts.Client.ThermalCosmetics)
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
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
                assert(
                    math.abs(cosmetic.LocalTransparencyModifier - 0.35) < 1e-6,
                    "map removal did not restore prior local value"
                )
                cosmetic.Parent = root
                assert(cosmetic.LocalTransparencyModifier == 1, "fresh descendant not observed")
                cosmetic.CanQuery = true
                assert(
                    math.abs(cosmetic.LocalTransparencyModifier - 0.35) < 1e-6,
                    "conversion into real cover remained hidden"
                )
                cosmetic.CanQuery = false
                cosmetic:SetAttribute("ThermalNonCover", false)
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
