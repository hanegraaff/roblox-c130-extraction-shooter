--!strict
-- P01 A6/R01: actual PlayerGui, replication and repeated StatusPanel lifecycle checks.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("client receives server status and an explicit character or late-spectator state", function()
        local player = game:GetService("Players").LocalPlayer
        local replicated = game:GetService("ReplicatedStorage")
        local started = os.clock()
        -- Server fixtures deliberately own map/bootstrap before the gameplay runtime.
        -- Waiting for a body during those fixtures races deferred character startup.
        -- Budgets are separate: 60s fixture completion, 35s runtime/client rendezvous,
        -- then the same 25s avatar/deployment budget used by the Studio harnesses.
        local function diagnostic(stage: string): string
            local state = replicated:FindFirstChild("RoundState")
            local character = player.Character
            return game:GetService("HttpService"):JSONEncode({
                stage = stage,
                elapsedSeconds = os.clock() - started,
                serverBaselineComplete = type(workspace:GetAttribute("ServerTestReport")) == "string",
                roundState = state ~= nil,
                phase = if state then tostring(state:GetAttribute("Phase")) else "absent",
                role = tostring(player:GetAttribute("Role")),
                life = tostring(player:GetAttribute("Life")),
                loadLease = tostring(player:GetAttribute("RoundCharacterLoad")),
                hasCharacter = character ~= nil,
                hasRoot = character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil,
            })
        end
        local function awaitReady(stage: string, seconds: number, predicate: () -> boolean)
            local deadline = os.clock() + seconds
            while not predicate() and os.clock() < deadline do
                task.wait()
            end
            assert(predicate(), "client startup timeout: " .. diagnostic(stage))
        end
        awaitReady("server fixtures", 60, function()
            return type(workspace:GetAttribute("ServerTestReport")) == "string"
        end)
        local report = workspace:GetAttribute("ServerTestReport")
        assert(type(report) == "string", "server fixture report missing")
        local totals = game:GetService("HttpService"):JSONDecode(report)
        assert(
            totals.discovered > 0
                and totals.passed == totals.discovered
                and totals.failed == 0
                and totals.skipped == 0
                and totals.errors == 0,
            "server fixtures failed: " .. report
        )
        local status = replicated:FindFirstChild("BootstrapStatus")
        assert(
            status and status:GetAttribute("Environment") == "Test" and status:GetAttribute("Running"),
            "test bootstrap not running after fixtures: " .. diagnostic("bootstrap")
        )
        awaitReady("deferred round runtime", 35, function()
            local state = replicated:FindFirstChild("RoundState")
            return state ~= nil
                and type(state:GetAttribute("Phase")) == "string"
                and type(player:GetAttribute("Role")) == "string"
        end)
        local avatarStarted = os.clock()
        awaitReady("actual avatar or late spectator", 25, function()
            local state = replicated:FindFirstChild("RoundState")
            if not state then
                return false
            end
            local character = player.Character
            if player:GetAttribute("Role") == "Spectator" then
                return state:GetAttribute("Phase") ~= "Lobby"
                    and player:GetAttribute("Life") == "Spectating"
                    and character == nil
                    and player:GetAttribute("RoundCharacterLoad") == nil
            end
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            return root ~= nil
                and root:IsA("BasePart")
                and character ~= nil
                and character:FindFirstChildOfClass("Humanoid") ~= nil
                and player:GetAttribute("RoundCharacterLoad") == nil
        end)
        local character = player.Character
        if player:GetAttribute("Role") == "Spectator" then
            local state = replicated:FindFirstChild("RoundState")
            assert(state and state:GetAttribute("Phase") ~= "Lobby", "spectator without active round")
            assert(player:GetAttribute("Life") == "Spectating", "late spectator life not explicit")
            assert(not character, "late spectator gained a character")
        else
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            assert(
                character and root and root:IsA("BasePart"),
                "ready character/root disappeared: " .. diagnostic("avatar")
            )
        end
        -- Persist real readiness timing for slow network/avatar diagnosis.
        player.PlayerScripts.ClientTests:SetAttribute(
            "StartupReadiness",
            game:GetService("HttpService"):JSONEncode({
                elapsedSeconds = os.clock() - started,
                avatarSeconds = os.clock() - avatarStarted,
                state = diagnostic("ready"),
            })
        )
    end)
    test("panel renders environment and restarts twice with one GUI", function()
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10) :: PlayerGui
        local status = game:GetService("ReplicatedStorage"):WaitForChild("BootstrapStatus", 10)
        assert(status, "expected status")
        local existing = playerGui:WaitForChild("FoundationStatus", 10)
        assert(existing, "expected existing")
        existing.Name = "EntrypointPanel"
        local StatusPanel = require(game:GetService("Players").LocalPlayer.PlayerScripts.Client.StatusPanel)
        local runtime = StatusPanel.new(playerGui, status)
        for _ = 1, 2 do
            assert(runtime.start(), "expected runtime.start()")
            assert(runtime.start(), "expected runtime.start()")
            local gui = playerGui:FindFirstChild("FoundationStatus")
            assert(gui and gui:IsA("ScreenGui"), 'expected gui and gui:IsA("ScreenGui")')
            local label = gui:FindFirstChild("Status")
            assert(
                label and label:IsA("TextLabel") and string.find(label.Text, "Test", 1, true),
                'expected label and label:IsA("TextLabel") and string.find(label.Text, "Test", 1, true)'
            )
            runtime.stop()
            runtime.stop()
            assert(
                not playerGui:FindFirstChild("FoundationStatus"),
                'expected not playerGui:FindFirstChild("FoundationStatus")'
            )
        end
        existing.Name = "FoundationStatus"
    end)
end
