--!strict
-- Offline placement of existing Creator Store models. Lune reads the four pack files
-- (forest, city, pine and cactus, followed by the output RBXM path) without executing their code.
-- Only static geometry and surface materials enter the editable district assembly.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local cf, vec = roblox.CFrame, roblox.Vector3
local function loadPack(index)
    return roblox.deserializeModel(fs.readFile(process.args[index]))[1]
end
local forest, city, pine = loadPack(1), loadPack(2), loadPack(3)
local cacti = loadPack(4)
local root = roblox.Instance.new("Model")
root.Name = "DistrictScenery"
root:SetAttribute("ThermalBrightness", 0.63)
local function group(name)
    local folder = roblox.Instance.new("Folder")
    folder.Name, folder.Parent = name, root
    return folder
end
local desert, grove, depot = group("SandbreakWash"), group("VesperWoods"), group("DepotStreets")
local count = 0
-- Preserve each stock part's orientation, mesh, PBR and relative position. Place
-- the bottom of the source's oriented bounds on the ground; heights are in studs.
local function place(parent, source, x, z, height, yaw, solid, bury)
    assert(source, "missing stock model")
    local parts = {}
    local lo, hi = vec.new(1e6, 1e6, 1e6), vec.new(-1e6, -1e6, -1e6)
    for _, part in source:GetDescendants() do
        if part:IsA("BasePart") and part.Name ~= "Soil" and part.Transparency < 1 then
            table.insert(parts, part)
            for _, sx in { -0.5, 0.5 } do
                for _, sy in { -0.5, 0.5 } do
                    for _, sz in { -0.5, 0.5 } do
                        local pt = part.CFrame * (part.Size * vec.new(sx, sy, sz))
                        lo, hi = lo:Min(pt), hi:Max(pt)
                    end
                end
            end
        end
    end
    assert(#parts > 0, source.Name)
    count += 1
    local model = roblox.Instance.new("Model")
    local key = string.format("%s_%03d", source.Name, count)
    model.Name, model.Parent = key, parent
    local center = vec.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
    local scale = height / (hi.Y - lo.Y)
    local placement = cf.new(x, -(bury or 0), z) * cf.Angles(0, math.rad(yaw), 0)
    for i, original in parts do
        local part = original:Clone()
        for j, child in part:GetChildren() do
            if child:IsA("SurfaceAppearance") and #child:GetChildren() == 0 then
                child.Name = string.format("%s_%02d_Surface%d", key, i, j)
            else
                child:Destroy()
            end
        end
        local collide = solid or (source == pine and original:IsA("Part"))
        part.Name = string.format("%s_%02d", key, i)
        part.Size = original.Size * scale
        part.CFrame = placement
            * cf.new((original.CFrame.Position - center) * scale)
            * original.CFrame.Rotation
        part.Anchored, part.CanTouch, part.CanCollide, part.CanQuery = true, false, collide, collide
        if not collide then
            part:SetAttribute("ThermalNonCover", true)
        end
        part.Parent = model
    end
end
-- Published desert succulents occupy small washes between the rock outcrops.
for i, pos in
    {
        { -82, 101 },
        { -102, 114 },
        { -115, 138 },
        { -99, 164 },
        { -121, 34 },
        { -154, 62 },
        { -207, 41 },
        { -180, 120 },
        { -235, 85 },
        { -270, 116 },
        { -161, 155 },
        { -146, 204 },
        { -105, -201 },
        { -62, -223 },
        { -31, -256 },
        { -19, -217 },
        { -4, -182 },
        { 5, -138 },
        { -24, -81 },
        { -31, 35 },
        { -19, 69 },
        { 31, 75 },
        { 67, 61 },
        { -87, 74 },
        { -65, 141 },
    }
do
    local x, z = pos[1], pos[2]
    place(desert, cacti.Cactus, x, z, 6 + i % 5, i * 49, false, 0.25)
    if i % 3 ~= 0 then
        place(desert, cacti.Cactus_3, x + 3 + i % 4, z - 2 - i % 3, 2.8 + i % 3, i * 73, false, 0.2)
    end
end
local rockA, rockB = forest.LargeBoulder_Var01, forest.LargeBoulder_Var02
-- Eroded ridges built by overlapping existing boulders, with talus at the toe.
for i, cluster in
    {
        { -189, 93, 25, 24 },
        { -258, 79, 19, 110 },
        { -153, 177, 23, 62 },
        { -82, -219, 24, 102 },
        { 5, -265, 29, 15 },
        { -266, 137, 16, 112 },
        { -113, 54, 13, 35 },
        { -132, 112, 10, 38 },
        { 33, 23, 8, 10 },
    }
do
    local x, z, h, yaw = table.unpack(cluster)
    place(desert, rockB, x, z, h, yaw, true, 2)
    place(desert, rockA, x + 10, z + 4, h * 0.62, yaw + 66, true, 1.3)
    place(desert, rockA, x - 9, z - 3, h * 0.48, yaw - 25, true, 1.2)
    for j = 1, 5 do
        local angle = i * 1.5 + j * 2.15
        local dx, dz = math.cos(angle) * (16 + j * 1.7), math.sin(angle) * (15 + j)
        place(
            desert,
            forest.SmallRockGroupVar02,
            x + dx,
            z + dz,
            0.85 + j * 0.12,
            i * 33 + j * 43,
            false,
            0.1
        )
        if j % 2 == 1 then
            place(desert, forest.DyingFern01, x + dx + 3, z + dz - 2, 1.6 + j * 0.12, j * 64, false, 0.1)
        end
    end
end
-- Vary canopy height within groves, keeping all four radar portals and the
-- southwest approach open. Pines and redwoods retain the stock silhouettes.
-- Feather the tree line with stock thickets and young plants across the loamy
-- margin. Open clearings behind the radar keep its silhouette visible from the paths.
for i, c in
    {
        { 42, -67 },
        { 54, -99 },
        { 25, -110 },
        { 18, -142 },
        { 36, -225 },
        { 74, -246 },
        { 82, -267 },
        { 123, -273 },
        { 199, -240 },
        { 223, -216 },
        { 270, -159 },
        { 281, -79 },
        { 285, -34 },
        { 233, 2 },
        { 202, 14 },
        { 178, 28 },
        { 144, 18 },
        { 118, 4 },
        { 93, -10 },
        { 76, -25 },
        { 62, -46 },
    }
do
    place(grove, forest.MountainLaurelBush_Var01, c[1], c[2], 3 + i % 3, i * 57, false, 0.2)
    place(grove, forest.Fern_Var01, c[1] - 3, c[2] + 4, 1.7 + i % 2, i * 83, false, 0.1)
    if i % 3 == 0 then
        place(grove, pine, c[1] + 4, c[2] - 7, 13 + i % 5, i * 18, false, 0.1)
    end
end
local clusters =
    { { 77, -119 }, { 114, -193 }, { 204, -172 }, { 247, -99 }, { 240, -40 }, { 86, -48 }, { 165, -232 }, {
        278,
        -137,
    }, {
        46,
        -175,
    } }
for i, c in clusters do
    place(grove, pine, c[1], c[2], 25 + i % 4 * 3, i * 51, false, 0)
    for j = 1, 3 do
        local angle = i * 0.9 + j * 2.16
        local x, z = c[1] + math.cos(angle) * (12 + j * 4), c[2] + math.sin(angle) * (14 + j * 3)
        place(
            grove,
            forest["RedwoodTree-Var01"],
            x,
            z,
            26 + (i * 11 + j * 5) % 24,
            i * 59 + j * 33,
            false,
            0.45
        )
        place(grove, forest.MountainLaurelBush_Var01, x + 5, z + 7, 3 + (i + j) % 3, j * 63, false, 0.15)
        place(grove, forest.Fern_Var01, x - 6, z + 5, 2 + (i + j) % 2, i * 47, false, 0.15)
    end
    place(grove, forest.SmallRockGroupVar02, c[1] + 6, c[2] - 4, 1.2, i * 36, false, 0.12)
end
for i, pos in { { 91, 90 }, { 143, 104 }, { 197, 118 }, { 228, 163 }, { 240, 211 } } do
    place(depot, city.Telephone_Pole_01_A, pos[1], pos[2], 29, i < 4 and -18 or 74, true, 0)
end
for i, pos in { { 163, 160 }, { 202, 212 }, { 105, 119 } } do
    place(depot, city.StreetLightPole_01_A, pos[1], pos[2], 24, i * 110, false, 0.1)
end
place(depot, city.Garbage_Bin_01, 181, 156, 5, 93, true, 0)
place(depot, city.FireHydrant_01_A, 198, 146, 3.3, 27, false, 0)
place(depot, city.FireHydrant_01_B, 117, 127, 3.3, 102, false, 0)
for i, pos in { { 111, 118 }, { 114, 120 }, { 198, 181 }, { 199, 185 }, { 211, 209 }, { 215, 211 } } do
    place(depot, city.StreeBarrel_01_A, pos[1], pos[2], 3.6, i * 23, false, 0)
end
fs.writeFile(process.args[5], roblox.serializeModel({ root }))
print(string.format("%d stock placements, %d descendants", count, #root:GetDescendants()))
