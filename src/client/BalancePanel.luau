--!strict
--[=[
    Client lobby editor for server-owned balance presets. Four tabs share one draft.
    Numeric controls support mouse/touch sliders, keyboard arrows and exact entry.
    Save persists the draft; Apply selects a saved preset. All remote authority
    remains on the server. stop/hide disconnect input listeners and invalidate
    yielding requests. No cloud writes occur until an explicit button action.
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
local ink = Color3.fromRGB(235, 241, 239)
local muted = Color3.fromRGB(161, 179, 177)
local accent = Color3.fromRGB(157, 227, 175)
local surface = Color3.fromRGB(38, 52, 54)
local dark = Color3.fromRGB(20, 30, 32)
local groups = {
    {
        name = "Player",
        keys = {
            "groundHealth",
            "m7Damage",
            "m7Cadence",
            "m7Reload",
            "rocketDamage",
            "launcherReload",
            "medkitHeal",
        },
    },
    {
        name = "C-130",
        keys = {
            "aircraftHealthPerGround",
            "gauDamage",
            "gauCadence",
            "gauReload",
            "m102Damage",
            "m102Reload",
        },
    },
    { name = "Buildings", keys = { "panelDamage" } },
    { name = "Game & lobby", keys = { "roundDuration", "intermission", "minimumPlayers" } },
}
local captions = {
    groundHealth = "Player health",
    m7Damage = "Rifle damage per hit",
    m7Cadence = "Time between rifle shots",
    m7Reload = "Rifle reload time",
    rocketDamage = "Rocket damage per hit",
    launcherReload = "Rocket launcher reload time",
    medkitHeal = "Health restored by a medkit",
    aircraftHealthPerGround = "Plane health per ground player",
    gauDamage = "30mm damage per hit",
    gauCadence = "Time between 30mm shots",
    gauReload = "30mm reload time",
    m102Damage = "Howitzer damage per hit",
    m102Reload = "Howitzer reload time",
    roundDuration = "Round length",
    intermission = "Wait between rounds",
    minimumPlayers = "Players needed to start",
}
local subheads = {
    groundHealth = "Health",
    m7Damage = "Rifle",
    rocketDamage = "Rocket launcher",
    medkitHeal = "Medkit · one use per round",
    aircraftHealthPerGround = "Plane health",
    gauDamage = "30mm gun",
    m102Damage = "Howitzer",
}

local function roundCorners(item: GuiObject, radius: number)
    local corners = Instance.new("UICorner")
    corners.CornerRadius = UDim.new(0, radius)
    corners.Parent = item
end
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
    item.Size = UDim2.new(1, 0, 0, 36)
    item.BackgroundColor3 = surface
    item.BorderSizePixel = 0
    item.TextColor3 = accent
    item.TextSize = 15
    item.Font = Enum.Font.BuilderSansBold
    item.Text = caption
    item.TextWrapped = true
    roundCorners(item, 7)
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
    roundCorners(item, 6)
    item.Parent = parent
    return item
end

-- Owns one editor and its global drag listeners. Values use schema units and
-- bounds; slider steps are one HP/player/whole second or 0.05 fractional seconds.
-- Exact typed numbers retain their precision. Invalid text restores the last value.
local function slider(
    parent: ScrollingFrame,
    field: Schema.Field,
    value: number,
    change: (number) -> ()
): () -> ()
    local row = Instance.new("Frame")
    row.Name = field.key .. "Row"
    row.Size = UDim2.new(1, -6, 0, 110)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local title = label(row, captions[field.key] or field.label, 24)
    title.Size = UDim2.new(1, -124, 0, 44)
    local box = input(row, "")
    box.Name = field.key
    box.Size = UDim2.fromOffset(82, 30)
    box.Position = UDim2.new(1, -118, 0, 0)
    local unit = label(row, if field.unit == "s" then "sec" else field.unit, 30)
    unit.Position = UDim2.new(1, -31, 0, 0)
    unit.Size = UDim2.fromOffset(31, 30)
    unit.TextSize = 13
    unit.TextColor3 = muted
    local track = button(row, "")
    track.Name = field.key .. "Slider"
    track.Position = UDim2.fromOffset(0, 48)
    track.Size = UDim2.new(1, 0, 0, 32)
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.fromScale(0, 0.15)
    fill.Position = UDim2.fromScale(0, 0.425)
    fill.Parent = track
    roundCorners(fill, 3)
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.fromOffset(14, 22)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.BackgroundColor3 = accent
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    roundCorners(thumb, 5)
    local low, high = field.minimum :: number, field.maximum :: number
    local step = if field.integer then 1 else 0.05
    local range =
        label(row, string.format("%g%s", low, if field.unit == "s" then " sec" else " " .. field.unit), 18)
    range.Position = UDim2.fromOffset(0, 82)
    range.TextSize = 12
    range.TextColor3 = muted
    local maximum = label(row, string.format("%g", high), 18)
    maximum.Position = UDim2.fromOffset(0, 82)
    maximum.TextXAlignment = Enum.TextXAlignment.Right
    maximum.TextSize = 12
    maximum.TextColor3 = muted
    local current = value
    local function set(nextValue: number)
        current = math.clamp(nextValue, low, high)
        box.Text = string.format("%.6g", current)
        local alpha = (current - low) / (high - low)
        fill.Size = UDim2.fromScale(alpha, 0.15)
        thumb.Position = UDim2.new(alpha, (0.5 - alpha) * 14, 0.5, 0)
        change(current)
    end
    set(value)
    local drag: InputObject? = nil
    local function point(x: number)
        if track.AbsoluteSize.X <= 0 then
            return
        end
        local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local raw = low + (high - low) * alpha
        local nextValue = low + math.floor((raw - low) / step + 0.5) * step
        set(if alpha == 1 then high else nextValue)
    end
    track.InputBegan:Connect(function(event)
        if
            event.UserInputType == Enum.UserInputType.MouseButton1
            or event.UserInputType == Enum.UserInputType.Touch
        then
            drag = event
            parent.ScrollingEnabled = false
            point(event.Position.X)
        elseif event.KeyCode == Enum.KeyCode.Left then
            set(current - step)
        elseif event.KeyCode == Enum.KeyCode.Right then
            set(current + step)
        end
    end)
    box.FocusLost:Connect(function()
        local typed = tonumber(box.Text)
        if typed and typed == typed and math.abs(typed) ~= math.huge then
            set(if field.integer then math.round(typed) else typed)
        else
            set(current)
        end
    end)
    local move = UserInputService.InputChanged:Connect(function(event: InputObject)
        if
            drag
            and (
                event == drag
                or (
                    drag.UserInputType == Enum.UserInputType.MouseButton1
                    and event.UserInputType == Enum.UserInputType.MouseMovement
                )
            )
        then
            point(event.Position.X)
        end
    end)
    local finish = UserInputService.InputEnded:Connect(function(event: InputObject)
        if event == drag then
            drag = nil
            parent.ScrollingEnabled = true
        end
    end)
    return function()
        drag = nil
        parent.ScrollingEnabled = true
        move:Disconnect()
        finish:Disconnect()
    end
end

-- Mount once for RoundState. Access/phase changes dismiss the editor. Requests
-- yield in an owned generation, so late responses cannot resurrect a closed UI.
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
    sheet.Name = "Editor"
    sheet.AnchorPoint = Vector2.new(0.5, 0.5)
    sheet.Position = UDim2.fromScale(0.5, 0.5)
    sheet.Size = UDim2.new(1, -20, 1, -20)
    sheet.BackgroundColor3 = dark
    sheet.BorderSizePixel = 0
    sheet.Visible = false
    sheet.Active = true
    roundCorners(sheet, 12)
    sheet.Parent = gui
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(620, 760)
    limit.Parent = sheet
    local heading = label(sheet, "Game balance", 42)
    heading.Position = UDim2.fromOffset(18, 4)
    heading.Size = UDim2.new(1, -110, 0, 42)
    heading.Font = Enum.Font.BuilderSansBold
    heading.TextSize = 24
    local close = button(sheet, "Close")
    close.Position = UDim2.new(1, -80, 0, 10)
    close.Size = UDim2.fromOffset(62, 32)
    local status = label(sheet, "", 30)
    status.Position = UDim2.fromOffset(18, 46)
    status.Size = UDim2.new(1, -36, 0, 30)
    status.TextColor3 = muted
    status.TextSize = 13
    local preset = button(sheet, "Shipped")
    preset.Name = "ChoosePreset"
    preset.Position = UDim2.fromOffset(18, 80)
    preset.Size = UDim2.new(0.5, -23, 0, 36)
    local nameBox = input(sheet, "Name your preset")
    nameBox.Name = "PresetName"
    nameBox.Position = UDim2.new(0.5, 5, 0, 80)
    nameBox.Size = UDim2.new(0.5, -23, 0, 36)
    local presetMenu = Instance.new("ScrollingFrame")
    presetMenu.Name = "PresetMenu"
    presetMenu.Position = UDim2.fromOffset(18, 120)
    presetMenu.Size = UDim2.new(1, -36, 0, 160)
    presetMenu.BackgroundColor3 = dark
    presetMenu.BorderSizePixel = 0
    presetMenu.ScrollBarThickness = 4
    presetMenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
    presetMenu.CanvasSize = UDim2.fromOffset(0, 0)
    presetMenu.ZIndex = 10
    presetMenu.Visible = false
    presetMenu.Parent = sheet
    local menuRows = Instance.new("UIListLayout")
    menuRows.Padding = UDim.new(0, 4)
    menuRows.Parent = presetMenu
    local tabs: { TextButton } = {}
    for index, group in groups do
        local tab = button(sheet, group.name)
        tab.Name = "Tab" .. tostring(index)
        tab.Position = UDim2.new((index - 1) / 4, 18 - (index - 1) * 7, 0, 128)
        tab.Size = UDim2.new(0.25, -16, 0, 38)
        tab.TextSize = 14
        table.insert(tabs, tab)
    end
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Settings"
    scroll.Position = UDim2.fromOffset(18, 180)
    scroll.Size = UDim2.new(1, -36, 1, -318)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.Parent = sheet
    local rows = Instance.new("UIListLayout")
    rows.SortOrder = Enum.SortOrder.LayoutOrder
    rows.Padding = UDim.new(0, 8)
    rows.Parent = scroll
    local footer = label(sheet, "Combat changes start next round.", 26)
    footer.Position = UDim2.new(0, 18, 1, -132)
    footer.Size = UDim2.new(1, -36, 0, 26)
    footer.TextColor3 = muted
    footer.TextSize = 13
    local save = button(sheet, "Save preset")
    save.Name = "SavePreset"
    save.Position = UDim2.new(0, 18, 1, -102)
    save.Size = UDim2.new(0.5, -23, 0, 36)
    local apply = button(sheet, "Apply saved preset")
    apply.Name = "ApplyPreset"
    apply.Position = UDim2.new(0.5, 5, 1, -102)
    apply.Size = UDim2.new(0.5, -23, 0, 36)
    apply.BackgroundColor3 = accent
    apply.TextColor3 = dark
    local restore = button(sheet, "Undo last apply")
    restore.Position = UDim2.new(0, 18, 1, -58)
    restore.Size = UDim2.new(0.5, -23, 0, 32)
    local refresh = button(sheet, "Refresh")
    refresh.Position = UDim2.new(0.5, 5, 1, -58)
    refresh.Size = UDim2.new(0.5, -23, 0, 32)
    local alive, busy = true, false
    local generation = 0
    local current: View? = nil
    local draft: Fields = {}
    local selectedTab = 1
    local cleanups: { () -> () } = {}
    local connections: { RBXScriptConnection } = {}
    local scale = Instance.new("UIScale")
    scale.Parent = sheet
    local function fit()
        local available = gui.AbsoluteSize - Vector2.new(20, 20)
        local factor = math.clamp(available.Y / 540, 0.5, 1)
        scale.Scale = factor
        limit.MaxSize = Vector2.new(620 / factor, 760)
        sheet.Size = UDim2.fromOffset(math.max(1, available.X / factor), math.max(1, available.Y / factor))
    end
    table.insert(connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
    fit()
    local request: (string, Edit?) -> ()
    local render: () -> ()
    local function clear()
        presetMenu.Visible = false
        for _, cleanup in cleanups do
            cleanup()
        end
        table.clear(cleanups)
        for _, child in scroll:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
    end
    local function hide()
        generation += 1
        busy = false
        sheet.Visible = false
        open.Visible = true
        current = nil
        clear()
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
    render = function()
        if not current then
            return
        end
        clear()
        scroll.CanvasPosition = Vector2.zero
        for index, tab in tabs do
            tab.BackgroundColor3 = if index == selectedTab then accent else surface
            tab.TextColor3 = if index == selectedTab then dark else muted
        end
        for _, key in groups[selectedTab].keys do
            if subheads[key] then
                local caption = label(scroll, subheads[key], 28)
                caption.Font = Enum.Font.BuilderSansBold
                caption.TextColor3 = accent
            end
            local field: Schema.Field? = nil
            for _, candidate in Schema.fields do
                if candidate.key == key then
                    field = candidate
                    break
                end
            end
            if field and field.kind == "number" then
                local summary: TextLabel? = nil
                if key == "aircraftHealthPerGround" then
                    local total = label(scroll, "", 36)
                    total.TextColor3 = muted
                    summary = total
                end
                table.insert(
                    cleanups,
                    slider(scroll, field, draft[key] :: number, function(value)
                        draft[key] = value
                        if summary and current then
                            summary.Text = string.format(
                                "%d ground players × %g HP = %g plane health",
                                current.groundCount,
                                value,
                                current.groundCount * value
                            )
                        end
                    end)
                )
            elseif key == "panelDamage" then
                label(scroll, "Damage needed to break a wall or roof", 32).Font = Enum.Font.BuilderSansBold
                local info = label(scroll, "", 78)
                local choices: { TextButton } = {}
                local function selectTier(tier: string)
                    draft.panelDamage = tier
                    local hits = if tier == "Low" then 2 else 1
                    local seconds = if tier == "Low" then 4 elseif tier == "High" then 1 else 2
                    info.Text = string.format(
                        "%d howitzer hit%s\nor %d seconds of 30mm hits on the same panel.\nDamage stays when you stop firing.",
                        hits,
                        if hits == 1 then "" else "s",
                        seconds
                    )
                    for _, choice in choices do
                        choice.BackgroundColor3 = if choice.Name == tier then accent else surface
                        choice.TextColor3 = if choice.Name == tier then dark else ink
                    end
                end
                for _, tier in { "Low", "Medium", "High" } do
                    local control = button(scroll, tier .. " damage")
                    control.Name = tier
                    table.insert(choices, control)
                    control.Activated:Connect(function()
                        selectTier(tier)
                    end)
                end
                selectTier(tostring(draft.panelDamage))
            end
        end
        if selectedTab == 1 then
            label(scroll, "Medkit pickups arrive in the medkit update.", 36).TextColor3 = muted
        elseif selectedTab == 4 then
            label(
                scroll,
                "The player minimum updates while waiting. A new wait length starts after the next result.",
                52
            ).TextColor3 =
                muted
            if current and current.owner then
                label(scroll, "Trusted testers", 32).Font = Enum.Font.BuilderSansBold
                local ids: { string } = {}
                for _, id in current.trusted do
                    table.insert(ids, tostring(id))
                end
                label(scroll, if #ids == 0 then "No testers added" else table.concat(ids, ", "), 32)
                local user = input(scroll, "Roblox user ID")
                for _, action in { { "Give panel access", "grant" }, { "Remove panel access", "revoke" } } do
                    button(scroll, action[1]).Activated:Connect(function()
                        request(action[2], { userId = tonumber(user.Text) })
                    end)
                end
            end
            if current then
                label(
                    scroll,
                    string.format(
                        "Saved change %d · Round uses change %d\nStorage: %s",
                        current.activeRevision,
                        current.roundRevision,
                        current.storageStatus
                    ),
                    48
                ).TextColor3 =
                    muted
            end
        end
    end
    request = function(verb, fields)
        if busy or not alive or not gui.Enabled then
            return
        end
        local remote = ReplicatedStorage:FindFirstChild("BalanceAdmin")
        if not remote or not remote:IsA("RemoteFunction") then
            status.Text = "Settings unavailable. Try Refresh."
            return
        end
        local args: Edit = fields or {}
        args.action = verb
        if verb ~= "read" and current then
            args.revision = current.revision
        end
        local stamp = generation
        busy = true
        status.Text = "Saving…"
        task.spawn(function()
            local ok, reply = pcall(function()
                return remote:InvokeServer(args)
            end)
            if not alive or stamp ~= generation then
                return
            end
            busy = false
            if not ok or type(reply) ~= "table" then
                status.Text = "Connection failed. Try Refresh."
                return
            end
            if reply.ok ~= true or not reply.view then
                status.Text = tostring(reply.error or "Could not save. Try Refresh.")
                return
            end
            current = reply.view :: View
            local view = current :: View
            local name = if verb == "save" then tostring(args.name) else view.activeName
            draft = table.clone(if verb == "save" then view.presets[name] else view.settings)
            nameBox.Text = name
            preset.Text = "Choose preset · " .. name
            status.Text = if verb == "save"
                then "Saved. Select Apply saved preset to use it."
                elseif verb == "apply" or verb == "restore" then "Applied · " .. view.activeName
                elseif verb == "read" then "Live preset · " .. view.activeName
                else "Tester access updated."
            render()
        end)
    end
    for index, tab in tabs do
        tab.Activated:Connect(function()
            selectedTab = index
            render()
        end)
    end
    preset.Activated:Connect(function()
        if busy or not current then
            return
        end
        local names: { string } = {}
        for name in current.presets do
            table.insert(names, name)
        end
        table.sort(names)
        if presetMenu.Visible then
            presetMenu.Visible = false
            return
        end
        for _, child in presetMenu:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        for _, name in names do
            local choice = button(presetMenu, name)
            choice.ZIndex = 11
            choice.Activated:Connect(function()
                if busy or not current then
                    return
                end
                draft = table.clone(current.presets[name])
                nameBox.Text = name
                preset.Text = "Choose preset · " .. name
                status.Text = "Editing · " .. name
                render()
            end)
        end
        presetMenu.Visible = true
    end)
    save.Activated:Connect(function()
        draft.medkitSingleUse = true
        draft.medkitRespawn = Schema.defaults.medkitRespawn
        draft.m102Cadence = draft.m102Reload
        request("save", { name = nameBox.Text, settings = table.clone(draft) })
    end)
    apply.Activated:Connect(function()
        request("apply", { name = nameBox.Text })
    end)
    restore.Activated:Connect(function()
        request("restore", nil)
    end)
    refresh.Activated:Connect(function()
        request("read", nil)
    end)
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
        clear()
        for _, connection in connections do
            connection:Disconnect()
        end
        gui:Destroy()
    end
end
return BalancePanel
