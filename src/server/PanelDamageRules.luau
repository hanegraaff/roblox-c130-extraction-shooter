--!strict
--[=[
    PanelDamageRules: deterministic server-only structural stage arithmetic. No
    engine, network, clock access or yielding. All earned heavy/30mm credit
    persists until reset. Continuity anchors belong to DestructionService and
    cannot erase earned damage. Completed stages never regress. Durations are seconds; stage 0/1/2 means Intact/Damaged/Destroyed.
]=]
local PanelDamageRules = {}
export type DamageAppearance = "Pristine" | "Light" | "Heavy" | "Total"
export type State = { stage: number, heavySeconds: number, sustainedSeconds: number }
PanelDamageRules.stageSeconds = 9
PanelDamageRules.heavySeconds = 3
PanelDamageRules.epsilonSeconds = 1e-7

-- Returns independent pristine state. The caller owns the record; no shared state.
function PanelDamageRules.new(): State
    return { stage = 0, heavySeconds = 0, sustainedSeconds = 0 }
end

-- Fraction through the current stage, bounded to [0,1]. Destroyed returns 1.
function PanelDamageRules.progress(state: State): number
    return if state.stage == 2 then 1 else (state.heavySeconds + state.sustainedSeconds) / 9
end

-- Stable player-visible tier. Heavy never returns to the original appearance
-- when its new stage starts at zero local progress; any positive earned credit
-- gives Light, while the first zero-credit 30mm impact remains Pristine.
function PanelDamageRules.appearance(state: State): DamageAppearance
    if state.stage == 2 then
        return "Total"
    end
    if state.stage == 1 then
        return "Heavy"
    end
    return if state.heavySeconds + state.sustainedSeconds > 0 then "Light" else "Pristine"
end

-- Applies one direct heavy impact or nonnegative finite valid 30mm seconds.
-- Returns true only on a stage transition. Overflow is discarded at the boundary;
-- a single impact cannot advance two stages. Invalid inputs reject without writes.
function PanelDamageRules.apply(state: State, heavy: boolean, seconds: number): boolean
    if state.stage == 2 or seconds ~= seconds or seconds < 0 or seconds == math.huge then
        return false
    end
    if heavy then
        state.heavySeconds += PanelDamageRules.heavySeconds
    else
        state.sustainedSeconds += seconds
    end
    if state.heavySeconds + state.sustainedSeconds + PanelDamageRules.epsilonSeconds >= 9 then
        state.stage += 1
        state.heavySeconds = 0
        state.sustainedSeconds = 0
        return true
    end
    return false
end
return PanelDamageRules
