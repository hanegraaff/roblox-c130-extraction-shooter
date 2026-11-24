--!strict
-- Studio Edit only. Assemble the captured native lobby and apply the approved
-- upright oil painting textures and the separately approved theater screen.
-- The caller owns the unparented result and exports it with SerializationService.

type ImageBinding = {
    assetId: string,
    sha256: string,
}

type Canvas = {
    number: number,
    inwardNormal: Vector3?,
}

local oilCanvases: { [string]: Canvas } = {
    P22_Portrait_02 = { number = 2, inwardNormal = -Vector3.zAxis },
    P22_Portrait_03 = { number = 3 },
    P22_Portrait_04 = { number = 4, inwardNormal = -Vector3.xAxis },
    P22_Portrait_06 = { number = 6, inwardNormal = -Vector3.zAxis },
}
local screenSource = "CRT | phosphor glass and aerial image"

-- MeshPart.TextureID uses the exact approved image. The source SurfaceAppearance
-- carries the former texture and would take precedence over that binding.
local function setImage(part: MeshPart, image: ImageBinding)
    assert(image.assetId:match("^%d+$") and #image.sha256 == 64 and image.sha256:match("^[a-f0-9]+$"))
    local surface = part:FindFirstChildWhichIsA("SurfaceAppearance")
    if surface then
        surface:Destroy()
    end
    part.TextureID = "rbxassetid://" .. image.assetId
    part.Color = Color3.new(1, 1, 1)
    part:SetAttribute("LobbyNativeColor", part.TextureID)
    part:SetAttribute("LobbyColorSourceSha256", image.sha256)
end

-- Preserve the old native mesh's UVs, center, and occupied plane. In the three
-- legacy canvases whose UVs rotated the photographic raster, turn the native
-- part around its inward normal and swap the local display extents. This gives
-- the same upright corners as the new canonical Blender UVs without recooking
-- or uploading mesh data.
local function orientUpright(part: MeshPart, inwardNormal: Vector3)
    local pose = part.CFrame
    local size = part.Size
    part.Size = if size.X > size.Z
        then Vector3.new(size.Y, size.X, size.Z)
        else Vector3.new(size.X, size.Z, size.Y)
    part.CFrame = CFrame.new(pose.Position) * CFrame.fromAxisAngle(inwardNormal, math.pi / 2) * pose.Rotation
end

local function sortByName(instances: { Instance })
    table.sort(instances, function(a, b)
        return a.Name < b.Name
    end)
end

-- Return a single native visual Folder and scene inventory. The input contains
-- the 14 calibrated batch folders and remains available for retesting.
return function(staging: Folder, paintings: { [number]: ImageBinding }, screen: ImageBinding)
    local lobby = Instance.new("Folder")
    lobby.Name = "LobbyArt"
    local succeeded, report = pcall(function()
        local parts = {}
        local names: { [string]: boolean } = {}
        local roles: { [string]: number } = {}
        local painted: { [string]: string } = {}
        local screens = 0
        local batches = staging:GetChildren()
        sortByName(batches)
        assert(#batches == 14, "Expected all fourteen captured lobby batches")
        for _, batch in batches do
            assert(batch:IsA("Folder"), "Unexpected lobby capture item")
            local captured = batch:GetChildren()
            sortByName(captured)
            for _, source in captured do
                assert(
                    source:IsA("MeshPart") and not names[source.Name],
                    "Invalid or duplicate native lobby part"
                )
                names[source.Name] = true
                local mesh = source:Clone()
                mesh.Parent = lobby
                local role = mesh:GetAttribute("LobbyArtRole")
                assert(type(role) == "string")
                roles[role] = (roles[role] or 0) + 1
                local canvas = oilCanvases[mesh.Name]
                if canvas then
                    local image = assert(paintings[canvas.number], "Missing approved oil portrait")
                    assert(mesh:GetAttribute("LobbyPortrait") == canvas.number and role == "Portrait")
                    setImage(mesh, image)
                    if canvas.inwardNormal then
                        orientUpright(mesh, canvas.inwardNormal)
                    end
                    painted[mesh.Name] = mesh.TextureID
                elseif mesh:GetAttribute("LobbyArtSource") == screenSource then
                    setImage(mesh, screen)
                    screens += 1
                end
                if role == "Portrait" or mesh:GetAttribute("LobbyArtSource") == screenSource then
                    parts[mesh.Name] = {
                        mesh = mesh.MeshId,
                        color = mesh:GetAttribute("LobbyNativeColor"),
                        colorSourceSha256 = mesh:GetAttribute("LobbyColorSourceSha256"),
                        cframe = { mesh.CFrame:GetComponents() },
                        size = { mesh.Size.X, mesh.Size.Y, mesh.Size.Z },
                        intrinsic = { mesh.MeshSize.X, mesh.MeshSize.Y, mesh.MeshSize.Z },
                    }
                end
            end
            task.wait()
        end
        assert(roles.Bust == 34 and roles.Portrait == 6 and roles.Room == 2392)
        assert(screens == 1 and #lobby:GetChildren() == 2432)
        for name in oilCanvases do
            assert(painted[name], "Missing approved canvas " .. name)
        end
        return { roles = roles, screens = screens, notableParts = parts, oilTextures = painted }
    end)
    if not succeeded then
        lobby:Destroy()
        error(report)
    end
    return lobby, report
end
