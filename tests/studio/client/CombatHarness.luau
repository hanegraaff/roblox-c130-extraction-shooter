--!strict
-- Test-only P05 client transport: sends production requests and observes replication.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CombatHarness = {}
local function waitFor(predicate: () -> boolean, message: string | (() -> string))
    local deadline = os.clock() + 8
    while not predicate() and os.clock() < deadline do
        task.wait(0.03)
    end
    if not predicate() then
        error("client combat harness timeout: " .. (if type(message) == "string" then message else message()))
    end
end
function CombatHarness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P05Harness", 50)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local listener: RBXScriptConnection
        listener = remote.OnClientEvent:Connect(function(token: number, kind: string, payload: unknown)
            local ok, reason = pcall(function()
                local state = ReplicatedStorage:WaitForChild("AircraftState", 5)
                assert(state, "aircraft state missing")
                if kind == "Fire" or kind == "Select" or kind == "Flood" then
                    local target =
                        state:FindFirstChild(if kind == "Select" then "SelectWeapon" else "FireWeapon")
                    assert(target and target:IsA("RemoteEvent"), "production combat transport missing")
                    if kind == "Flood" then
                        for _ = 1, 30 do
                            target:FireServer(payload)
                        end
                    else
                        target:FireServer(payload)
                    end
                elseif kind == "P19Impact" then
                    assert(type(payload) == "table", "missing impact expectation")
                    local fields = payload :: { [string]: unknown }
                    local point, id = fields.point, fields.id
                    assert(
                        typeof(point) == "Vector3" and type(id) == "string",
                        "malformed contact expectation"
                    )
                    waitFor(function()
                        local holder = workspace:FindFirstChild("LocalWeaponImpacts")
                        if not holder then
                            return false
                        end
                        for _, burst in holder:GetChildren() do
                            if
                                burst.Name == "ImpactBurst"
                                and burst:GetAttribute("Weapon") == "M102"
                                and burst:GetAttribute("ShotId") == id
                            then
                                local contact = burst:GetAttribute("ImpactPoint")
                                assert(
                                    typeof(contact) == "Vector3" and (contact - point).Magnitude < 0.01,
                                    "local burst disagreed with server contact"
                                )
                                return true
                            end
                        end
                        return false
                    end, "P19 actual local howitzer confirmation")
                elseif kind == "PanelDestroyed" then
                    assert(type(payload) == "table", "destroyed-panel expectation missing")
                    local fields = payload :: { [string]: unknown }
                    local id = fields.id
                    assert(type(id) == "string", "destroyed-panel id missing")
                    waitFor(function()
                        local panel = workspace.World.Battlefield:FindFirstChild(id, true)
                        return panel ~= nil and panel:GetAttribute("DamageAppearance") == "Total"
                    end, "one-hit opening replication")
                    local panel = assert(
                        workspace.World.Battlefield:FindFirstChild(id, true),
                        "panel missing after impact"
                    )
                    for _, part in panel:GetDescendants() do
                        assert(
                            not (part:IsA("BasePart") and part.CanCollide),
                            "replicated one-hit opening retains solid"
                        )
                    end
                elseif kind == "SandbreakThermal" then
                    assert(type(payload) == "table", "missing Sandbreak witness")
                    local fields = payload :: { [string]: unknown }
                    local id, appearance, thermal = fields.id, fields.appearance, fields.thermal
                    assert(
                        type(id) == "string" and type(appearance) == "string" and type(thermal) == "boolean",
                        "invalid Sandbreak panel, damage stage or thermal view"
                    )
                    assert(type(fields.visuals) == "table", "missing Sandbreak material witnesses")
                    local visuals = fields.visuals :: {
                        [string]: { texture: string, color: Color3, hidden: boolean },
                    }
                    local player = Players.LocalPlayer
                    local camera = assert(workspace.CurrentCamera, "missing local camera")
                    local detail = "waiting for Sandbreak replication"
                    local function awaiting(message: string): boolean
                        detail = message
                        return false
                    end
                    waitFor(function()
                        local panels = workspace.World.Battlefield:FindFirstChild("SpawnShelterPanels")
                        local panel = if panels then panels:FindFirstChild(id) else nil
                        if not panel or panel:GetAttribute("DamageAppearance") ~= appearance then
                            return awaiting("expected panel appearance has not replicated")
                        end
                        if (camera:FindFirstChild("OperatorThermal") ~= nil) ~= thermal then
                            return awaiting("operator grading did not match the local role")
                        end
                        local queryParts, visualParts = 0, 0
                        for _, mesh in panel:GetChildren() do
                            if mesh:IsA("MeshPart") and mesh:GetAttribute("PanelProxy") == true then
                                assert(
                                    mesh.CanCollide and mesh.CanQuery and mesh.Transparency == 1,
                                    "replicated cover changed"
                                )
                                queryParts += 1
                            elseif mesh:IsA("MeshPart") and mesh.TextureID ~= "" then
                                local expected = visuals[mesh.Name]
                                if not expected or mesh.TextureID ~= expected.texture then
                                    return awaiting("different texture witness: " .. mesh.Name)
                                end
                                local tint = mesh:FindFirstChildWhichIsA("SurfaceAppearance")
                                visualParts += 1
                                local transparency = if thermal and expected.hidden then 1 else 0
                                if
                                    mesh.Color ~= expected.color
                                    or mesh.LocalTransparencyModifier ~= transparency
                                then
                                    return awaiting(
                                        `unexpected base color or local transparency: {mesh.Name}`
                                    )
                                end
                                if thermal then
                                    if
                                        not expected.hidden
                                        and (not tint or tint.Color.R >= 0.45 or tint.Color.R <= 0)
                                    then
                                        return awaiting("operator tint missing or too bright: " .. mesh.Name)
                                    end
                                elseif tint then
                                    return awaiting(
                                        "operator tint leaked into the Ground view: " .. mesh.Name
                                    )
                                end
                            end
                        end
                        local expectedVisuals = 0
                        for _ in visuals do
                            expectedVisuals += 1
                        end
                        if
                            visualParts ~= expectedVisuals
                            or queryParts ~= (if appearance == "Total" then 0 else 1)
                        then
                            return awaiting(
                                `mesh counts differ: {visualParts}/{expectedVisuals} visuals, {queryParts} proxies`
                            )
                        end
                        if thermal then
                            for _, child in camera:GetChildren() do
                                if child:IsA("Highlight") and child.Name == "OperatorThermalTarget" then
                                    local ground = if child.Adornee and child.Adornee:IsA("Model")
                                        then Players:GetPlayerFromCharacter(child.Adornee)
                                        else nil
                                    if
                                        ground
                                        and ground ~= player
                                        and ground:GetAttribute("Role") == "Ground"
                                    then
                                        if
                                            child.DepthMode == Enum.HighlightDepthMode.Occluded
                                            and child.FillColor == Color3.new(1, 1, 1)
                                        then
                                            return true
                                        end
                                        return awaiting("Ground highlight lacks white fill or native depth")
                                    end
                                end
                            end
                            return awaiting("operator Ground highlight missing")
                        end
                        return camera:FindFirstChild("OperatorThermalTarget") == nil
                            or awaiting("Ground view retained an operator highlight")
                    end, function()
                        return `Sandbreak {id} {appearance} palette and cover: {detail}`
                    end)
                elseif kind == "OperatorPresentation" then
                    local player = Players.LocalPlayer
                    local gui = player.PlayerGui
                    local roundHud = gui:FindFirstChild("RoundHUD")
                    local banner = gui:FindFirstChild("FoundationStatus")
                    local thermal = gui:FindFirstChild("ThermalHUD")
                    local round = if roundHud then roundHud:FindFirstChild("Round") else nil
                    local profile = if thermal then thermal:FindFirstChild("Profile") else nil
                    assert(
                        round and round:IsA("TextLabel") and profile and profile:IsA("TextLabel"),
                        "operator labels missing"
                    )
                    assert(
                        banner and banner:IsA("ScreenGui") and not banner.Enabled,
                        "operator foundation banner obscures battlefield"
                    )
                    local camera = workspace.CurrentCamera
                    assert(camera, "operator camera missing")
                    local effect = camera:FindFirstChild("OperatorThermal")
                    assert(
                        effect
                            and effect:IsA("ColorCorrectionEffect")
                            and effect.Saturation == -1
                            and effect.Brightness >= -1
                            and effect.Brightness <= 1
                            and effect.Contrast >= -1
                            and effect.Contrast <= 1,
                        "white-hot thermal view lacks valid monochrome grading"
                    )
                    game:GetService("RunService").RenderStepped:Wait()
                    local origin, size = round.AbsolutePosition, round.AbsoluteSize
                    local center = camera.ViewportSize * 0.5
                    assert(
                        not (
                                center.X >= origin.X
                                and center.X <= origin.X + size.X
                                and center.Y >= origin.Y
                                and center.Y <= origin.Y + size.Y
                            ),
                        "round label covers center targeting"
                    )
                    if game:GetService("UserInputService").TouchEnabled then
                        local touchGui = gui:FindFirstChild("TouchGui")
                        assert(
                            not touchGui or (touchGui:IsA("ScreenGui") and not touchGui.Enabled),
                            "operator default movement joystick remains visible"
                        )
                        local controls = gui:FindFirstChild("OperatorTouchControls")
                        assert(
                            controls and controls:FindFirstChild("Fire") and controls:FindFirstChild("PanUp"),
                            "operator touch controls missing"
                        )
                    end
                elseif kind == "Observe" then
                    local round = ReplicatedStorage:FindFirstChild("RoundState")
                    local effects = workspace:FindFirstChild("CombatEffects")
                    assert(
                        round
                            and effects
                            and state:GetAttribute("Selection")
                            and state:GetAttribute("Readiness"),
                        "replicated combat state missing"
                    )
                    if type(payload) == "table" then
                        local expected = payload :: { [string]: unknown }
                        waitFor(function()
                            local selection = state:GetAttribute("Selection")
                            local impact = state:GetAttribute("Impact")
                            local selected = if type(selection) == "string"
                                then HttpService:JSONDecode(selection)
                                else nil
                            local hit = if type(impact) == "string"
                                then HttpService:JSONDecode(impact)
                                else nil
                            local target = if type(expected.targetId) == "number"
                                then Players:GetPlayerByUserId(expected.targetId)
                                else nil
                            local character = if target then target.Character else nil
                            local humanoid = if character
                                then character:FindFirstChildOfClass("Humanoid")
                                else nil
                            return (
                                expected.weapon == nil or (selected and selected.weapon == expected.weapon)
                            )
                                and (expected.shotId == nil or (hit and hit.shotId == expected.shotId))
                                and (expected.health == nil or (humanoid and humanoid.Health == expected.health))
                                and (
                                    expected.winner == nil
                                    or round:GetAttribute("Winner") == expected.winner
                                )
                        end, "matching weapon, impact, health and result")
                    end
                else
                    error("unknown combat probe")
                end
            end)
            remote:FireServer(token, ok, if ok then "ok" else tostring(reason), Players.LocalPlayer.UserId)
        end)
        remote.AncestryChanged:Connect(function()
            if not remote:IsDescendantOf(ReplicatedStorage) then
                listener:Disconnect()
            end
        end)
        remote:FireServer(0, true, script.Parent:GetAttribute("ClientTestReport"), Players.LocalPlayer.UserId)
    end)
end
return CombatHarness
