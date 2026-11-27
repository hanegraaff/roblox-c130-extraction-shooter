--!strict
--[=[
    Lobby balance editor. The server supplies access, settings, revisions and
    preset names. Edits stay local until Save, and Apply selects a saved preset.
    start owns one ScreenGui and its listeners. The returned stop invalidates
    outstanding requests, disconnects signals and destroys all controls.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(ReplicatedStorage.Shared.BalanceSchema)
local BalancePanel = {}

type Fields = { [string]: number | string | boolean }
type Edit = { name: string?, settings: Fields?, userId: number?, action: string?, revision: number? }
type View = {
    revision: number,
    activeRevision: number,
    roundRevision: number,
    activeName: string,
    settings: Fields,
    presets: { [string]: Fields },
    trusted: { number },
    owner: boolean,
    savedBy: number,
    groundCount: number,
    storageStatus: string,
}
local ink = Color3.fromRGB(233, 238, 236)
local accent = Color3.fromRGB(157, 227, 175)
local surface = Color3.fromRGB(39, 51, 52)
local dark = Color3.fromRGB(21, 31, 32)

local function label(parent: Instance, caption: string, height: number): TextLabel
    local item = Instance.new("TextLabel")
    item.Size = UDim2.new(1, 0, 0, height)
    item.BackgroundTransparency = 1
    item.TextColor3 = ink
    item.TextSize = 16
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Font = Enum.Font.BuilderSans
    item.TextWrapped = true
    item.Text = caption
    item.Parent = parent
    return item
end

local function button(parent: Instance, caption: string): TextButton
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, 0, 0, 34)
    item.BackgroundColor3 = surface
    item.BorderSizePixel = 0
    item.TextColor3 = accent
    item.TextSize = 15
    item.Font = Enum.Font.BuilderSansBold
    item.Text = caption
    item.Parent = parent
    return item
end

local function input(parent: Instance, hint: string): TextBox
    local item = Instance.new("TextBox")
    item.Size = UDim2.new(1, 0, 0, 34)
    item.BackgroundColor3 = surface
    item.BorderSizePixel = 0
    item.ClearTextOnFocus = false
    item.Text = ""
    item.PlaceholderText = hint
    item.TextColor3 = ink
    item.TextSize = 16
    item.Font = Enum.Font.BuilderSans
    item.Parent = parent
    return item
end

-- Mount once for the current RoundState. Access and lobby transitions close the
-- editor automatically. Remote calls yield outside input and render callbacks.
function BalancePanel.start(player: Player, parent: PlayerGui, round: Instance): () -> ()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BalancePanel"
    gui.DisplayOrder = 60
    gui.ResetOnSpawn = false
    gui.Parent = parent
    local open = button(gui, "Balance")
    open.Name = "OpenBalance"
    open.AnchorPoint = Vector2.new(1, 1)
    open.Size = UDim2.fromOffset(94, 38)
    open.Position = UDim2.new(1, -12, 1, -76)

    local sheet = Instance.new("Frame")
    sheet.AnchorPoint = Vector2.new(0.5, 0.5)
    sheet.Position = UDim2.fromScale(0.5, 0.5)
    sheet.Size = UDim2.new(1, -20, 1, -20)
    sheet.BackgroundColor3 = dark
    sheet.BorderSizePixel = 0
    sheet.Visible = false
    sheet.Active = true
    sheet.Parent = gui
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(520, 680)
    limit.Parent = sheet
    local heading = label(sheet, "Round balance", 42)
    heading.Position = UDim2.fromOffset(14, 0)
    heading.Size = UDim2.new(1, -100, 0, 42)
    heading.Font = Enum.Font.BuilderSansBold
    heading.TextSize = 23
    local close = button(sheet, "Close")
    close.Position = UDim2.new(1, -74, 0, 5)
    close.Size = UDim2.fromOffset(62, 32)
    local feedback = label(sheet, "", 48)
    feedback.Position = UDim2.fromOffset(14, 42)
    feedback.Size = UDim2.new(1, -28, 0, 50)
    feedback.TextColor3 = accent

    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.fromOffset(14, 96)
    scroll.Size = UDim2.new(1, -28, 1, -108)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.Parent = sheet
    local rows = Instance.new("UIListLayout")
    rows.SortOrder = Enum.SortOrder.LayoutOrder
    rows.Padding = UDim.new(0, 6)
    rows.Parent = scroll

    local alive, busy = true, false
    local generation = 0
    local current: View? = nil
    local connections: { RBXScriptConnection } = {}
    local request: (string, Edit?) -> ()
    local render: (View, Fields, string) -> ()

    local function hide()
        generation += 1
        busy = false
        sheet.Visible = false
        open.Visible = true
        current = nil
        for _, child in scroll:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
    end
    local hud = parent:FindFirstChild("RoundHUD")
    local function eligibility()
        local view = if hud then hud:GetAttribute("View") else nil
        local inLobby = view == "Waiting"
            or view == "RoundLobby"
            or view == "Results"
            or view == "Resetting"
            or (view == nil and round:GetAttribute("Phase") == "Lobby")
        gui.Enabled = player:GetAttribute("BalanceAdminAccess") == true and inLobby
        if not gui.Enabled then
            hide()
        end
    end
    local function action(caption: string, callback: () -> ())
        button(scroll, caption).Activated:Connect(function()
            if not busy then
                callback()
            end
        end)
    end
    render = function(view, values, presetName)
        for _, child in scroll:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        local draft = table.clone(values)
        local editors: { [string]: TextBox } = {}
        label(
            scroll,
            string.format(
                "Live preset: %s  •  Live revision %d  •  Round revision %d",
                view.activeName,
                view.activeRevision,
                view.roundRevision
            ),
            34
        )
        label(
            scroll,
            string.format(
                "Last saved by %s  •  %s",
                if view.savedBy == 0 then "game defaults" else tostring(view.savedBy),
                view.storageStatus
            ),
            28
        )
        action("Refresh saved settings", function()
            request("read", nil)
        end)
        local names: { string } = {}
        for name in view.presets do
            table.insert(names, name)
        end
        table.sort(names)
        if #names > 0 then
            label(scroll, "Saved presets", 24)
        end
        for _, name in names do
            action(name, function()
                render(view, view.presets[name], name)
                feedback.Text = "Editing " .. name
            end)
        end
        label(scroll, "Preset name • enter a new name to save a copy", 26)
        local nameBox = input(scroll, "Preset name")
        nameBox.Text = presetName
        label(
            scroll,
            "Settings apply at the next deployment. The lobby minimum applies while waiting. Intermission locks when a result is announced.",
            56
        )
        local function readNumber(key: string): number?
            local box = editors[key]
            return if box then tonumber(box.Text) else nil
        end
        for _, field in Schema.fields do
            local key = field.key
            local suffix = ""
            if field.minimum ~= nil and field.maximum ~= nil then
                suffix = string.format("   %g–%g %s", field.minimum, field.maximum, field.unit or "")
            end
            label(scroll, field.label .. suffix, 25)
            if field.kind == "number" then
                local box = input(scroll, field.unit or "")
                box.Text = tostring(values[key])
                box.Name = key
                editors[key] = box
            else
                local choices: { string } = field.options or { "Off", "On" }
                local control = button(
                    scroll,
                    if field.kind == "boolean"
                        then (if values[key] then "On" else "Off")
                        else tostring(values[key])
                )
                control.Name = key
                control.Activated:Connect(function()
                    local index = table.find(choices, control.Text) or 0
                    control.Text = choices[index % #choices + 1]
                    draft[key] = if field.kind == "boolean" then control.Text == "On" else control.Text
                end)
            end
        end
        local summary = label(scroll, "", 60)
        local function preview()
            local function waitTime(cadence: string, reload: string): number
                return math.max(readNumber(cadence) or 0, readNumber(reload) or 0)
            end
            local tier = draft.panelDamage
            summary.Text = string.format(
                "Aircraft: %g HP for %d Ground. Empty weapon wait: 30mm %gs, 105mm %gs. Fresh panel: %d shell(s) or %gs of 30mm hits.",
                (readNumber("aircraftHealthPerGround") or 0) * view.groundCount,
                view.groundCount,
                waitTime("gauCadence", "gauReload"),
                waitTime("m102Cadence", "m102Reload"),
                if tier == "Low" then 2 else 1,
                if tier == "Low" then 4 elseif tier == "High" then 1 else 2
            )
        end
        for _, box in editors do
            box:GetPropertyChangedSignal("Text"):Connect(preview)
        end
        local panelControl = scroll:FindFirstChild("panelDamage")
        if panelControl and panelControl:IsA("TextButton") then
            panelControl:GetPropertyChangedSignal("Text"):Connect(function()
                task.defer(preview)
            end)
        end
        preview()
        action("Save named preset", function()
            for key, box in editors do
                local value = tonumber(box.Text)
                if value == nil then
                    feedback.Text = "Enter a number for " .. key
                    return
                end
                draft[key] = value
            end
            request("save", { name = nameBox.Text, settings = draft })
        end)
        action("Apply saved preset", function()
            request("apply", { name = nameBox.Text })
        end)
        action("Restore previous live preset", function()
            request("restore", nil)
        end)
        if view.owner then
            label(scroll, "Trusted tester IDs", 26)
            local ids: { string } = {}
            for _, id in view.trusted do
                table.insert(ids, tostring(id))
            end
            label(scroll, if #ids == 0 then "No testers added" else table.concat(ids, ", "), 34)
            local user = input(scroll, "Roblox user ID")
            action("Grant tester access", function()
                request("grant", { userId = tonumber(user.Text) })
            end)
            action("Revoke tester access", function()
                request("revoke", { userId = tonumber(user.Text) })
            end)
        end
    end
    request = function(verb, fields)
        if busy or not alive or not gui.Enabled then
            return
        end
        local remote = ReplicatedStorage:FindFirstChild("BalanceAdmin")
        if not remote or not remote:IsA("RemoteFunction") then
            feedback.Text = "Balance service unavailable"
            return
        end
        local args: Edit = fields or {}
        args.action = verb
        if verb ~= "read" and current then
            args.revision = current.revision
        end
        local stamp = generation
        busy = true
        feedback.Text = "Contacting server…"
        task.spawn(function()
            local ok, reply = pcall(function()
                return remote:InvokeServer(args)
            end)
            if not alive or stamp ~= generation then
                return
            end
            busy = false
            if not ok or type(reply) ~= "table" then
                feedback.Text = "Request failed. Close and reopen to retry."
                return
            end
            if reply.ok ~= true or not reply.view then
                feedback.Text = tostring(reply.error or "Request rejected")
                return
            end
            local view = reply.view :: View
            current = view
            local name = if verb == "save" then tostring(args.name) else view.activeName
            render(view, if verb == "save" then view.presets[name] else view.settings, name)
            feedback.Text = if verb == "save"
                then "Preset saved. Choose Apply to use it."
                elseif verb == "apply" or verb == "restore" then "Live settings saved."
                elseif verb == "read" then "Settings loaded."
                else "Tester access updated."
        end)
    end
    table.insert(
        connections,
        open.Activated:Connect(function()
            sheet.Visible, open.Visible = true, false
            request("read", nil)
        end)
    )
    table.insert(connections, close.Activated:Connect(hide))
    table.insert(connections, player:GetAttributeChangedSignal("BalanceAdminAccess"):Connect(eligibility))
    table.insert(connections, round:GetAttributeChangedSignal("Phase"):Connect(eligibility))
    if hud then
        table.insert(connections, hud:GetAttributeChangedSignal("View"):Connect(eligibility))
    end
    eligibility()
    return function()
        alive = false
        for _, connection in connections do
            connection:Disconnect()
        end
        gui:Destroy()
    end
end
return BalancePanel
