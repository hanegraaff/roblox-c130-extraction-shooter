--!strict
-- Regression engine specs run explicitly after the actual test runtime starts.
-- Requires one real client; asserts actual spawning, containment and preview cleanup.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local controls = game:GetService("ServerStorage"):WaitForChild("LocalTestControls", 10)
    local status = ReplicatedStorage:WaitForChild("RoundState", 10)
    assert(controls and status, "test runtime controls unavailable")
    local players = Players:GetPlayers()
    local function invoke(name: string): (boolean, string?)
        local control = controls:FindFirstChild(name)
        assert(control and control:IsA("BindableFunction"), "missing server-only shortcut")
        return control:Invoke()
    end
    local function rootFor(player: Player): BasePart
        local deadline = os.clock() + 15
        while os.clock() < deadline do
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if root and root:IsA("BasePart") and not player:GetAttribute("RoundCharacterLoad") then
                return root
            end
            task.wait()
        end
        error("character readiness timed out")
    end
    test("waiting characters walk while retaining station protection", function()
        for _, player in players do
            local root = rootFor(player)
            assert(not root.Anchored, "lobby root is anchored")
            assert(
                player.Character and player.Character:FindFirstChild("StationProtection"),
                "lobby protection missing"
            )
        end
    end)
    assert(#players == 1, "solo shortcut regression requires one real client")
    local player = players[1]
    test("one test client automatically enters solo map preview", function()
        local deadline = os.clock() + 5
        while player:GetAttribute("LocalMapPreview") ~= true and os.clock() < deadline do
            task.wait()
        end
        assert(player:GetAttribute("LocalMapPreview") == true, "solo Play remained stuck in the lobby")
        assert(
            (rootFor(player).Position - workspace.World.Battlefield.Anchors.Ground05.Position).Magnitude < 5,
            "automatic preview did not reach shelter"
        )
    end)
    test("solo preview moves to the map without changing role life or phase", function()
        assert(invoke("ExploreMap"), "solo preview rejected")
        local root = rootFor(player)
        assert(
            (root.Position - workspace.World.Battlefield.Anchors.Ground05.Position).Magnitude < 1,
            "preview did not reach shelter"
        )
        assert(
            status:GetAttribute("Phase") == "Lobby"
                and player:GetAttribute("Role") == "Waiting"
                and player:GetAttribute("Life") == "Waiting",
            "preview granted an active life"
        )
        assert(
            player:GetAttribute("LocalMapPreview") == true and not root.Anchored,
            "preview state or walking unavailable"
        )
    end)
    test("solo preview contains exterior positions and returns to the lobby", function()
        local root = rootFor(player)
        root.CFrame = CFrame.new(500, 10, 500)
        task.wait(0.2)
        assert(
            (root.Position - workspace.World.Battlefield.Anchors.Ground05.Position).Magnitude < 5,
            "preview boundary did not recover"
        )
        assert(invoke("ReturnToLobby"), "preview return rejected")
        assert(
            (root.Position - workspace.World.Battlefield.Anchors.Lobby.Position).Magnitude < 1,
            "return did not reach lobby"
        )
        assert(player:GetAttribute("LocalMapPreview") == nil, "preview marker survived return")
        assert(not invoke("ReturnToLobby"), "duplicate return unexpectedly accepted")
    end)
end
