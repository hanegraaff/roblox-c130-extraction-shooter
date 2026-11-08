--!strict
-- P01 A6/R01: actual PlayerGui, replication and repeated StatusPanel lifecycle checks.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("client receives server status and an explicit character or late-spectator state", function()
        local player = game:GetService("Players").LocalPlayer
        local status = game:GetService("ReplicatedStorage"):WaitForChild("BootstrapStatus", 10)
        assert(
            status and status:GetAttribute("Environment") == "Test" and status:GetAttribute("Running"),
            'expected status and status:GetAttribute("Environment") == "Test" and status:GetAttribute("Running")'
        )
        local deadline = os.clock() + 10
        while not player.Character and player:GetAttribute("Role") ~= "Spectator" and os.clock() < deadline do
            task.wait()
        end
        local character = player.Character
        if player:GetAttribute("Role") == "Spectator" then
            local roundState = game:GetService("ReplicatedStorage"):FindFirstChild("RoundState")
            assert(
                roundState and roundState:GetAttribute("Phase") ~= "Lobby",
                "spectator without active round"
            )
            assert(not character, "late spectator gained a character")
            return
        end
        assert(character, "character unavailable after 10 seconds")
        assert(
            character:WaitForChild("HumanoidRootPart", 10),
            'expected character:WaitForChild("HumanoidRootPart", 10)'
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
