--!strict
-- P17ManualRunner: test-only local native Server & Clients invocation/storage adapter.
-- Uses the existing trusted ManualHarness selector and real Players only.
-- Never calls GetTestArgs/EndTest, never starts Studio, never changes core rules.
-- The source-bound harness disconnects observers and stops runtime before delivery.
-- Report chunks are server-only and remain until coordinator collection/Stop.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Metadata = require(script.Parent.P17Metadata)
local Runner = {}

local function cleanupObservation(): { [string]: boolean }
    return {
        transportAbsent = ReplicatedStorage:FindFirstChild("P17ManualHarness") == nil,
        roundStateAbsent = ReplicatedStorage:FindFirstChild("RoundState") == nil,
        aircraftStateAbsent = ReplicatedStorage:FindFirstChild("AircraftState") == nil,
        combatEffectsAbsent = workspace:FindFirstChild("CombatEffects") == nil,
        groundEffectsAbsent = workspace:FindFirstChild("GroundCombatEffects") == nil,
        fragmentFolderAbsent = workspace:FindFirstChild("PanelFragments") == nil,
    }
end

-- Source-owned trusted invocation; ordinary TestEZ must already have completed.
-- May yield for the same v6 game waits. No SDK session or arguments are consulted.
function Runner.run()
    assert(RunService:IsStudio(), "P17 manual probe is Studio-only")
    assert(game.PlaceId == 0 and game.GameId == 0, "P17 fixture requires a local test document")
    local settings = ServerStorage:FindFirstChild("DevelopmentSettings")
    assert(settings and settings:IsA("ModuleScript"), "test-only settings missing")
    assert(settings:GetAttribute("ManualHarness") == "P17", "explicit P17 selector missing")
    assert(
        not ServerStorage:FindFirstChild("P17ManualEvidence"),
        "manual evidence already owned; collect before rerun"
    )
    local harnessCommit = settings:GetAttribute("P17HarnessCommit")
    assert(
        type(harnessCommit) == "string" and #harnessCommit == 40 and harnessCommit:match("^[0-9a-f]+$"),
        "exact frozen harness commit must be supplied through server-only P17HarnessCommit"
    )
    local baseline = workspace:GetAttribute("ServerTestReport")
    assert(type(baseline) == "string", "ordinary server baseline missing")
    local ordinary = HttpService:JSONDecode(baseline)
    assert(
        ordinary.discovered == Metadata.expectedServerSmoke
            and ordinary.passed == ordinary.discovered
            and ordinary.failed == 0
            and ordinary.errors == 0
            and ordinary.skipped == 0,
        "ordinary server baseline failed or has unexpected count"
    )
    assert(
        #Players:GetPlayers() == 2 and ordinary.clientCount == 2,
        "fresh two-client server baseline and roster required"
    )
    -- Reject competing runtime/preview owners before creating evidence or status.
    for _, name in
        {
            "RoundState",
            "AircraftState",
            "LauncherState",
            "StudioTestControls",
            "P17ManualHarness",
            "P17PerformanceTransport",
        }
    do
        assert(not ReplicatedStorage:FindFirstChild(name), "active game/test owner: " .. name)
    end
    for _, name in { "Aircraft", "CombatEffects", "GroundCombatEffects", "PanelFragments" } do
        assert(not workspace:FindFirstChild(name), "active game/effect owner: " .. name)
    end
    for _, name in { "LocalTestControls", "P17UserPreviewStop" } do
        assert(not ServerStorage:FindFirstChild(name), "active test-preview owner: " .. name)
    end
    local invocation = {
        mode = "manual-native-server-clients",
        harness = "P17Manual-" .. Metadata.manualFixtureVersion,
        requestedInitialClients = 2,
        actualLateClientRequired = false,
        selector = "ServerStorage.DevelopmentSettings.ManualHarness",
        selectorValue = "P17",
        productionCommit = Metadata.productionCommit,
        productionFingerprintSha256 = Metadata.productionFingerprintSha256,
        harnessCommit = harnessCommit,
        harnessFingerprintSha256 = Metadata.harnessFingerprintSha256,
        serverProbeSha256 = Metadata.serverProbeSha256,
        clientProbeSha256 = Metadata.clientProbeSha256,
        manualFixtureVersion = Metadata.manualFixtureVersion,
        approvedAssetBindings = Metadata.approvedAssetBindings,
        serverTime = workspace:GetServerTimeNow(),
        automaticSessionEnd = false,
    }
    workspace:SetAttribute("P17ManualInvocation", HttpService:JSONEncode(invocation))
    local evidence = Instance.new("Folder")
    evidence.Name = "P17ManualEvidence"
    evidence:SetAttribute("Complete", false)
    evidence:SetAttribute("ChunkBytesLimit", 60000)
    evidence.Parent = ServerStorage
    local delivered = false
    local function store(result: unknown, wrapperFailure: string?)
        assert(not delivered, "manual result delivered twice")
        local encoded = HttpService:JSONEncode({
            invocation = invocation,
            preparedMetadata = Metadata,
            result = result,
            wrapperFailure = wrapperFailure,
            actualClientsAtDelivery = #Players:GetPlayers(),
            cleanupObservedAfterHarness = cleanupObservation(),
            serverBaselineAtDelivery = workspace:GetAttribute("ServerTestReport"),
        })
        assert(#encoded <= 16000000, "full manual report exceeds explicit16MB retention bound")
        local offset, chunks = 1, 0
        while offset <= #encoded do
            local last = math.min(#encoded, offset + 59999)
            -- Keep every chunk valid UTF-8 without changing any report bytes.
            while last < #encoded do
                local nextByte = string.byte(encoded, last + 1)
                if nextByte < 128 or nextByte >= 192 then
                    break
                end
                last -= 1
            end
            assert(last >= offset, "invalid report UTF-8 boundary")
            chunks += 1
            local chunk = Instance.new("StringValue")
            chunk.Name = string.format("Chunk%04d", chunks)
            chunk.Value = string.sub(encoded, offset, last)
            chunk.Parent = evidence
            offset = last + 1
        end
        local totals: { suite: string?, discovered: number?, passed: number?, failed: number?, skipped: number? } = if type(
                result
            ) == "table"
            then result :: {
                suite: string?,
                discovered: number?,
                passed: number?,
                failed: number?,
                skipped: number?,
            }
            else {}
        evidence:SetAttribute("TotalBytes", #encoded)
        evidence:SetAttribute("ChunkCount", chunks)
        evidence:SetAttribute("DeliveredAtServerSeconds", workspace:GetServerTimeNow())
        evidence:SetAttribute("Complete", true) -- publication marker, written last
        delivered = true
        workspace:SetAttribute(
            "P17ManualSummary",
            HttpService:JSONEncode({
                complete = true,
                storage = "ServerStorage.P17ManualEvidence",
                bytes = #encoded,
                chunks = chunks,
                suite = totals.suite,
                discovered = totals.discovered,
                passed = totals.passed,
                failed = totals.failed,
                skipped = totals.skipped,
                wrapperFailure = wrapperFailure,
                actualClients = #Players:GetPlayers(),
            })
        )
    end
    local ok, failure = pcall(function()
        require(script.Parent.P17MaterialHarness).run(function(report)
            store(report, nil)
        end)
    end)
    if not ok and not delivered then
        store({
            suite = "P17-manual-bootstrap",
            discovered = 0,
            passed = 0,
            failed = 1,
            skipped = 0,
            detail = tostring(failure),
        }, tostring(failure))
    end
    -- The native session intentionally stays open for report collection.
    -- Its coordinator then uses supported Stop/End Session and restores Edit.
end

return Runner
