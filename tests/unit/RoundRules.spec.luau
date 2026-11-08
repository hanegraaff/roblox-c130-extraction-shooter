--!strict
-- P03 A2/R03: phase edges, exact deadline and pre-deadline outcome ordering.
type Facts = {
    nowSeconds: number,
    deadlineSeconds: number,
    aircraftDestroyed: boolean,
    groundAlive: number,
    operatorConnected: boolean,
    connectedCount: number,
}
type API = {
    canTransition: (string, string) -> boolean,
    outcome: (Facts) -> { winner: string, reason: string }?,
}
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Rules = candidate :: API
    test("only documented phase edges and deployment cancellation are legal", function()
        local legal = {
            ["Lobby>Deploying"] = true,
            ["Deploying>Active"] = true,
            ["Deploying>Lobby"] = true,
            ["Deploying>Results"] = true,
            ["Active>Results"] = true,
            ["Results>Resetting"] = true,
            ["Resetting>Lobby"] = true,
        }
        local phases: { "Lobby" | "Deploying" | "Active" | "Results" | "Resetting" } =
            { "Lobby", "Deploying", "Active", "Results", "Resetting" }
        for _, from in phases do
            for _, to in phases do
                assert(
                    Rules.canTransition(from, to) == (legal[from .. ">" .. to] == true),
                    'expected Rules.canTransition(from, to) == (legal[from .. ">" .. to] == true)'
                )
            end
        end
    end)
    test("deadline equality beats destruction and last ground elimination", function()
        local result = Rules.outcome({
            nowSeconds = 10,
            deadlineSeconds = 10,
            aircraftDestroyed = true,
            groundAlive = 0,
            operatorConnected = true,
            connectedCount = 2,
        })
        assert(
            result and result.winner == "Gunship" and result.reason == "Timeout",
            'expected result and result.winner == "Gunship" and result.reason == "Timeout"'
        )
    end)
    test("pre-deadline aircraft destruction beats mutual ground elimination", function()
        local result = Rules.outcome({
            nowSeconds = 9,
            deadlineSeconds = 10,
            aircraftDestroyed = true,
            groundAlive = 0,
            operatorConnected = true,
            connectedCount = 2,
        })
        assert(result and result.winner == "Ground", 'expected result and result.winner == "Ground"')
    end)
    test("empty server and no participants never award a competitive winner", function()
        for _, count in { 0, 1 } do
            local result = Rules.outcome({
                nowSeconds = 9,
                deadlineSeconds = 10,
                aircraftDestroyed = false,
                groundAlive = 0,
                operatorConnected = false,
                connectedCount = count,
            })
            assert(result and result.winner == "None", 'expected result and result.winner == "None"')
        end
    end)
end
