--!strict
--[=[
    AssetMesh: shared, nonyielding check of compiled native mesh reconstruction.
    MeshId/Size alone cannot reconstruct MeshPart intrinsic size or collisions.
    The compiler preserves genuine engine-authored InitialSize/opaque payloads;
    this ordinary server/client adapter compares public MeshSize and fidelities
    with readable v1 metadata. Host/native authoring audits bind that metadata to
    actual payload bytes. No cloud fetch, protected reads, mutation or resources.
    A valid result does not prove rendered bounds, UVs or physics contacts.
]=]
local AssetMesh = {}

local function positiveFinite(value: number): boolean
    return value == value and value > 0 and value < math.huge
end

-- Reject missing/zero/mismatched native constructor data before installation.
-- Stud intrinsics describe the original asset, independently of target Size.
-- Allow Default fidelity only for callers retaining native, non-solid art.
function AssetMesh.validate(mesh: MeshPart, allowDefault: boolean?): (boolean, string?)
    local expected = mesh:GetAttribute("NativeMeshSize")
    local collision = mesh:GetAttribute("NativeCollisionFidelity")
    if
        mesh:GetAttribute("NativeGeometryVersion") ~= 1
        or mesh:GetAttribute("NativeMeshId") ~= mesh.MeshId
        or not string.match(mesh.MeshId, "^rbxassetid://[1-9]%d*$")
        or typeof(expected) ~= "Vector3"
        or not positiveFinite(expected.X)
        or not positiveFinite(expected.Y)
        or not positiveFinite(expected.Z)
        or (collision ~= "Box" and collision ~= "PreciseConvexDecomposition" and (not allowDefault or collision ~= "Default" or mesh.CanCollide or mesh.CanQuery))
        or mesh:GetAttribute("NativeRenderFidelity") ~= "Automatic"
    then
        return false, "missing/invalid compiled native mesh identity/intrinsics"
    end
    local actual = mesh.MeshSize
    if
        not positiveFinite(actual.X)
        or not positiveFinite(actual.Y)
        or not positiveFinite(actual.Z)
        or (actual - expected).Magnitude > 0.0001
        or collision ~= mesh.CollisionFidelity.Name
        or mesh.RenderFidelity ~= Enum.RenderFidelity.Automatic
    then
        return false, "native mesh intrinsic/fidelity reconstruction mismatch"
    end
    return true, nil
end

return AssetMesh
