--!strict
-- P10 A3: check the production neutral path with no eligible roster, in an
-- actual Client DataModel. The multiplayer suite separately follows avatars.
return function()
    local test = getfenv().it :: (string, () -> ()) -> ()
    test("P10 spectator with no living round teammates owns and releases an inert overview", function()
        local player = game:GetService("Players").LocalPlayer
        local module = require(player.PlayerScripts.Client.SpectatorCamera)
        local camera = assert(workspace.CurrentCamera, "client camera absent")
        local originalType, originalSubject = camera.CameraType, camera.CameraSubject
        local originalFrame, originalFocus = camera.CFrame, camera.Focus
        local owner = module.new(player)
        local ok, problem = pcall(function()
            -- A disposable round identity excludes every real participant and
            -- avoids relying on one short frame before the round reaches Results.
            local target, name, count = owner.update("Spectator", -1000, 1, nil, 0)
            assert(target == nil and name == nil and count == 0, "invalid spectator target acquired")
            local subject = camera.CameraSubject
            assert(camera.CameraType == Enum.CameraType.Scriptable, "neutral camera not scriptable")
            assert(subject and subject:IsA("BasePart"), "missing neutral camera subject")
            assert(subject.Name == "RoundOverviewSubject" and subject.Parent == camera, "wrong camera owner")
            assert(
                subject.Anchored and not subject.CanCollide and not subject.CanQuery and not subject.CanTouch,
                "neutral camera subject participates in world queries or physics"
            )
            owner.stop()
            owner.stop()
            assert(subject.Parent == nil, "neutral subject remained after stop")
            return true
        end)
        owner.stop()
        camera.CameraType, camera.CameraSubject = originalType, originalSubject
        camera.CFrame, camera.Focus = originalFrame, originalFocus
        assert(ok, tostring(problem))
    end)
end
