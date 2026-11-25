--!strict
--[=[
    DamageRules: server-only deterministic per-shot target deduplication and bounded
    health damage. Depends on finite scalar inputs; no Instances, clocks or yielding.
    A fresh owner belongs to one authoritative shot and is discarded with it.
]=]
local DamageRules = {}
export type Controller = { award: (number, number, number, number) -> number? }

-- Creates a shot-local ledger. award takes a target UserId, current/max health and
-- configured damage in health units. It returns the clamped damage once per target;
-- malformed, eliminated or previously awarded targets return nil without mutation.
function DamageRules.new(): Controller
    local awarded: { [number]: boolean } = {}
    return {
        award = function(targetId, health, maximum, damage)
            if
                targetId ~= targetId
                or targetId == math.huge
                or targetId == -math.huge
                or targetId % 1 ~= 0
                or math.abs(targetId) > 9007199254740991
            then
                return nil
            end
            if
                health ~= health
                or maximum ~= maximum
                or damage ~= damage
                or math.abs(health) == math.huge
                or math.abs(maximum) == math.huge
                or math.abs(damage) == math.huge
                or maximum <= 0
                or health <= 0
                or damage <= 0
                or awarded[targetId]
            then
                return nil
            end
            local applied = math.min(math.min(health, maximum), damage)
            awarded[targetId] = true
            return applied
        end,
    }
end
return DamageRules
