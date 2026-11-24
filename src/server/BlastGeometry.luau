--!strict
-- Server-only spatial query for building splash. Combat supplies the live
-- registry and pre-impact cover filter. Reads world-stud geometry synchronously.
local CombatService = require(script.Parent.CombatService)
local BlastGeometry = {}
local endpointPadding = 0.03

-- Tests the closest point of each actual live collider, including rotated
-- geometry and residual pieces. A broadphase only limits the work; the exact
-- distance and first solid along the ray decide acceptance. Returns unique IDs.
function BlastGeometry.exposedPanels(
    contact: Vector3,
    origin: Vector3,
    radiusStuds: number,
    battlefield: Instance,
    cover: RaycastParams,
    identify: (Instance?) -> string?,
    directPanelId: string?
): { string }
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances = { battlefield }
    overlap.RespectCanCollide = true
    local ids: { string } = {}
    local seen: { [string]: boolean } = {}
    for _, part in workspace:GetPartBoundsInRadius(contact, radiusStuds + endpointPadding, overlap) do
        local id = identify(part)
        if id and id ~= directPanelId and id ~= "HerculesWreck" and not seen[id] then
            local closest = part:GetClosestPointOnSurface(contact)
            if CombatService.withinBlast((closest - contact).Magnitude, radiusStuds) then
                local delta = closest - origin
                local distance = delta.Magnitude
                local blocking = if distance > 0
                    then workspace:Raycast(origin, delta.Unit * (distance + endpointPadding), cover)
                    else nil
                if not blocking or blocking.Instance == part then
                    seen[id] = true
                    table.insert(ids, id)
                end
            end
        end
    end
    table.sort(ids)
    return ids
end

return BlastGeometry
