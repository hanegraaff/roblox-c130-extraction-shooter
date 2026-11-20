--!strict
-- P10 test-only native client. Drives public Studio virtual input, inspects
-- live production HUD/camera state and sends ordinary intents for authority checks.
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Harness = {}

type Expected = {
    view: string?,
    targetId: number?,
    result: string?,
    phrase: string?,
    profile: string?,
    fov: number?,
    ammo: boolean?,
}

local function waitFor(predicate: () -> boolean, message: string)
    local deadline = os.clock() + 8
    repeat
        if predicate() then
            return
        end
        task.wait()
    until os.clock() >= deadline
    error(message, 2)
end

local function hud(name: string): ScreenGui
    local found = player.PlayerGui:FindFirstChild(name)
    assert(found and found:IsA("ScreenGui"), "missing " .. name)
    return found
end

local function object(root: Instance, name: string): GuiObject
    local found = root:FindFirstChild(name, true)
    assert(found and found:IsA("GuiObject"), "missing " .. name)
    return found
end

local function label(root: Instance, name: string): TextLabel
    local found = object(root, name)
    assert(found:IsA("TextLabel"), name .. " must be a TextLabel")
    return found
end

local function expectText(element: TextLabel, phrase: string)
    waitFor(function()
        return element.Visible
            and string.find(string.lower(element.Text), string.lower(phrase), 1, true) ~= nil
    end, element.Name .. " did not display " .. phrase .. ": " .. element.Text)
end

local function humanoid(owner: Player): Humanoid?
    return if owner.Character then owner.Character:FindFirstChildOfClass("Humanoid") else nil
end

local function checkBounds(element: GuiObject, root: ScreenGui)
    local camera = assert(workspace.CurrentCamera, "camera missing for layout")
    local inset = if root.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
    local start = element.AbsolutePosition + inset
    local finish = start + element.AbsoluteSize
    assert(
        element.AbsoluteSize.X > 0
            and element.AbsoluteSize.Y > 0
            and start.X >= 0
            and start.Y >= 0
            and finish.X <= camera.ViewportSize.X + 1
            and finish.Y <= camera.ViewportSize.Y + 1,
        string.format("%s is outside %s: %s to %s", element.Name, camera.ViewportSize, start, finish)
    )
    if element:IsA("TextLabel") or element:IsA("TextButton") then
        assert(element.TextFits, element.Name .. " text clips: " .. element.Text)
    end
end

-- Use the same input route as a player's keyboard. The engine can reject
-- injection when its chat/menu owns focus, which fails the named case.
local function key(code: Enum.KeyCode)
    local input = UserInputService:CreateVirtualInput()
    assert(input and input:IsA("VirtualInput"), "Studio VirtualInput is unavailable")
    input:SendKey(true, code)
    RunService.RenderStepped:Wait()
    input:SendKey(false, code)
    RunService.RenderStepped:Wait()
end

local function verifyCamera(expected: Expected, round: ScreenGui)
    waitFor(function()
        local camera = workspace.CurrentCamera
        if not camera then
            return false
        end
        if expected.targetId then
            local target = Players:GetPlayerByUserId(expected.targetId)
            return target ~= nil
                and humanoid(target) ~= nil
                and camera.CameraType == Enum.CameraType.Custom
                and camera.CameraSubject == humanoid(target)
                and round:GetAttribute("SpectatorUserId") == expected.targetId
        elseif expected.view == "Results" or expected.view == "Spectator" then
            local subject = camera.CameraSubject
            return camera.CameraType == Enum.CameraType.Scriptable
                and subject ~= nil
                and subject.Name == "RoundOverviewSubject"
                and round:GetAttribute("SpectatorUserId") == nil
        elseif expected.view == "Ground" or expected.view == "Waiting" then
            return humanoid(player) ~= nil
                and camera.CameraType == Enum.CameraType.Custom
                and camera.CameraSubject == humanoid(player)
        elseif expected.view == "Operator" then
            return camera.CameraType == Enum.CameraType.Scriptable
                and (expected.fov == nil or math.abs(camera.FieldOfView - expected.fov) < 0.5)
        end
        return true
    end, "camera ownership did not converge for " .. tostring(expected.view))
end

local function verifyView(expected: Expected): unknown
    local round = hud("RoundHUD")
    waitFor(function()
        return round:GetAttribute("View") == expected.view
    end, "expected " .. tostring(expected.view) .. ", observed " .. tostring(round:GetAttribute("View")))
    verifyCamera(expected, round)
    local hint = label(round, "Guide")
    if expected.phrase then
        expectText(hint, expected.phrase)
    end
    local roundText = label(round, "Round")
    RunService.RenderStepped:Wait()
    checkBounds(roundText, round)
    if hint.Visible then
        checkBounds(hint, round)
    end
    if expected.result then
        expectText(roundText, expected.result)
    elseif expected.view == "Ground" or expected.view == "Operator" then
        assert(string.match(roundText.Text, "%d+:%d%d"), "round timer missing: " .. roundText.Text)
        expectText(label(round, "AircraftHealth"), "300")
    end
    if expected.view == "Ground" then
        local ground = hud("GroundCombatHUD")
        expectText(label(ground, "RifleStatus"), "M-7")
        if expected.ammo then
            expectText(label(ground, "RifleStatus"), "30")
        end
        expectText(label(ground, "LauncherStatus"), "available")
    elseif expected.profile then
        local profile = label(hud("ThermalHUD"), "Profile")
        expectText(profile, expected.profile)
    elseif expected.view == "Spectator" or expected.view == "Results" or expected.view == "Waiting" then
        assert(player.PlayerGui:FindFirstChild("ThermalHUD") == nil, "thermal controls persisted")
        assert(not object(hud("GroundCombatHUD"), "RifleStatus").Visible, "spectator rifle actions visible")
    end
    for _, name in { "RoundHUD", "GroundCombatHUD", "ThermalHUD" } do
        local total = 0
        for _, item in player.PlayerGui:GetChildren() do
            if item.Name == name then
                total += 1
            end
        end
        assert(total <= 1, "duplicate " .. name)
    end
    local camera = assert(workspace.CurrentCamera, "camera disappeared before telemetry")
    return {
        viewport = { camera.ViewportSize.X, camera.ViewportSize.Y },
        view = expected.view,
        timerOrResult = roundText.Text,
        fov = camera.FieldOfView,
        targetId = round:GetAttribute("SpectatorUserId"),
    }
end

local function perform(action: string, payload: unknown): unknown
    local expected = payload :: Expected
    if action == "NoHud" then
        waitFor(function()
            local camera = workspace.CurrentCamera
            return player.PlayerGui:FindFirstChild("RoundHUD") == nil
                and player.PlayerGui:FindFirstChild("GroundCombatHUD") == nil
                and player.PlayerGui:FindFirstChild("ThermalHUD") == nil
                and (camera == nil or camera:FindFirstChild("RoundOverviewSubject") == nil)
        end, "HUD or camera subject was not destroyed after runtime stop")
        return { removed = true }
    end
    local round = hud("RoundHUD")
    if action == "View" then
        return verifyView(expected)
    elseif action == "EquipRifle" then
        key(Enum.KeyCode.One)
        waitFor(function()
            return player.Character ~= nil and player.Character:FindFirstChild("M-7 rifle") ~= nil
        end, "1 did not equip the M-7")
        return verifyView(expected)
    elseif action == "RejectFullReload" then
        key(Enum.KeyCode.R)
        local feedback = label(hud("GroundCombatHUD"), "ActionFeedback")
        expectText(feedback, "magazine is full")
        return { feedback = feedback.Text }
    elseif action == "NextTarget" or action == "PreviousTarget" then
        key(if action == "NextTarget" then Enum.KeyCode.RightBracket else Enum.KeyCode.LeftBracket)
        return verifyView(expected)
    elseif action == "SwitchWeapon" then
        key(Enum.KeyCode.Two)
        return verifyView(expected)
    elseif action == "HelpAndSettings" then
        key(Enum.KeyCode.H)
        local help = object(round, "HelpContent")
        assert(help.Visible, "H did not open help")
        checkBounds(help, round)
        checkBounds(label(help, "Instructions"), round)
        key(Enum.KeyCode.P)
        local settings = object(round, "SettingsContent")
        assert(settings.Visible, "P did not open settings")
        assert(not help.Visible, "help and settings both visible")
        checkBounds(settings, round)
        checkBounds(label(settings, "Instructions"), round)
        for _ = 1, 3 do
            if round:GetAttribute("Effects") == "Off" then
                break
            end
            key(Enum.KeyCode.Left)
        end
        assert(round:GetAttribute("Effects") == "Off", "keyboard did not turn effects off")
        key(Enum.KeyCode.Down)
        assert(round:GetAttribute("SettingsSelection") == "CameraShake", "Down did not select camera shake")
        for _ = 1, 3 do
            if round:GetAttribute("CameraShake") == "Off" then
                break
            end
            key(Enum.KeyCode.Left)
        end
        assert(round:GetAttribute("CameraShake") == "Off", "keyboard did not turn shake off")
        key(Enum.KeyCode.P)
        assert(not settings.Visible, "P did not close settings")
        verifyCamera(expected, round)
        return { effects = round:GetAttribute("Effects"), shake = round:GetAttribute("CameraShake") }
    elseif action == "Cue" then
        local cue = label(round, "Cue")
        local phrase = assert(expected.phrase, "expected cue phrase missing")
        waitFor(function()
            return cue.Visible and string.find(cue.Text, phrase, 1, true) ~= nil
        end, "missing visual cue with effects off: " .. cue.Text)
        assert(round:GetAttribute("Effects") == "Off", "effects setting drifted")
        assert(round:GetAttribute("CuePulse") == 0, "muted effects still pulse")
        return { cue = cue.Text, effects = round:GetAttribute("Effects") }
    elseif action == "StillDestruction" then
        verifyView(expected)
        local cue = label(round, "Cue")
        expectText(cue, "C-130 DESTROYED")
        assert(round:GetAttribute("Effects") == "Off", "muted effects lost after round reset")
        assert(round:GetAttribute("CameraShake") == "Off", "shake preference lost after round reset")
        local camera = assert(workspace.CurrentCamera, "no destruction camera")
        local initial = camera.CFrame
        local deadline = os.clock() + 0.2
        repeat
            RunService.RenderStepped:Wait()
            assert(camera.CFrame:FuzzyEq(initial, 1e-5), "destruction camera moved with shake off")
        until os.clock() >= deadline
        return { cue = cue.Text, effects = "Off", shake = "Off", stillSeconds = 0.2 }
    end
    local ownerName, remoteName = string.match(action, "^([^/]+)/([^/]+)$")
    assert(ownerName and remoteName, "unknown P10 client probe " .. action)
    local owner = ReplicatedStorage:FindFirstChild(ownerName)
    local remote = if owner then owner:FindFirstChild(remoteName) else nil
    assert(remote and remote:IsA("RemoteEvent"), "production remote missing")
    remote:FireServer(payload)
    return { sent = action }
end

-- Starts one listener for this native test only. Reports the actual local smoke
-- results and releases the fixture when its owned server transport is destroyed.
function Harness.run()
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("P10Harness", 120)
        if not remote or not remote:IsA("RemoteEvent") then
            return
        end
        local listener = remote.OnClientEvent:Connect(
            function(token: number, action: string, payload: unknown)
                local ok, value = pcall(perform, action, payload)
                remote:FireServer(token, ok, if ok then HttpService:JSONEncode(value) else tostring(value))
            end
        )
        remote.Destroying:Once(function()
            listener:Disconnect()
        end)
        remote:FireServer(0, true, script.Parent:GetAttribute("ClientTestReport"))
    end)
end

return Harness
