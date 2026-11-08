--!strict
-- Actual one-client engine regression for human test request validation, previews,
-- settings, restart and teardown. The dedicated harness supplies TestEZ lifecycle hooks.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    local beforeAll = getfenv().beforeAll :: (() -> ()) -> ()
    local afterAll = getfenv().afterAll :: (() -> ()) -> ()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local GameRuntime = require(game.ServerScriptService.Server.GameRuntime)
    local Session = require(script.Parent.HumanTestSession)
    local args = game:GetService("StudioTestService"):GetTestArgs()
    local multiplayer = type(args) == "table" and args.kind == "HumanTestMultiplayer"
    local session: Session.Controller
    local player: Player
    local sequence = 0
    local function waitFor(predicate: () -> boolean)
        local deadline = os.clock() + 30
        while not predicate() and os.clock() < deadline do
            task.wait(0.05)
        end
        assert(predicate(), "human control assertion timed out")
    end
    local function controls(): Instance
        local value = ReplicatedStorage:FindFirstChild("StudioTestControls")
        assert(value, "human controls missing")
        return value
    end
    local function request(action: string, value: unknown?): (boolean, string?)
        task.wait(0.4) -- Exercise the real rate limiter without exhausting normal traffic.
        sequence += 1
        return session.request(player, {
            action = action,
            value = value,
            sequence = sequence,
            generation = controls():GetAttribute("Generation"),
        })
    end
    local function root(): BasePart
        local character = player.Character
        local value = character and character:FindFirstChild("HumanoidRootPart")
        assert(value and value:IsA("BasePart"), "ready character missing")
        return value
    end
    beforeAll(function()
        waitFor(function()
            return #Players:GetPlayers() == (if multiplayer then 2 else 1)
        end)
        player = Players:GetPlayers()[1]
        local runtime, reason = GameRuntime.start({
            automaticDeployment = false,
            minimumPlayers = 2,
            durationSeconds = 60,
            lobbySeconds = 0,
            deploymentSeconds = 25,
            resultsSeconds = 3,
            seed = 1,
        })
        assert(runtime, reason)
        session = Session.start(runtime)
        waitFor(function()
            return player.Character ~= nil and not player:GetAttribute("RoundCharacterLoad")
        end)
        if not multiplayer then
            waitFor(function()
                return player:GetAttribute("LocalMapPreview") == true
            end)
        end
    end)
    afterAll(function()
        session.stop()
        session.stop()
        assert(not ReplicatedStorage:FindFirstChild("StudioTestControls"), "human transport leaked")
        assert(not game.ServerStorage:FindFirstChild("LocalTestControls"), "preview shortcuts leaked")
        assert(not ReplicatedStorage:FindFirstChild("RoundState"), "runtime state leaked")
        assert(
            player:GetAttribute("LocalMapPreview") == nil
                and player:GetAttribute("LocalTestRoleChoice") == nil,
            "test attributes leaked"
        )
        waitFor(function()
            return Players:GetAttribute("RoundCharacterTeardown") == nil
        end)
    end)
    test("malformed stale and invalid role requests cannot change settings", function()
        local generation = controls():GetAttribute("Generation")
        local rejected: { unknown } = {
            false,
            { action = "Role", value = "Gunship", sequence = 0 / 0, generation = generation },
            { action = "Role", value = "Gunship", sequence = 1, generation = -1 },
            { action = "Role", value = "Unknown", sequence = 1, generation = generation },
            { action = "Role", value = "Gunship", sequence = 1, generation = generation, extra = true },
        }
        for _, payload in rejected do
            task.wait(0.4)
            assert(not session.request(player, payload), "invalid request accepted")
        end
        assert(
            player:GetAttribute("LocalTestRoleChoice") == "Auto"
                and controls():GetAttribute("RoundSeconds") == 60,
            "rejection changed test settings"
        )
    end)
    if multiplayer then
        local otherSequence = 0
        local function other(): Player
            for _, candidate in Players:GetPlayers() do
                if candidate ~= player then
                    return candidate
                end
            end
            error("second actual client disconnected")
        end
        local function otherRequest(action: string, value: unknown?): (boolean, string?)
            task.wait(0.4)
            otherSequence += 1
            return session.request(other(), {
                action = action,
                value = value,
                sequence = otherSequence,
                generation = controls():GetAttribute("Generation"),
            })
        end
        test("two Operator choices and all-Ground choices reject without starting a round", function()
            assert(request("Role", "Gunship"), "first choice rejected")
            assert(otherRequest("Role", "Gunship"), "second choice rejected")
            assert(not request("Start"), "conflicting Operators were silently reassigned")
            assert(request("Role", "Ground"), "ground choice rejected")
            assert(otherRequest("Role", "Ground"), "other ground choice rejected")
            assert(not request("Start"), "all-Ground roster created a fake operator")
            assert(ReplicatedStorage.RoundState:GetAttribute("Phase") == "Lobby", "rejection changed phase")
        end)
        test("start skips the wait and gives the two actual clients their requested roles", function()
            assert(otherRequest("Role", "Gunship"), "operator choice rejected")
            assert(request("Duration", 30), "duration rejected")
            assert(request("Start"), "valid role roster rejected")
            waitFor(function()
                return ReplicatedStorage.RoundState:GetAttribute("Phase") == "Active"
                    and controls():GetAttribute("Busy") == false
            end)
            assert(
                player:GetAttribute("Role") == "Ground" and other():GetAttribute("Role") == "Gunship",
                "actual roles do not match requests"
            )
            assert(not root().Anchored, "ground character locked")
            local operatorBody = other().Character
            local operatorRoot = operatorBody and operatorBody:FindFirstChild("HumanoidRootPart")
            assert(
                operatorRoot and operatorRoot:IsA("BasePart") and operatorRoot.Anchored,
                "operator station unlocked"
            )
            local remaining = ReplicatedStorage.RoundState:GetAttribute("DeadlineSeconds")
            assert(
                type(remaining) == "number" and remaining - workspace:GetServerTimeNow() <= 30,
                "chosen duration not applied"
            )
        end)
        test("role changes leave the active round intact and apply after reset/start", function()
            assert(request("Role", "Gunship"), "next operator preference rejected")
            assert(otherRequest("Role", "Ground"), "next ground preference rejected")
            assert(
                player:GetAttribute("Role") == "Ground" and other():GetAttribute("Role") == "Gunship",
                "role preference changed an active role"
            )
            local generation = controls():GetAttribute("Generation")
            assert(request("Reset"), "reset rejected")
            waitFor(function()
                return controls():GetAttribute("Generation") ~= generation
                    and controls():GetAttribute("Busy") == false
            end)
            assert(
                ReplicatedStorage.RoundState:GetAttribute("Phase") == "Lobby",
                "reset did not return to lobby"
            )
            assert(request("Start"), "second start rejected")
            waitFor(function()
                return ReplicatedStorage.RoundState:GetAttribute("Phase") == "Active"
                    and player:GetAttribute("Role") == "Gunship"
            end)
            assert(
                other():GetAttribute("Role") == "Ground",
                "second tester did not receive chosen ground role"
            )
        end)
        return
    end
    test("Operator and Ground choices change solo preview without granting an active life", function()
        assert(request("Role", "Gunship"), "operator choice rejected")
        waitFor(function()
            return player:GetAttribute("LocalPreviewRole") == "Gunship" and root().Anchored
        end)
        assert(
            (root().Position - workspace.World.Battlefield.Anchors.Operator.Position).Magnitude < 1,
            "operator preview at wrong anchor"
        )
        assert(
            player:GetAttribute("Role") == "Waiting" and player:GetAttribute("Life") == "Waiting",
            "preview granted competitive authority"
        )
        assert(request("Role", "Ground"), "ground choice rejected")
        waitFor(function()
            return player:GetAttribute("LocalPreviewRole") == "Ground" and not root().Anchored
        end)
        assert(
            (root().Position - workspace.World.Battlefield.Anchors.Ground05.Position).Magnitude < 5,
            "ground preview at wrong anchor"
        )
    end)
    test("bounded duration choices apply to the next round and reject arbitrary values", function()
        assert(request("Duration", 180), "valid duration rejected")
        assert(not request("Duration", 777), "invalid duration accepted")
        assert(controls():GetAttribute("RoundSeconds") == 180, "duration not retained")
        assert(
            ReplicatedStorage.RoundState:GetAttribute("DeadlineSeconds") == 0,
            "setting a duration started a round"
        )
    end)
    test("solo start rejects without fabricating a roster and replay cannot change choices", function()
        assert(not request("Start"), "one player started a real round")
        assert(
            #Players:GetPlayers() == 1 and ReplicatedStorage.RoundState:GetAttribute("Phase") == "Lobby",
            "solo start fabricated players or a round"
        )
        assert(request("Role", "Ground"), "valid choice rejected")
        local payload = {
            action = "Role",
            value = "Gunship",
            sequence = sequence,
            generation = controls():GetAttribute("Generation"),
        }
        task.wait(0.4)
        assert(not session.request(player, payload), "replayed sequence accepted")
        assert(player:GetAttribute("LocalTestRoleChoice") == "Ground", "replay changed role")
    end)
    test("test panel can return to lobby and re-enter the chosen solo preview", function()
        assert(request("Lobby"), "return rejected")
        assert(
            not root().Anchored and player:GetAttribute("LocalMapPreview") == nil,
            "lobby stayed locked or marked preview"
        )
        assert(request("Explore"), "exploration rejected")
        assert(player:GetAttribute("LocalMapPreview") == true, "preview not restored")
    end)
    test("reset replaces the runtime and invalidates old-generation requests", function()
        local oldGeneration = controls():GetAttribute("Generation")
        local oldState = ReplicatedStorage.RoundState
        assert(request("Reset"), "reset rejected")
        waitFor(function()
            return controls():GetAttribute("Generation") ~= oldGeneration
                and controls():GetAttribute("Busy") == false
                and player:GetAttribute("LocalMapPreview") == true
        end)
        assert(
            ReplicatedStorage.RoundState ~= oldState and controls():GetAttribute("RoundSeconds") == 180,
            "reset lost settings or kept old runtime"
        )
        sequence += 1
        task.wait(0.4)
        assert(
            not session.request(
                player,
                { action = "Role", value = "Gunship", sequence = sequence, generation = oldGeneration }
            ),
            "old generation changed fresh runtime"
        )
    end)
end
