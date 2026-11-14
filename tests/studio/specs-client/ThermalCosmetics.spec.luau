--!strict
-- P17: real client-only transparency ownership; rendered depth review is separate.
type CosmeticsAPI = typeof(require(game.StarterPlayer.StarterPlayerScripts.Client.ThermalCosmetics))
type MaterialAPI = typeof(require(game.ReplicatedStorage.Shared.AssetMaterial))
type MeshAPI = typeof(require(game.ReplicatedStorage.Shared.AssetMesh))
-- Resolve delayed StarterPlayerScripts copies inside each test, so prerequisite
-- timeouts remain ordinary reported failures rather than aborting TestEZ discovery.
local function cosmetics(): CosmeticsAPI
    local scripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts", 10)
    local client = if scripts then scripts:WaitForChild("Client", 15) else nil
    local module = if client then client:WaitForChild("ThermalCosmetics", 10) else nil
    assert(module and module:IsA("ModuleScript"), "client ThermalCosmetics replication timeout")
    return require(module) :: CosmeticsAPI
end
local function materialAPI(): MaterialAPI
    local shared = game.ReplicatedStorage:WaitForChild("Shared", 10)
    local module = if shared then shared:WaitForChild("AssetMaterial", 10) else nil
    assert(module and module:IsA("ModuleScript"), "shared AssetMaterial replication timeout")
    return require(module) :: MaterialAPI
end
local function meshAPI(): MeshAPI
    local shared = game.ReplicatedStorage:WaitForChild("Shared", 10)
    local module = if shared then shared:WaitForChild("AssetMesh", 10) else nil
    assert(module and module:IsA("ModuleScript"), "shared AssetMesh replication timeout")
    return require(module) :: MeshAPI
end
local function importedMesh(materials: MaterialAPI): MeshPart
    local deadline = os.clock() + 60
    while type(workspace:GetAttribute("ServerTestReport")) ~= "string" and os.clock() < deadline do
        task.wait()
    end
    local report = workspace:GetAttribute("ServerTestReport")
    assert(type(report) == "string", "server fixtures did not finish before imported material probe")
    local totals = game.HttpService:JSONDecode(report)
    assert(
        totals.failed == 0 and totals.errors == 0 and totals.passed > 0,
        "server fixtures failed: " .. report
    )
    -- Runtime startup follows fixture completion. Attribute and actual descendant
    -- readiness are both required; a report alone is not mesh replication proof.
    deadline = os.clock() + 35
    repeat
        local world = workspace:FindFirstChild("World")
        local map = if world then world:FindFirstChild("Battlefield") else nil
        local buildings = if map then map:FindFirstChild("Buildings") else nil
        local outpost = if buildings then buildings:FindFirstChild("Outpost") else nil
        local mesh = if outpost then outpost:FindFirstChildWhichIsA("MeshPart", true) else nil
        if
            map
            and map:GetAttribute("OutpostAssetRevision")
            and mesh
            and mesh:IsA("MeshPart")
            and materials.read(mesh) ~= nil
        then
            return mesh
        end
        task.wait()
    until os.clock() >= deadline
    error("approved runtime Outpost mesh/material metadata replication timeout")
end
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test(
        "P17MaterialMetadata ordinary client reads compiled material contract without Plugin property access",
        function()
            local AssetMaterial = materialAPI()
            local source = importedMesh(AssetMaterial)
            local AssetMesh = meshAPI()
            assert(AssetMesh.validate(source), "replicated native mesh constructor data missing")
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
                clone:SetAttribute("NativeMeshSize", source.MeshSize * 2)
                assert(not AssetMesh.validate(clone), "client accepted mismatched native mesh intrinsics")
            end)
            clone:Destroy()
            assert(ok, failure)
        end
    )
    test(
        "P17ThermalFragments hides owned physical debris while rejecting marker-only impostors and real cover",
        function()
            local Cosmetics = cosmetics()
            local root = Instance.new("Folder")
            root.Name = "ThermalFragmentFixture"
            -- An unparented real-Instance subtree has exactly this test owner.
            -- The live operator owner legitimately watches all of Workspace.
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
            local Cosmetics = cosmetics()
            local root = Instance.new("Folder")
            root.Name = "ThermalCosmeticFixture"
            -- Isolate ownership from the production operator's Workspace watch.
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
