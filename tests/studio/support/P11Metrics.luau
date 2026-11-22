--!strict
-- Test-only frame and retained-memory accounting shared by Studio probes and Lune.
-- It has no engine, clock or transport dependencies. Frame storage is a fixed-size
-- histogram at 0.1 ms resolution; one percentile report never contains raw frames.
local Metrics = {}
local maximumBin = 2500
local binsPerSecond = 10000

export type FrameSummary = {
    samples: number,
    invalid: number,
    overflow: number,
    p95Ms: number?,
}
export type FrameRecorder = { record: (number) -> (), summary: () -> FrameSummary }
export type MemorySummary = { growthPercent: number, monotonicGrowth: boolean }

local function positiveFinite(number: number): boolean
    return number > 0 and number < math.huge
end

-- Records positive finite seconds; nonpositive/nonfinite observations are counted
-- separately, above-range observations share a terminal bin. The nearest-rank p95
-- is rounded up to 0.1 ms. If it is over 250 ms, p95Ms is nil (a budget failure).
function Metrics.frames(): FrameRecorder
    local bins: { [number]: number } = {}
    local count, invalid, overflow = 0, 0, 0
    return {
        record = function(seconds)
            if not positiveFinite(seconds) then
                invalid += 1
                return
            end
            count += 1
            local bin = math.ceil(seconds * binsPerSecond)
            if bin > maximumBin then
                overflow += 1
            else
                bins[bin] = (bins[bin] or 0) + 1
            end
        end,
        summary = function()
            local remaining = math.ceil(count * 0.95)
            if remaining > 0 then
                for bin = 1, maximumBin do
                    remaining -= bins[bin] or 0
                    if remaining <= 0 then
                        return { samples = count, invalid = invalid, overflow = overflow, p95Ms = bin / 10 }
                    end
                end
            end
            return { samples = count, invalid = invalid, overflow = overflow }
        end,
    }
end

-- Takes 3–32 equivalent post-reset observations in chronological order (engine
-- reported MB). A strictly increasing sequence flags a monotonic growth pattern.
-- A final reduction is negative growth. Invalid inputs never produce evidence.
function Metrics.retainedMemory(samples: { number }): MemorySummary?
    if #samples < 3 or #samples > 32 then
        return nil
    end
    local increasing = true
    for index, current in samples do
        if not positiveFinite(current) then
            return nil
        end
        if index > 1 and current <= samples[index - 1] then
            increasing = false
        end
    end
    return {
        growthPercent = (samples[#samples] - samples[1]) * 100 / samples[1],
        monotonicGrowth = increasing,
    }
end

return Metrics
