--!strict
-- R13/P01 A2: deterministic injected time, exact refill boundaries, unchanged rejected state.
type Bucket = { capacity: number, refillPerSecond: number, tokens: number, updatedAtSeconds: number }
return function(
    test: (string, () -> ()) -> (),
    RateLimit: { new: (number, number, number) -> (Bucket?, string?), take: (Bucket, number) -> boolean }
)
    test("burst exhausts and exact refill boundary accepts", function()
        local bucket = assert(RateLimit.new(2, 2, 0), "expected RateLimit.new(2, 2, 0)")
        assert(RateLimit.take(bucket, 0), "expected RateLimit.take(bucket, 0)")
        assert(RateLimit.take(bucket, 0), "expected RateLimit.take(bucket, 0)")
        assert(not RateLimit.take(bucket, 0.499), "expected not RateLimit.take(bucket, 0.499)")
        assert(
            bucket.tokens == 0 and bucket.updatedAtSeconds == 0,
            "expected bucket.tokens == 0 and bucket.updatedAtSeconds == 0"
        )
        assert(RateLimit.take(bucket, 0.5), "expected RateLimit.take(bucket, 0.5)")
        assert(bucket.tokens == 0, "expected bucket.tokens == 0")
        assert(RateLimit.take(bucket, 100), "expected RateLimit.take(bucket, 100)")
        assert(bucket.tokens == 1, "expected bucket.tokens == 1")
    end)
    test("bad time rejects without mutation and valid requests still succeed", function()
        local bucket = assert(RateLimit.new(1, 1, 10), "expected RateLimit.new(1, 1, 10)")
        for _, bad in { 0 / 0, math.huge, -math.huge, 9 } do
            assert(not RateLimit.take(bucket, bad), "expected not RateLimit.take(bucket, bad)")
            assert(
                bucket.tokens == 1 and bucket.updatedAtSeconds == 10,
                "expected bucket.tokens == 1 and bucket.updatedAtSeconds == 10"
            )
        end
        assert(RateLimit.take(bucket, 10), "expected RateLimit.take(bucket, 10)")
    end)
    test("invalid bucket configuration rejects", function()
        for _, bad in { 0 / 0, math.huge, -1, 0, 1001 } do
            assert(not RateLimit.new(bad, 1, 0), "expected not RateLimit.new(bad, 1, 0)")
        end
        assert(not RateLimit.new(1, 0, 0), "expected not RateLimit.new(1, 0, 0)")
        assert(not RateLimit.new(1, 1, math.huge), "expected not RateLimit.new(1, 1, math.huge)")
    end)
end
