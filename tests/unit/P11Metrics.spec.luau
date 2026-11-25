--!strict
-- P11 A2/A3: bounded histograms and equivalent reset-point memory arithmetic.
type API = typeof(require(game:GetService("ReplicatedStorage").P11Metrics))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local metrics = candidate :: API
    test("P11 reports no p95 for empty or invalid frame samples", function()
        local frames = metrics.frames()
        assert(frames.summary().p95Ms == nil, "empty samples produced a percentile")
        for _, invalid in { 0, -1, 0 / 0, math.huge } do
            frames.record(invalid)
        end
        local summary = frames.summary()
        assert(
            summary.samples == 0 and summary.invalid == 4 and summary.p95Ms == nil,
            "invalid frame classification"
        )
    end)
    test("P11 nearest-rank frame percentile rounds upward without storing raw frames", function()
        local frames = metrics.frames()
        for _ = 1, 19 do
            frames.record(0.03321)
        end
        frames.record(1)
        local summary = frames.summary()
        assert(
            summary.samples == 20 and summary.overflow == 1 and summary.p95Ms == 33.3,
            "percentile or overflow accounting"
        )
        frames.record(1)
        assert(frames.summary().p95Ms == nil, "overflow p95 must fail the budget")
    end)
    test("P11 memory growth uses equivalent endpoints and flags strictly increasing samples", function()
        local growing = assert(metrics.retainedMemory({ 100, 101, 110 }))
        assert(
            growing.growthPercent == 10 and growing.monotonicGrowth,
            "monotonic increase or endpoint growth"
        )
        local recovered = assert(metrics.retainedMemory({ 100, 104, 95 }))
        assert(
            recovered.growthPercent == -5 and not recovered.monotonicGrowth,
            "recovered allocation misclassified"
        )
        assert(not metrics.retainedMemory({ 100, 110 }), "too few samples accepted")
        assert(not metrics.retainedMemory({ 100, 0 / 0, 110 }), "invalid memory sample accepted")
        assert(not metrics.retainedMemory(table.create(33, 100)), "too many samples accepted")
    end)
end
