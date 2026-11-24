--!strict
-- Test-only staged-fixture version contract. Pre-P18 balance/camera fixtures are
-- retained for historical evidence and reject before acquiring runtime resources.
-- Current coverage requires P18 with three clients, adapted P05 actual fire
-- with two clients, and ordinary native smoke. Independent P03/P04/map fixtures
-- remain available. Pure scalar API, no yielding.
local Compatibility = {}
local historical: { [string]: boolean } = table.freeze({
    P06 = true,
    P06Team = true,
    P07 = true,
    Sandbreak = true,
    P08 = true,
    P09 = true,
    P10 = true,
    P11 = true,
    P14 = true,
    P14ArrivalRegression = true,
    P17 = true,
})

-- Returns a descriptive incompatibility for a historical scenario, otherwise nil.
-- This is version rejection, never a passing/skipped gameplay result. Historical
-- scenarios must be run from their recorded source revision, not current balance.
function Compatibility.reason(kind: string): string?
    if not historical[kind] then
        return nil
    end
    return kind
        .. " is a historical pre-P18 staged fixture and cannot validate current balance. "
        .. "Use the P18 three-client scenario, adapted P05 two-client actual-fire scenario, and ordinary Studio smoke; reproduce old evidence from its recorded Git revision. "
        .. "P18 does not replace the separately pending live capacity/performance/release gates."
end

-- Rejects an incompatible direct/staged entry before allocating resources. Never
-- yields or mutates state. Callers report this error as unavailable validation.
function Compatibility.assertCurrent(kind: string)
    local reason = Compatibility.reason(kind)
    if reason then
        error(reason, 2)
    end
end
return Compatibility
