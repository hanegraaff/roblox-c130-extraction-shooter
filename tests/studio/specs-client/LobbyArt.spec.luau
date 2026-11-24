--!strict
-- P22 A2/A4, R24: exercise mounted native meshes in an ordinary Studio client.
-- Processed SurfaceAppearance textures are reviewed in the viewport. The host
-- gate verifies their actual serialized bindings.
local ContentProvider = game:GetService("ContentProvider")

local function mountedArt(): Folder
    local world = assert(workspace:WaitForChild("World", 10), "missing game world")
    local battlefield = assert(world:WaitForChild("Battlefield", 10), "missing battlefield")
    local station = assert(battlefield:WaitForChild("LobbyStation", 10), "missing lobby station")
    local art = station:WaitForChild("LobbyArt", 10)
    assert(art and art:IsA("Folder"), "missing native lobby")
    return art
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
            ContentProvider:PreloadAsync(content)
            for _, part in content do
                assert(
                    ContentProvider:GetAssetFetchStatus(part.MeshId) == Enum.AssetFetchStatus.Success,
                    "failed to load lobby mesh " .. part.Name
                )
                local directColor = part.TextureID
                if directColor ~= "" and directColor == part:GetAttribute("LobbyNativeColor") then
                    assert(
                        ContentProvider:GetAssetFetchStatus(directColor) == Enum.AssetFetchStatus.Success,
                        "failed to load direct lobby texture " .. part.Name
                    )
                end
            end
        end
    )
end
