--!strict
--[=[
    BuildingLayout: pure validation for authored two-story panel buildings. No engine
    dependencies/yielding. Dimensions are studs; pivots are twelve finite CFrame components.
    Static stairs/floors stay separate from panel states. P07 owns damage and variant swaps.
]=]
local BuildingLayout = {}
export type Panel = { id: string, story: number, roof: boolean, pivot: { number } }
export type Building = {
    id: string,
    width: number,
    depth: number,
    stories: number,
    stairSteps: number,
    stepRise: number,
    stepRun: number,
    panels: { Panel },
}

-- Validates exact population, dimensions, stairs and registry without mutation. Expected
-- rejection returns false/reason. IDs are global and stable across rebuilds; roof panels
-- belong to the top story. Variants share their Intact pivot instead of moving supports.
function BuildingLayout.validate(buildings: { Building }): (boolean, string?)
    if #buildings ~= 3 then
        return false, "requires exactly three buildings"
    end
    local large, small = 0, 0
    local ids: { [string]: boolean } = {}
    for _, building in buildings do
        if ids[building.id] or building.id == "" then
            return false, "duplicate/empty building ID"
        end
        ids[building.id] = true
        if building.width == 64 and building.depth == 48 then
            large += 1
        elseif building.width == 32 and building.depth == 48 then
            small += 1
        else
            return false, "unexpected footprint"
        end
        if
            building.stories ~= 2
            or building.stairSteps ~= 16
            or building.stepRise ~= 0.625
            or building.stepRun ~= 2
        then
            return false, "invalid two-story stair contract"
        end
        local stories: { [number]: number } = { [1] = 0, [2] = 0 }
        local roof = 0
        for _, panel in building.panels do
            if ids[panel.id] or panel.id == "" then
                return false, "duplicate/empty panel ID"
            end
            ids[panel.id] = true
            if panel.story ~= 1 and panel.story ~= 2 then
                return false, "invalid panel story"
            end
            if #panel.pivot ~= 12 then
                return false, "invalid panel pivot"
            end
            for _, value in panel.pivot do
                if value ~= value or math.abs(value) == math.huge then
                    return false, "nonfinite panel pivot"
                end
            end
            if panel.roof then
                if panel.story ~= 2 then
                    return false, "roof must belong to top story"
                end
                roof += 1
            else
                stories[panel.story] += 1
            end
        end
        local wallCount = 2 * (building.width / 16 + building.depth / 16)
        if
            stories[1] ~= wallCount - 1
            or stories[2] ~= wallCount
            or roof ~= (building.width / 16) * (building.depth / 16)
        then
            return false, "each story needs exterior panels and a panelized roof"
        end
    end
    if large ~= 2 or small ~= 1 then
        return false, "requires two large and one smaller footprint"
    end
    return true, nil
end
return BuildingLayout
