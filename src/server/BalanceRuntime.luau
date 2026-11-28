--!strict
--[=[
    Server engine adapter for admin access, persistent presets and cross-server
    notifications. Runs cloud calls off the match frame. Only the numeric revision
    is broadcast to other servers; each fetches its own authoritative record.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Schema = require(ReplicatedStorage.Shared.BalanceSchema)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Record = require(script.Parent.BalanceRecord)
local Service = require(script.Parent.BalanceService)
local BalanceRuntime = {}

-- Studio fixtures may inject isolated storage, principals and a notification bus.
-- Production constructs its own adapters and always uses the sending Player.UserId.
export type Dependencies = Service.Storage & {
    ownerId: () -> number?,
    actorId: ((Player) -> number)?,
    subscribe: ((number) -> ()) -> () -> (),
    notify: (number) -> (),
}
export type Controller = {
    getBalance: () -> Schema.Values,
    latest: () -> Record.Record,
    roundRevision: () -> number,
    beforeDeployment: () -> boolean,
    capture: () -> (),
    stop: () -> (),
}

local function production(): Dependencies
    local data = game:GetService("DataStoreService")
    local messaging = game:GetService("MessagingService")
    local groups = game:GetService("GroupService")
    local topic = "BalanceRevision_v1"
    local options = Instance.new("DataStoreGetOptions")
    options.UseCache = false
    local function store()
        return data:GetDataStore("Balance_v1")
    end
    return {
        ownerId = function(): number?
            if game.CreatorId <= 0 then
                return nil
            end
            if game.CreatorType == Enum.CreatorType.User then
                return game.CreatorId
            end
            local info = groups:GetGroupInfoAsync(game.CreatorId)
            return if info.Owner then info.Owner.Id else nil
        end,
        read = function(): unknown
            return store():GetAsync("Settings", options)
        end,
        update = function(change: (unknown) -> unknown): unknown
            return store():UpdateAsync("Settings", change)
        end,
        subscribe = function(receive: (number) -> ()): () -> ()
            local conn = messaging:SubscribeAsync(topic, function(message)
                if type(message.Data) == "number" then
                    receive(message.Data)
                end
            end)
            return function()
                conn:Disconnect()
            end
        end,
        notify = function(revision: number)
            messaging:PublishAsync(topic, revision)
        end,
    }
end

-- Starts the remote and asynchronous refresh loop. Ordinary Studio Play uses
-- shipped defaults, with no live storage access. Test dependencies only run in Studio.
function BalanceRuntime.start(injected: Dependencies?, groundCount: () -> number): (Controller?, string?)
    if ReplicatedStorage:FindFirstChild("BalanceAdmin") then
        return nil, "balance panel already owned"
    end
    if injected and not RunService:IsStudio() then
        return nil, "external balance adapters require Studio"
    end
    local deps = if injected then injected else production()
    local offline = RunService:IsStudio() and injected == nil
    local service = Service.new(deps)
    local active = true
    local buckets: { [Player]: RateLimit.Bucket } = {}
    local busy: { [Player]: boolean } = {}
    local unsubscribe: (() -> ())? = nil
    local cachedOwner: number? = nil
    local deploymentReadStarted: number? = nil
    local deploymentReadFinished: number? = nil
    local refreshing = false
    local function principal(player: Player): number
        return if deps.actorId then deps.actorId(player) else player.UserId
    end
    local function hint(player: Player)
        if active and player.Parent == Players then
            player:SetAttribute(
                "BalanceAdminAccess",
                Record.allowed(service.latest(), principal(player), cachedOwner)
            )
        end
    end
    local function hints()
        for _, player in Players:GetPlayers() do
            hint(player)
        end
    end
    local function currentOwner(): number?
        local ok, value = pcall(deps.ownerId)
        if not ok then
            -- Keep the last confirmed UI hint during an owner lookup outage.
            -- A request still needs fresh ownership or a stored tester grant.
            return nil
        end
        local owner = if type(value) == "number" and value > 0 then value else nil
        if active then
            cachedOwner = owner
        end
        return owner
    end
    local function refresh()
        if refreshing or not active or offline then
            return
        end
        refreshing = true
        currentOwner()
        service.refresh()
        if active then
            hints()
        end
        refreshing = false
    end
    local remote = Instance.new("RemoteFunction")
    remote.Name = "BalanceAdmin"
    local function handle(player: Player, raw: unknown)
        local request, why = Record.request(raw)
        if not request then
            return { ok = false, error = why }
        end
        local actor = principal(player)
        -- Reject an ordinary client before spending a cloud request. A cached grant
        -- is only a hint; read refresh and atomic write recheck the authoritative ACL.
        if offline or not Record.allowed(service.latest(), actor, cachedOwner) then
            return { ok = false, error = "Admin access denied." }
        end
        local owner = currentOwner()
        local function connected(): boolean
            return active and player.Parent == Players
        end
        if not connected() then
            return { ok = false, error = "Session ended." }
        end
        if request.action == "read" then
            local fresh = service.refresh()
            if not fresh and actor ~= owner then
                return { ok = false, error = "Cannot confirm tester access. Try again." }
            end
        else
            local saved, err = service.write(request, actor, owner, connected)
            if not saved then
                return { ok = false, error = err }
            end
            local revision = service.latest().revision
            task.spawn(function()
                local ok = pcall(deps.notify, revision)
                if not ok and active then
                    warn("Balance notification unavailable; servers will refresh from storage.")
                end
            end)
        end
        if not connected() then
            return { ok = false, error = "Session ended." }
        end
        hints()
        local record = service.latest()
        if not Record.allowed(record, actor, owner) then
            return { ok = false, error = "Admin access denied." }
        end
        return {
            ok = true,
            view = {
                revision = record.revision,
                activeRevision = record.activeRevision,
                roundRevision = service.round().activeRevision,
                activeName = record.activeName,
                settings = record.settings,
                presets = record.presets,
                trusted = if owner == actor then record.trusted else {},
                owner = owner == actor,
                savedBy = record.savedBy,
                groundCount = groundCount(),
                storageStatus = service.status(),
            },
        }
    end
    remote.OnServerInvoke = function(player: Player, raw: unknown)
        if not active or player.Parent ~= Players then
            return { ok = false, error = "Session ended." }
        end
        local now = os.clock()
        local bucket = buckets[player]
        if not bucket then
            bucket = assert(RateLimit.new(5, 0.5, now))
            buckets[player] = bucket
        end
        if busy[player] or not RateLimit.take(bucket, now) then
            return { ok = false, error = "Please wait before trying again." }
        end
        busy[player] = true
        local ok, response = pcall(handle, player, raw)
        busy[player] = nil
        if not ok then
            warn("Unable to process balance request: " .. tostring(response))
            return { ok = false, error = "Unable to process request." }
        end
        return response
    end
    remote.Parent = ReplicatedStorage
    local join = Players.PlayerAdded:Connect(hint)
    local leave = Players.PlayerRemoving:Connect(function(player)
        buckets[player] = nil
        busy[player] = nil
    end)
    hints()
    -- A pending timer can be canceled immediately. In-flight subscriptions
    -- release their own connection on return if teardown happened while yielding.
    local timer: thread? = nil
    local function poll()
        timer = nil
        if not active or offline then
            return
        end
        refresh()
        if active and not unsubscribe then
            local ok, close = pcall(deps.subscribe, function(revision: number)
                if active and revision > service.latest().revision then
                    refresh()
                end
            end)
            if ok and close then
                if active then
                    unsubscribe = close
                else
                    close()
                end
            end
        end
        if active then
            timer = task.delay(20, poll)
        end
    end
    timer = task.defer(poll)
    return {
        getBalance = function()
            return service.round().settings
        end,
        latest = service.latest,
        roundRevision = function()
            return service.round().activeRevision
        end,
        beforeDeployment = function()
            if offline then
                return true
            end
            local now = os.clock()
            if deploymentReadFinished and now - deploymentReadFinished < 5 then
                return true
            end
            if deploymentReadStarted and not deploymentReadFinished then
                -- A throttled cloud operation cannot stall a playable lobby indefinitely.
                return now - deploymentReadStarted >= 3
            end
            deploymentReadStarted = now
            deploymentReadFinished = nil
            task.defer(function()
                service.refresh()
                if active and deploymentReadStarted == now then
                    deploymentReadFinished = os.clock()
                    hints()
                end
            end)
            return false
        end,
        capture = function()
            service.capture()
            deploymentReadStarted, deploymentReadFinished = nil, nil
        end,
        stop = function()
            if not active then
                return
            end
            active = false
            service.stop()
            join:Disconnect()
            leave:Disconnect()
            if unsubscribe then
                unsubscribe()
            end
            if timer then
                task.cancel(timer)
            end
            remote:Destroy()
            for _, player in Players:GetPlayers() do
                player:SetAttribute("BalanceAdminAccess", nil)
            end
        end,
    },
        nil
end
return BalanceRuntime
