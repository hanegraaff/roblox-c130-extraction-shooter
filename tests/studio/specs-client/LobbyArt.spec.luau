--!strict
-- P22 A2/A4, R24: exercise mounted native meshes in an ordinary Studio client.
-- Processed SurfaceAppearance textures are reviewed in the viewport. The host
-- gate verifies their actual serialized bindings.
local ContentProvider = game:GetService("ContentProvider")
local PRELOAD_ATTEMPTS = 3
local RETRY_PAUSE_SECONDS = 0.25

local function mountedArt(): Folder
    local world = assert(workspace:WaitForChild("World", 10), "missing game world")
    local battlefield = assert(world:WaitForChild("Battlefield", 10), "missing battlefield")
    local station = assert(battlefield:WaitForChild("LobbyStation", 10), "missing lobby station")
    local art = station:WaitForChild("LobbyArt", 10)
    assert(art and art:IsA("Folder"), "missing native lobby")
    return art
end

local function preloadMountedParts(parts: { MeshPart })
    local expected: { [MeshPart]: { [string]: string } } = {}
    for _, part in parts do
        local mesh = part.MeshId
        assert(mesh:match("^rbxassetid://%d+$"), "missing native lobby mesh " .. part.Name)
        local required = { [mesh] = "mesh" }
        if not part:FindFirstChildWhichIsA("SurfaceAppearance") then
            local color = part.TextureID
            assert(
                color ~= "" and color == part:GetAttribute("LobbyNativeColor"),
                "missing direct lobby texture " .. part.Name
            )
            required[color] = "texture"
        end
        expected[part] = required
    end

    -- A cold client's raw cache status can briefly disagree with a successful
    -- callback. Keep callback Success for each required asset across attempts
    -- and retry only mounted parts that still have an unconfirmed dependency.
    local observed: { [string]: Enum.AssetFetchStatus } = {}
    local pending = parts
    local missing: { string } = {}
    for attempt = 1, PRELOAD_ATTEMPTS do
        ContentProvider:PreloadAsync(pending, function(id: string, status: Enum.AssetFetchStatus)
            if observed[id] ~= Enum.AssetFetchStatus.Success then
                observed[id] = status
            end
        end)
        table.clear(missing)
        local retry: { MeshPart } = {}
        for _, part in pending do
            local needed = false
            for id, assetType in expected[part] do
                local status = observed[id]
                if status ~= Enum.AssetFetchStatus.Success then
                    local reason = if status then status.Name else "no callback"
                    table.insert(missing, string.format("%s %s %s (%s)", part.Name, assetType, id, reason))
                    needed = true
                end
            end
            if needed then
                table.insert(retry, part)
            end
        end
        if #retry == 0 then
            return
        end
        pending = retry
        if attempt < PRELOAD_ATTEMPTS then
            task.wait(RETRY_PAUSE_SECONDS)
        end
    end
    table.sort(missing)
    error(
        string.format(
            "Lobby preload failed after %d attempts: %s",
            PRELOAD_ATTEMPTS,
            table.concat(missing, ", ")
        )
    )
end

return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test(
        "P22 local client receives the furnished rooms and preloads the six native portrait meshes and television",
        function()
            local art = mountedArt()
            local count, bustCount = 0, 0
            local content: { MeshPart } = {}
            local distinctArt: { [string]: boolean } = {}
            for _, part in art:GetChildren() do
                assert(part:IsA("MeshPart"), "unexpected mounted lobby visual: " .. part.Name)
                assert(
                    part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,
                    part.Name
                )
                count += 1
                if part:GetAttribute("LobbyArtRole") == "Bust" then
                    bustCount += 1
                end
            end
            assert(count == 2432 and bustCount == 34, "mounted lobby or bust count changed")
            local television = art:FindFirstChild("P22_Room04_757_01")
            assert(television and television:IsA("MeshPart"), "native lobby television is missing")
            assert(television.TextureID == "rbxassetid://97488158099796", "television texture changed")
            table.insert(content, television)
            for portrait = 1, 6 do
                local part = art:FindFirstChild(string.format("P22_Portrait_%02d", portrait))
                assert(part and part:IsA("MeshPart"), "native portrait missing: " .. tostring(portrait))
                local source = part:GetAttribute("LobbyArtSource")
                assert(
                    source == string.format("Portrait %02d | canvas", portrait),
                    "portrait source mismatch"
                )
                assert(part:GetAttribute("LobbyArtRole") == "Portrait", "portrait role changed")
                assert(part:GetAttribute("LobbyPortrait") == portrait, "portrait index changed")
                local id = part:GetAttribute("LobbyNativeColor")
                assert(
                    type(id) == "string" and id:match("^rbxassetid://%d+$"),
                    "missing native portrait color"
                )
                assert(not distinctArt[id], "portrait color is a duplicate")
                distinctArt[id] = true
                table.insert(content, part)
            end
            preloadMountedParts(content)
        end
    )
end
