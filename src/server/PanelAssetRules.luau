--!strict
--[=[
    PanelAssetRules: pure server-side bounds/identity validation for imported mesh
    metadata. Inputs are finite stud sizes, twelve CFrame components and canonical
    half-bounds. Does not yield, upload, mutate input or assert cloud availability.
]=]
local PanelAssetRules = {}

-- SHA-256 receipt identifiers must be exact lowercase hex, not just length64.
function PanelAssetRules.receipt(value: unknown): boolean
    return type(value) == "string" and #value == 64 and string.match(value, "^[0-9a-f]+$") ~= nil
end

-- A rigid, right-handed orientation and all eight transformed bounds corners
-- must fit the approved canonical envelope. Rejects malformed arrays/NaN/infinity,
-- zero/negative dimensions, translated/scaled/sheared/reflected import transforms.
function PanelAssetRules.geometry(size: { number }, pose: { number }, bounds: { number }): boolean
    if #size ~= 3 or #pose ~= 12 or #bounds ~= 3 then
        return false
    end
    for _, values in { size, pose, bounds } do
        for _, value in values do
            if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
                return false
            end
        end
    end
    for axis = 1, 3 do
        if size[axis] <= 0 or size[axis] > 40 or bounds[axis] <= 0 then
            return false
        end
    end
    local r = { pose[4], pose[7], pose[10] }
    local u = { pose[5], pose[8], pose[11] }
    local b = { pose[6], pose[9], pose[12] }
    local function dot(a: { number }, c: { number }): number
        return a[1] * c[1] + a[2] * c[2] + a[3] * c[3]
    end
    local cross = { r[2] * u[3] - r[3] * u[2], r[3] * u[1] - r[1] * u[3], r[1] * u[2] - r[2] * u[1] }
    if
        math.abs(dot(r, r) - 1) > 1e-4
        or math.abs(dot(u, u) - 1) > 1e-4
        or math.abs(dot(b, b) - 1) > 1e-4
        or math.abs(dot(r, u)) > 1e-4
        or math.abs(dot(r, b)) > 1e-4
        or math.abs(dot(u, b)) > 1e-4
        or math.abs(dot(cross, b) - 1) > 1e-4
    then
        return false
    end
    for axis = 1, 3 do
        local extent = math.abs(r[axis]) * size[1] / 2
            + math.abs(u[axis]) * size[2] / 2
            + math.abs(b[axis]) * size[3] / 2
        if math.abs(pose[axis]) + extent > bounds[axis] + 0.001 then
            return false
        end
    end
    return true
end

return PanelAssetRules
