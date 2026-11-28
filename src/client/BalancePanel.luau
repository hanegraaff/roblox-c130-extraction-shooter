--!strict
--[=[
    Client lobby editor for server-owned balance presets. Four tabs share one draft.
    Numeric controls support mouse/touch sliders, keyboard arrows and exact entry.
    Save persists the draft. Apply selects a saved preset or saves and applies an
    edited draft in one server transaction. All remote authority
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
    medkitHeal = "Maximum health restored by a medkit",
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
    close.Name = "CloseEditor"
    close.Position = UDim2.new(1, -80, 0, 10)
    close.Size = UDim2.fromOffset(62, 32)
    local live = label(sheet, "Loading live settings…", 28)
    live.Name = "LiveSettings"
    live.Position = UDim2.fromOffset(18, 46)
    live.Size = UDim2.new(1, -128, 0, 28)
    live.TextColor3 = accent
    live.TextSize = 14
    local refresh = button(sheet, "Refresh")
    refresh.Position = UDim2.new(1, -100, 0, 46)
    refresh.Size = UDim2.fromOffset(82, 28)
    local library = Instance.new("Frame")
    library.Name = "PresetLibrary"
    library.Position = UDim2.fromOffset(18, 84)
    library.Size = UDim2.new(1, -36, 0, 140)
    library.BackgroundColor3 = Color3.fromRGB(28, 42, 44)
    library.BorderSizePixel = 0
    roundCorners(library, 8)
    library.Parent = sheet
    local libraryTitle = label(library, "Saved presets", 26)
    libraryTitle.Position = UDim2.fromOffset(10, 3)
    libraryTitle.Font = Enum.Font.BuilderSansBold
    local preset = button(library, "Load Settings")
    preset.Name = "ChoosePreset"
    preset.Position = UDim2.fromOffset(10, 34)
    preset.Size = UDim2.new(0.5, -15, 0, 32)
    local nameBox = input(library, "Preset name")
    nameBox.Name = "PresetName"
    nameBox.Position = UDim2.new(0.5, 5, 0, 34)
    nameBox.Size = UDim2.new(0.5, -15, 0, 32)
    local save = button(library, "Save preset")
    save.Name = "SavePreset"
    save.Position = UDim2.fromOffset(10, 74)
    save.Size = UDim2.new(1 / 3, -13, 0, 32)
    local apply = button(library, "Apply preset")
    apply.Name = "ApplyPreset"
    apply.Position = UDim2.new(1 / 3, 3, 0, 74)
    apply.Size = UDim2.new(1 / 3, -13, 0, 32)
    local delete = button(library, "Delete preset")
    delete.Name = "DeletePreset"
    delete.Position = UDim2.new(2 / 3, -3, 0, 74)
    delete.Size = UDim2.new(1 / 3, -13, 0, 32)
    local status = label(library, "Loading saved presets…", 26)
    status.Name = "PresetFeedback"
    status.Position = UDim2.fromOffset(10, 110)
    status.Size = UDim2.new(1, -20, 0, 26)
    status.TextSize = 13
    status.TextColor3 = muted
    local function menu(name: string, y: number): ScrollingFrame
        local list = Instance.new("ScrollingFrame")
        list.Name = name
        list.Position = UDim2.fromOffset(18, y)
        list.Size = UDim2.new(1, -36, 0, 160)
        list.BackgroundColor3 = dark
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 4
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.CanvasSize = UDim2.fromOffset(0, 0)
        list.ZIndex = 10
        list.Visible = false
        list.Parent = sheet
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.Parent = list
        return list
    end
    local presetMenu = menu("PresetMenu", 152)
    local categoryMenu = menu("CategoryMenu", 272)
    local category = button(sheet, "Settings · Player v")
    category.Name = "ChooseCategory"
    category.Position = UDim2.fromOffset(18, 236)
    category.Size = UDim2.new(1, -36, 0, 36)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Settings"
    scroll.Position = UDim2.fromOffset(18, 284)
    scroll.Size = UDim2.new(1, -36, 1, -324)
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
    local footer = label(sheet, "Combat changes start next round.", 28)
    footer.Name = "EditingSettings"
    footer.Position = UDim2.new(0, 18, 1, -34)
    footer.Size = UDim2.new(1, -36, 0, 28)
    footer.TextColor3 = muted
    footer.TextSize = 13
    local alive, busy = true, false
    local generation = 0
    local current: View? = nil
    local draft: Fields = {}
    local selectedTab = 1
    local loadedPreset: string? = nil
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
    local function matchesDraft(saved: Fields): boolean
        for key, value in saved do
            if draft[key] ~= value then
                return false
            end
        end
        return true
    end
    local function canApply(): boolean
        if busy or not current or not loadedPreset or nameBox.Text ~= Schema.presetLabel(loadedPreset) then
            return false
        end
        local saved = current.presets[loadedPreset]
        return saved ~= nil and matchesDraft(saved)
    end
    local function canSave(): boolean
        if busy or not current then
            return false
        end
        local saved = if loadedPreset then current.presets[loadedPreset] else nil
        local originalName = if loadedPreset then Schema.presetLabel(loadedPreset) else ""
        return Schema.canSavePresetName(nameBox.Text, originalName, saved ~= nil and not matchesDraft(saved))
    end
    local function updateActions()
        local saveReady = canSave()
        save.Active = saveReady
        save.Selectable = saveReady
        save.AutoButtonColor = saveReady
        save.TextColor3 = if saveReady then accent else muted
        local ready = saveReady or canApply()
        apply.Text = if saveReady then "Save & apply" else "Apply preset"
        apply.BackgroundColor3 = if ready then accent else surface
        apply.TextColor3 = if ready then dark else muted
        apply.Active = ready
        apply.Selectable = ready
        local removable = not busy and loadedPreset ~= nil and loadedPreset ~= Schema.builtinPresetKey
        delete.Active = removable
        delete.Selectable = removable
        delete.TextColor3 = if removable then Color3.fromRGB(239, 164, 151) else muted
        local liveMatches = current ~= nil
            and loadedPreset == current.activeName
            and matchesDraft(current.settings)
        footer.Text = if saveReady
            then "Save & apply to use these changes in the next round."
            elseif ready and liveMatches then "Matches live settings · Combat changes start next round."
            elseif ready then "Select Apply preset to use these saved values."
            elseif
                loadedPreset == Schema.builtinPresetKey
            then "Enter a custom name to save a copy of Default."
            else "Enter a valid preset name to save."
    end
    local request: (string, Edit?) -> ()
    local render: () -> ()
    local function clear()
        presetMenu.Visible = false
        categoryMenu.Visible = false
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
        gui:SetAttribute("InputOverlayOpen", false)
        open.Visible = true
        current = nil
        clear()
    end
    local hud = parent:FindFirstChild("RoundHUD")
    local function eligibility()
        local phase = round:GetAttribute("Phase")
        local view = if hud then hud:GetAttribute("View") else nil
        local inRoundLobby = (phase == "Active" or phase == "Scatter") and view == "RoundLobby"
        -- Use the current round phase during return. The HUD's last combat
        -- view may still be visible in the frame that replicates the phase.
        local inLobby = (phase == "Lobby" and view ~= "GroundPreview" and view ~= "OperatorPreview")
            or phase == "Results"
            or phase == "Resetting"
            or inRoundLobby
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
        category.Text = "Settings · " .. groups[selectedTab].name .. " v"
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
                        if key == "m102Reload" then
                            draft.m102Cadence = value
                        end
                        updateActions()
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
                local choiceRow = Instance.new("Frame")
                choiceRow.Name = "PanelDamageChoice"
                choiceRow.Size = UDim2.new(1, -6, 0, 36)
                choiceRow.BackgroundTransparency = 1
                choiceRow.Parent = scroll
                local control = button(choiceRow, "")
                control.Name = "PanelDamage"
                local options = Instance.new("Frame")
                options.Name = "Options"
                options.Position = UDim2.fromOffset(0, 40)
                options.Size = UDim2.new(1, 0, 0, 120)
                options.BackgroundTransparency = 1
                options.Visible = false
                options.Parent = choiceRow
                local layout = Instance.new("UIListLayout")
                layout.Padding = UDim.new(0, 4)
                layout.Parent = options
                local function selectTier(tier: string)
                    draft.panelDamage = tier
                    control.Text = tier .. " damage v"
                    local hits = if tier == "Low" then 2 else 1
                    local seconds = if tier == "Low" then 4 elseif tier == "High" then 1 else 2
                    info.Text = string.format(
                        "%d howitzer hit%s\nor %d seconds of 30mm hits on the same panel.\nDamage stays when you stop firing.",
                        hits,
                        if hits == 1 then "" else "s",
                        seconds
                    )
                    options.Visible = false
                    choiceRow.Size = UDim2.new(1, -6, 0, 36)
                    updateActions()
                end
                control.Activated:Connect(function()
                    options.Visible = not options.Visible
                    choiceRow.Size = UDim2.new(1, -6, 0, if options.Visible then 160 else 36)
                end)
                for _, tier in { "Low", "Medium", "High" } do
                    local option = button(options, tier .. " damage")
                    option.Name = tier
                    option.Activated:Connect(function()
                        selectTier(tier)
                    end)
                end
                selectTier(tostring(draft.panelDamage))
            end
        end
        if selectedTab == 4 then
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
                        "Live revision %d · Round uses revision %d\nStorage: %s",
                        current.activeRevision,
                        current.roundRevision,
                        current.storageStatus
                    ),
                    48
                ).TextColor3 =
                    muted
            end
        end
        updateActions()
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
        status.Text = if verb == "read" then "Loading saved presets…" else "Saving…"
        updateActions()
        task.spawn(function()
            local ok, reply = pcall(function()
                return remote:InvokeServer(args)
            end)
            if not alive or stamp ~= generation then
                return
            end
            busy = false
            updateActions()
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
            live.Text = "Live in game · " .. Schema.presetLabel(view.activeName)
            if verb == "delete" then
                loadedPreset = nil
                draft = (table.clone(Schema.defaults) :: unknown) :: Fields
                nameBox.Text = ""
            else
                local name = if verb == "save" then tostring(args.name) else view.activeName
                loadedPreset = if view.presets[name] then name else nil
                draft = table.clone(view.presets[name] or view.settings)
                nameBox.Text = if loadedPreset then Schema.presetLabel(name) else ""
            end
            status.Text = if verb == "delete"
                then "Preset deleted. Enter a name to save a copy, or close."
                elseif verb == "save" then "Saved. Select Apply preset to use it."
                elseif verb == "apply" or verb == "saveAndApply" then "Applied · " .. Schema.presetLabel(
                    view.activeName
                )
                elseif verb == "read" then "Choose a preset to edit. Live settings are shown above."
                else "Tester access updated."
            render()
        end)
    end
    for index, group in groups do
        local option = button(categoryMenu, group.name)
        option.Name = "Category" .. tostring(index)
        option.ZIndex = 11
        option.Activated:Connect(function()
            selectedTab = index
            render()
        end)
    end
    category.Activated:Connect(function()
        if not busy and current then
            categoryMenu.Visible = not categoryMenu.Visible
            presetMenu.Visible = false
        end
    end)
    nameBox:GetPropertyChangedSignal("Text"):Connect(updateActions)
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
            local caption = if name == Schema.builtinPresetKey then "Default · read only" else name
            local choice = button(presetMenu, caption)
            choice.Name = name
            choice.ZIndex = 11
            choice.Activated:Connect(function()
                if busy or not current then
                    return
                end
                loadedPreset = name
                draft = table.clone(current.presets[name])
                nameBox.Text = Schema.presetLabel(name)
                status.Text = "Loaded into editor · " .. nameBox.Text
                render()
            end)
        end
        categoryMenu.Visible = false
        presetMenu.Visible = true
    end)
    local function saveDraft(action: string)
        local values = table.clone(draft)
        values.medkitSingleUse = true
        values.medkitRespawn = Schema.defaults.medkitRespawn
        values.m102Cadence = values.m102Reload
        request(action, { name = nameBox.Text, settings = values })
    end
    save.Activated:Connect(function()
        if canSave() then
            saveDraft("save")
        end
    end)
    apply.Activated:Connect(function()
        if canSave() then
            saveDraft("saveAndApply")
        elseif canApply() then
            request("apply", { name = loadedPreset })
        end
    end)
    delete.Activated:Connect(function()
        if loadedPreset and loadedPreset ~= Schema.builtinPresetKey then
            request("delete", { name = loadedPreset })
        end
    end)
    refresh.Activated:Connect(function()
        request("read", nil)
    end)
    table.insert(
        connections,
        open.Activated:Connect(function()
            sheet.Visible, open.Visible = true, false
            gui:SetAttribute("InputOverlayOpen", true)
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
        if not alive then
            return
        end
        alive = false
        clear()
        for _, connection in connections do
            connection:Disconnect()
        end
        gui:Destroy()
    end
end
return BalancePanel
