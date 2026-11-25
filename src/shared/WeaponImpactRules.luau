--!strict
-- WeaponImpactRules: public cosmetic contact types and bounded replay admission.
-- No clock or transport ownership. The server alone resolves real collisions.
local WeaponImpactRules = {}

export type Weapon = "M102" | "GAU23" | "Rocket"
export type Surface = "Ground" | "Solid" | "Metal"
export type Emit = (Weapon, number, string, Vector3, Vector3, string, number) -> ()
export type History = {
    admit: (Weapon, string, number, number) -> boolean,
    clear: () -> (),
}

local freshnessSeconds = 0.75
local historyLimit = 192

-- Coarse cosmetic classification; Terrain material does not change damage.
function WeaponImpactRules.surface(material: Enum.Material?, terrain: boolean, aircraft: boolean): Surface
    if
        aircraft
        or material == Enum.Material.Metal
        or material == Enum.Material.DiamondPlate
        or material == Enum.Material.CorrodedMetal
        or material == Enum.Material.Foil
    then
        return "Metal" :: Surface
    end
    if
        terrain
        or material == Enum.Material.Ground
        or material == Enum.Material.Sand
        or material == Enum.Material.Grass
        or material == Enum.Material.LeafyGrass
        or material == Enum.Material.Mud
        or material == Enum.Material.Asphalt
    then
        return "Ground" :: Surface
    end
    return "Solid" :: Surface
end

-- Creates one bounded per-round replay history. Times are synchronized server
-- seconds. Old and future deliveries reject. At capacity keep existing
-- identities for the rest of their valid window rather than allowing replay.
function WeaponImpactRules.history(): History
    local recent: { [string]: number } = {}
    return {
        admit = function(weapon, id, emittedAt, receivedAt)
            if
                not (math.abs(receivedAt) < math.huge and math.abs(emittedAt) < math.huge)
                or emittedAt > receivedAt + 0.25
                or emittedAt + freshnessSeconds < receivedAt
                or #id == 0
                or #id > 96
            then
                return false
            end
            local count = 0
            for key, expiry in recent do
                if expiry < receivedAt then
                    recent[key] = nil
                else
                    count += 1
                end
            end
            local key = weapon .. "/" .. id
            if recent[key] or count >= historyLimit then
                return false
            end
            recent[key] = emittedAt + freshnessSeconds
            return true
        end,
        clear = function()
            table.clear(recent)
        end,
    }
end

return WeaponImpactRules
