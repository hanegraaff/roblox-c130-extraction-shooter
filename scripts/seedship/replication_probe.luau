--!strict
-- Temporary StudioTestService companion scripts use this shared probe to count
-- physical hits for a representative wall and roof from both real clients.
return function(panels: Instance, witness)
    local rays = RaycastParams.new()
    rays.FilterType = Enum.RaycastFilterType.Include
    rays.RespectCanCollide = true
    local volumes = {}
    for _, sample in witness do
        local panel = assert(panels:FindFirstChild(sample.name), sample.name)
        rays.FilterDescendantsInstances = { panel }
        local hitCount = 0
        for i = -7, 7 do
            for j = -7, 7 do
                local offset = Vector3.xAxis * sample.half.X * i / 8
                    + (
                            if sample.roof
                                then Vector3.zAxis * sample.half.Z
                                else Vector3.yAxis * sample.half.Y
                        )
                        * j
                        / 8
                local line = (if sample.roof then Vector3.yAxis else Vector3.zAxis) * 28
                if workspace:Raycast(sample.center + offset + line, -line * 2, rays) then
                    hitCount += 1
                end
            end
        end
        volumes[sample.name] = {
            hits = hitCount,
            appearance = panel:GetAttribute("DamageAppearance"),
        }
    end
    return volumes
end
