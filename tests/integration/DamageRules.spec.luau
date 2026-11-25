--!strict
-- P05 A1: per-shot player-health clamps, deduplication and invalid inputs.
type API = typeof(require(game:GetService("ServerScriptService").Server.DamageRules))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local damage = candidate :: API
    test("P05 damage clamps to remaining and maximum health", function()
        local shot = damage.new()
        assert(shot.award(1, 4, 100, 25) == 4, "lethal damage must not exceed remaining health")
        assert(shot.award(2, 150, 100, 200) == 100, "damage must not exceed max health")
        assert(shot.award(3, 100, 100, 25) == 25, "ordinary configured damage changed")
    end)
    test("P05 one shot awards each target once and a new shot has a fresh ledger", function()
        local first = damage.new()
        assert(first.award(-1, 100, 100, 25) == 25, "Studio signed user ID must work")
        assert(first.award(2, 100, 100, 25) == 25, "distinct target should be awarded")
        assert(first.award(-1, 75, 100, 25) == nil, "same target was awarded twice")
        assert(damage.new().award(-1, 75, 100, 25) == 25, "new shot retained an old target ledger")
    end)
    test("P05 invalid damage inputs reject without poisoning a later valid award", function()
        local shot = damage.new()
        for _, bad in { 0 / 0, math.huge, -math.huge, 0, -1 } do
            assert(shot.award(3, bad, 100, 25) == nil, "invalid health accepted")
            assert(shot.award(3, 100, bad, 25) == nil, "invalid max health accepted")
            assert(shot.award(3, 100, 100, bad) == nil, "invalid configured damage accepted")
        end
        assert(shot.award(0 / 0, 100, 100, 25) == nil, "invalid target accepted")
        assert(shot.award(3, 100, 100, 25) == 25, "rejected inputs consumed target award")
    end)
end
