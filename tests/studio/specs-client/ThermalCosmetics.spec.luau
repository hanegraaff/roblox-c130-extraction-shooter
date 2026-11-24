--!strict
-- Real client-only thermal color/transparency ownership. Rendered depth review is separate.
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
    test("P18 thermal tint follows late SurfaceAppearance arrival removal and owner cleanup", function()
        local Cosmetics = cosmetics()
        local root = Instance.new("Model")
        root:SetAttribute("ThermalBrightness", 0.5)
        local part = Instance.new("MeshPart")
        part.Color = Color3.fromRGB(200, 180, 160)
        part.Parent = root
        local original = part.Color
        local owner = Cosmetics.start(root)
        local surface = Instance.new("SurfaceAppearance")
        surface.Color = Color3.fromRGB(180, 220, 200)
        local surfaceOriginal = surface.Color
        local function close(actual: Color3, wanted: Color3): boolean
            return (Vector3.new(actual.R, actual.G, actual.B) - Vector3.new(wanted.R, wanted.G, wanted.B)).Magnitude
                < 0.01
        end
        local ok, problem = pcall(function()
            assert(close(part.Color, original:Lerp(Color3.new(0, 0, 0), 0.5)), "fallback tint missing")
            surface.Parent = part
            task.wait()
            assert(close(part.Color, original), "old fallback was not restored before surface ownership")
            assert(
                close(surface.Color, surfaceOriginal:Lerp(Color3.new(0, 0, 0), 0.5)),
                "late surface stayed bright"
            )
            surface.Parent = nil
            task.wait()
            assert(close(surface.Color, surfaceOriginal), "removed surface retained tint")
            assert(
                close(part.Color, original:Lerp(Color3.new(0, 0, 0), 0.5)),
                "surface removal lost fallback tint"
            )
            surface.Parent = part
            task.wait()
            assert(
                close(surface.Color, surfaceOriginal:Lerp(Color3.new(0, 0, 0), 0.5)),
                "replacement surface stayed bright"
            )
            return true
        end)
        owner.stop()
        owner.stop()
        assert(
            owner.resources() == 0 and part.Color == original and surface.Color == surfaceOriginal,
            "late-surface cleanup leaked color or observers"
        )
        root:Destroy()
        assert(ok, problem)
    end)
    test("P18 thermal environment dims Parts and terrain locally and restores exact originals", function()
        local Cosmetics = cosmetics()
        local world = workspace:FindFirstChild("World")
        assert(world, "source world missing")
        local fixture = Instance.new("Folder")
        fixture.Name = "P18ThermalPaletteFixture"
        local part = Instance.new("Part")
        part.Anchored = true
        part.Color = Color3.new(1, 1, 1)
        part.CFrame = CFrame.new(2000, 2000, 2000)
        part.Parent = fixture
        fixture.Parent = world
        local originalSand = workspace.Terrain:GetMaterialColor(Enum.Material.Sand)
        local originalColor = part.Color
        local owner = Cosmetics.start(workspace)
        local ok, problem = pcall(function()
            local sand = workspace.Terrain:GetMaterialColor(Enum.Material.Sand)
            assert(
                part.Color.R < 0.46 and part.Color.G < 0.46 and part.Color.B < 0.46,
                "bright environment part retained"
            )
            assert(
                (Vector3.new(sand.R, sand.G, sand.B) - Vector3.new(
                    originalSand.R,
                    originalSand.G,
                    originalSand.B
                ) * 0.4).Magnitude < 0.01,
                "terrain palette did not dim"
            )
            assert(
                part.CanCollide and part.CanQuery and part.LocalTransparencyModifier == 0,
                "thermal palette changed cover"
            )
            return true
        end)
        owner.stop()
        owner.stop()
        assert(
            part.Color == originalColor
                and workspace.Terrain:GetMaterialColor(Enum.Material.Sand) == originalSand,
            "thermal palette restoration leaked"
        )
        fixture:Destroy()
        assert(ok, problem)
    end)
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
        "ThermalBrightness dims scoped art and replacement meshes while preserving cover and restoring exact colors",
        function()
            local Cosmetics = cosmetics()
            local root = Instance.new("Folder")
            local building = Instance.new("Model")
            building:SetAttribute("ThermalBrightness", 0.65)
            building:SetAttribute("ThermalSurfacePalette", "VesperThermalSurfaces")
            building.Parent = root
            local panel = Instance.new("Model")
            panel:SetAttribute("ThermalBrightness", -0.5)
            panel.Parent = building
            local original = Color3.fromRGB(190, 124, 82)
            local expected = original:Lerp(Color3.new(0, 0, 0), 0.35)
            local function near(actual: Color3, wanted: Color3): boolean
                return math.abs(actual.R - wanted.R) <= 1 / 255
                    and math.abs(actual.G - wanted.G) <= 1 / 255
                    and math.abs(actual.B - wanted.B) <= 1 / 255
            end
            local function piece(parent: Instance, transparency: number): Part
                local part = Instance.new("Part")
                part.Color = original
                part.Anchored = true
                part.Transparency = transparency
                part.Parent = parent
                return part
            end
            local wall = piece(panel, 0)
            local proxy = piece(panel, 1)
            local unscoped = piece(root, 0)
            local textured = Instance.new("MeshPart")
            textured.TextureID = "rbxassetid://102770137409004"
            textured:SetAttribute("ImportMaterialKey", "chalk")
            textured.Parent = panel
            local owner = Cosmetics.start(root)
            local replacement: Part? = nil
            local ok, failure = pcall(function()
                assert(near(wall.Color, expected), "dimmed art did not use the valid building setting")
                assert(proxy.Color == original and unscoped.Color == original, "dim leaked outside art")
                local surface = textured:FindFirstChildWhichIsA("SurfaceAppearance")
                assert(
                    surface and near(surface.Color, Color3.new(0.65, 0.65, 0.65)),
                    "legacy map lacked tint"
                )
                assert(wall.CanQuery and wall.CanCollide and wall.Transparency == 0, "dim changed cover")
                assert(wall.LocalTransparencyModifier == 0, "dim hid solid geometry")
                wall.Parent = nil
                local newWall = piece(panel, 0)
                replacement = newWall
                task.wait()
                assert(wall.Color == original, "removed panel kept the local tint")
                assert(near(newWall.Color, expected), "replacement panel did not inherit thermal brightness")
            end)
            owner.stop()
            owner.stop()
            local finalWall = replacement
            assert(
                owner.resources() == 0 and (not finalWall or finalWall.Color == original),
                "tint leaked on stop"
            )
            assert(not textured:FindFirstChildWhichIsA("SurfaceAppearance"), "local thermal surface leaked")
            assert(textured.TextureID == "rbxassetid://102770137409004", "source texture changed")
            wall:Destroy()
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
