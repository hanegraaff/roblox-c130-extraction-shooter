--!strict
-- P08 A3/R04 regression: real Player/LoadCharacterAsync/removal/destruction signals.
-- Internal owner cleanup must not eliminate a life; removal of its current
-- character must eliminate exactly once. Runs before GameRuntime owns players
-- and reloads a ready avatar at its prior pose before restoring autoload settings.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Server = game:GetService("ServerScriptService").Server
    local CharacterOwner = require(Server.CharacterOwner)
    local MatchService = require(Server.MatchService)
    local function waitFor(predicate: () -> boolean, label: string)
        local deadline = os.clock() + 30
        while not predicate() and os.clock() < deadline do
            task.wait(0.03)
        end
        assert(predicate(), "CharacterOwner timeout: " .. label)
    end
    test("P08 owned character removal eliminates once while internal clear preserves the life", function()
        local player = Players:GetPlayers()[1]
        assert(player, "real player required")
        local autoLoads = Players.CharacterAutoLoads
        if autoLoads then
            waitFor(function()
                local character = player.Character
                return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
            end, "initial automatic character")
        end
        local previous = player.Character
        local previousRoot = if previous then previous:FindFirstChild("HumanoidRootPart") else nil
        local restorePose = if previousRoot and previousRoot:IsA("BasePart")
            then previousRoot.CFrame
            else workspace.World.Battlefield.Anchors.Ground01.CFrame
        local restoreAnchored = if previousRoot and previousRoot:IsA("BasePart")
            then previousRoot.Anchored
            else false
        local owned: CharacterOwner.Controller? = nil
        local ok, failure = pcall(function()
            Players.CharacterAutoLoads = false
            local released = 0
            local selected: MatchService.Controller? = nil
            local dummyIds = { -900000001, -900000002 }
            for seed = 1, 20 do
                local candidate = MatchService.new(
                    { minimumPlayers = 2, durationSeconds = 600, seed = seed },
                    {
                        now = function()
                            return workspace:GetServerTimeNow()
                        end,
                        releaseLife = function(id)
                            if id == player.UserId then
                                released += 1
                            end
                        end,
                    }
                )
                candidate.join(player.UserId)
                for _, id in dummyIds do
                    candidate.join(id)
                end
                assert(candidate.deploy(), "fixture deploy")
                if candidate.snapshot().members[player.UserId].role == "Ground" then
                    selected = candidate
                    break
                end
            end
            assert(selected, "fixture could not assign real ground player")
            local match = selected
            local owner = CharacterOwner.new(player, match)
            owned = owner
            local roundId = match.snapshot().roundId
            owner.request("Ground01", "Ground", roundId)
            waitFor(function()
                return owner.resources().spawnTasks == 0 and player.Character ~= nil
            end, "first owned avatar")
            for _, id in dummyIds do
                assert(match.ready(id, roundId), "dummy ready")
            end
            assert(match.activate(), "fixture active")
            local first = player.Character
            assert(first, "first character missing")
            owner.clear()
            RunService.Heartbeat:Wait()
            match.step()
            assert(player.Character == nil and first.Parent == nil, "internal clear retained character")
            assert(
                match.snapshot().members[player.UserId].life == "Alive" and released == 0,
                "internal clear falsely eliminated"
            )
            owner.request("Ground02", "Ground", roundId)
            waitFor(function()
                return owner.resources().spawnTasks == 0 and player.Character ~= nil
            end, "replacement owned avatar")
            local current = player.Character
            assert(current and current ~= first, "new generation not loaded")
            -- Exact regression: Destroy() without clearing Player.Character.
            -- Studio may retain that property while the model loses its parent.
            current:Destroy()
            waitFor(function()
                return match.snapshot().members[player.UserId].life == "Eliminated"
            end, "external removal elimination")
            match.step()
            match.step()
            assert(
                released == 1 and match.snapshot().phase == "Active",
                "removal was duplicated or ended populated round"
            )
            owner.clear()
            owner.stop()
            owner.stop()
            match.step()
            assert(released == 1 and player.Character == nil, "cleanup restored life or released twice")
            assert(
                owner.resources().connections == 0 and owner.resources().spawnTasks == 0,
                "character owner resources survived"
            )
        end)
        -- LoadCharacterAsync can destroy earlier avatar models even if they
        -- were parked outside Workspace. Never restore an old model reference
        -- or assume CharacterAutoLoads recreates a character after manual removal.
        local cleanupOk, cleanupFailure = pcall(function()
            local owner = owned
            if owner then
                owner.stop()
                waitFor(function()
                    return owner.resources().spawnTasks == 0
                end, "fixture load drain")
            end
            assert(player:GetAttribute("RoundCharacterLoad") == nil, "fixture avatar load lease survived")
            player:LoadCharacterAsync()
            waitFor(function()
                local character = player.Character
                local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
                return character ~= nil
                    and character:IsDescendantOf(workspace)
                    and root ~= nil
                    and root:IsA("BasePart")
                    and humanoid ~= nil
                    and humanoid.Health > 0
            end, "restored ready avatar")
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            assert(character and root and root:IsA("BasePart"), "restored avatar vanished")
            character:PivotTo(restorePose)
            root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
            root.Anchored = restoreAnchored
            assert(
                root.Parent == character and character.Parent ~= nil,
                "restoration returned an unparented avatar"
            )
        end)
        Players.CharacterAutoLoads = autoLoads
        assert(cleanupOk, "CharacterOwner fixture cleanup failed: " .. tostring(cleanupFailure))
        assert(ok, tostring(failure))
    end)
end
