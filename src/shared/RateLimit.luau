--!strict
--[=[
    RateLimit: deterministic shared token bucket for future server adapters.
    Caller injects monotonic seconds and owns one bucket per authority scope; no global clock or tasks.
    Rejections never mutate the bucket, including backward/nonfinite time. No yielding.
]=]
local Validation = if script then require(script.Parent.Validation) else require("./Validation")
local RateLimit = {}

-- Mutable server-owned state; capacity/refill are positive finite game configuration.
export type Bucket = { capacity: number, refillPerSecond: number, tokens: number, updatedAtSeconds: number }

-- Constructs a full bucket or rejects invalid configuration with an explicit reason.
function RateLimit.new(capacity: number, refillPerSecond: number, nowSeconds: number): (Bucket?, string?)
    if
        not Validation.inRange(capacity, 1, 1000)
        or not Validation.inRange(refillPerSecond, 0.001, 1000)
        or not Validation.isFinite(nowSeconds)
    then
        return nil, "invalid rate configuration"
    end
    return {
        capacity = capacity,
        refillPerSecond = refillPerSecond,
        tokens = capacity,
        updatedAtSeconds = nowSeconds,
    },
        nil
end

-- Consumes one token when available. Refill is computed only when a request is accepted.
function RateLimit.take(bucket: Bucket, nowSeconds: number): boolean
    if not Validation.isFinite(nowSeconds) or nowSeconds < bucket.updatedAtSeconds then
        return false
    end
    local tokens = math.min(
        bucket.capacity,
        bucket.tokens + (nowSeconds - bucket.updatedAtSeconds) * bucket.refillPerSecond
    )
    if tokens < 1 then
        return false
    end
    bucket.tokens = tokens - 1
    bucket.updatedAtSeconds = nowSeconds
    return true
end
return RateLimit
