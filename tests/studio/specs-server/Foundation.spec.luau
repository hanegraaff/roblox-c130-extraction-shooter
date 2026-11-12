--!strict
-- P01 A6/R01: TestEZ adapter discovers the actual mapped shared/unit/service modules.
return function()
    -- TestEZ installs its callback DSL into the spec environment at this boundary.
    local test = getfenv().it :: (string, () -> ()) -> ()
    local ServerStorage = game:GetService("ServerStorage")
    local Shared = game:GetService("ReplicatedStorage").Shared
    require(ServerStorage.Tests.Unit["Validation.spec"])(test, require(Shared.Validation))
    require(ServerStorage.Tests.Unit["Config.spec"])(test, require(Shared.Config))
    require(ServerStorage.Tests.Unit["RateLimit.spec"])(test, require(Shared.RateLimit))
    require(ServerStorage.Tests.Integration["Lifecycle.spec"])(test, require(Shared.Lifecycle))
    local Server = game:GetService("ServerScriptService").Server
    require(ServerStorage.Tests.Unit["RoleService.spec"])(test, require(Server.RoleService))
    require(ServerStorage.Tests.Unit["RoundRules.spec"])(test, require(Server.RoundRules))
    require(ServerStorage.Tests.Integration["MatchService.spec"])(test, require(Server.MatchService))
    require(ServerStorage.Tests.Unit["AircraftRules.spec"])(test, require(Shared.AircraftRules))
    require(ServerStorage.Tests.Unit["AircraftPanRules.spec"])(test, require(Shared.AircraftPanRules))
    require(ServerStorage.Tests.Integration["CombatService.spec"])(test, require(Server.CombatService))
    require(ServerStorage.Tests.Integration["DamageRules.spec"])(test, require(Server.DamageRules))
    require(ServerStorage.Tests.Integration["AircraftSelection.spec"])(
        test,
        require(Server.AircraftSelection)
    )
    test("server bootstrap stops and starts twice without duplicate resources", function()
        local status = game:GetService("ReplicatedStorage"):FindFirstChild("BootstrapStatus")
        assert(
            status and status:GetAttribute("Running") == true,
            'expected status and status:GetAttribute("Running") == true'
        )
        local Bootstrap = require(game:GetService("ServerScriptService").Server.Bootstrap)
        -- Use an independent status owner while preserving the actual entrypoint's status.
        status.Name = "EntrypointStatus"
        local runtime = Bootstrap.new("Test")
        for _ = 1, 2 do
            assert(runtime.start(), "expected runtime.start()")
            assert(runtime.start(), "expected runtime.start()")
            assert(
                game:GetService("ReplicatedStorage"):FindFirstChild("BootstrapStatus"),
                'expected game:GetService("ReplicatedStorage"):FindFirstChild("BootstrapStatus")'
            )
            runtime.stop()
            runtime.stop()
            assert(
                not game:GetService("ReplicatedStorage"):FindFirstChild("BootstrapStatus"),
                'expected not game:GetService("ReplicatedStorage"):FindFirstChild("BootstrapStatus")'
            )
        end
        status.Name = "BootstrapStatus"
    end)
    test("ground spawn is solid anchored and reachable", function()
        local spawn = workspace.World.Battlefield.GroundSpawn
        assert(
            spawn:IsA("SpawnLocation") and spawn.Anchored and spawn.CanCollide,
            'expected spawn:IsA("SpawnLocation") and spawn.Anchored and spawn.CanCollide'
        )
        assert(
            workspace:Raycast(spawn.Position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0)),
            "expected workspace:Raycast(spawn.Position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0))"
        )
    end)
end
