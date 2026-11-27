--!strict
-- P26 A1/A5. Schema boundaries apply to each actual panel input.
type API = typeof(require(game:GetService("ReplicatedStorage").Shared.BalanceSchema))
return function(test: (string, () -> ()) -> (), raw: unknown)
    local schema = raw :: API
    local function edit(key: string, value: unknown): { [string]: unknown }
        local copy = (table.clone(schema.defaults) :: unknown) :: { [string]: unknown }
        copy[key] = value
        return copy
    end
    test(
        "P26 every numeric control accepts inclusive endpoints and rejects overflow or malformed values",
        function()
            for _, field in schema.fields do
                if field.kind == "number" then
                    local low, high = field.minimum :: number, field.maximum :: number
                    for _, v in { low, high } do
                        assert(schema.validate(edit(field.key, v)), field.key)
                    end
                    local invalid: { unknown } = { low - 1, high + 1, 0 / 0, math.huge, "2", false }
                    for _, v in invalid do
                        assert(not schema.validate(edit(field.key, v)), field.key)
                    end
                    if field.integer then
                        assert(not schema.validate(edit(field.key, low + 0.5)), field.key)
                    end
                end
            end
        end
    )
    test("Legacy presets use one howitzer reload and single-use medkits", function()
        local values = edit("m102Reload", 0.5)
        values.m102Cadence = 60
        values.medkitSingleUse = false
        values.medkitRespawn = 600
        local decoded = assert(schema.validate(values))
        assert(decoded.m102Cadence == 0.5 and decoded.m102Reload == 0.5, "legacy timer overrides reload")
        assert(
            decoded.medkitSingleUse and decoded.medkitRespawn == schema.defaults.medkitRespawn,
            "legacy kit reuse survived"
        )
        assert(values.m102Cadence == 60 and values.medkitSingleUse == false, "mutated stored input")
    end)
    test("P26 durable preset and kit modes accept only known complete snapshots", function()
        for _, mode in { "Low", "Medium", "High" } do
            assert(schema.validate(edit("panelDamage", mode)))
        end
        for _, flag in { false, true } do
            assert(schema.validate(edit("medkitSingleUse", flag)))
        end
        for _, bad in
            {
                edit("panelDamage", "max"),
                edit("panelDamage", {}),
                edit("medkitSingleUse", 1),
                edit("secret", 2),
                edit("groundHealth", nil),
            }
        do
            assert(not schema.validate(bad), "incomplete or malformed preset accepted")
        end
        local input = edit("groundHealth", 123)
        local decoded = assert(schema.validate(input))
        input.groundHealth = 300
        assert(
            decoded.groundHealth == 123 and table.isfrozen(decoded),
            "decoded snapshot aliases mutable input"
        )
    end)
    test("Stored earlier ranges clamp while new edits reject out-of-range values", function()
        local stored = edit("m7Damage", 1000)
        stored.m7Cadence, stored.m7Reload, stored.rocketDamage = 5, 120, 10000
        stored.gauReload, stored.m102Reload, stored.intermission = 120, 120, 0
        assert(not schema.validate(stored), "new edit accepted old limits")
        local decoded = assert(schema.decodeStored(stored))
        assert(
            decoded.m7Damage == 50 and decoded.m7Cadence == 1 and decoded.m7Reload == 10,
            "rifle limits not migrated"
        )
        assert(
            decoded.rocketDamage == 5000 and decoded.gauReload == 30 and decoded.m102Reload == 30,
            "damage or reload migration"
        )
        assert(decoded.m102Cadence == 30 and decoded.intermission == 1, "clock migration")
        assert(stored.m7Damage == 1000 and table.isfrozen(decoded), "migration mutated input")
        stored.m7Damage = 1001
        assert(not schema.decodeStored(stored), "corrupt historical value accepted")
    end)
    test("Requested slider limits include zero aircraft reload and reject adjacent values", function()
        local bounds: { [string]: { number } } = {
            m7Damage = { 1, 50 },
            m7Cadence = { 0.15, 1 },
            m7Reload = { 0.15, 10 },
            rocketDamage = { 1, 5000 },
            intermission = { 1, 300 },
            gauReload = { 0, 30 },
            m102Reload = { 0, 30 },
        }
        for key, range in bounds do
            for _, value in range do
                assert(schema.validate(edit(key, value)), key)
            end
            assert(not schema.validate(edit(key, range[1] - 0.01)), key)
            assert(not schema.validate(edit(key, range[2] + 0.01)), key)
        end
    end)
    test("Default label keeps legacy preset identifiers compatible", function()
        assert(schema.presetLabel("Shipped") == "Default", "built-in label did not change")
        assert(schema.presetLabel("Production Settings") == "Production Settings", "custom name changed")
    end)
    test("Save remains disabled until the loaded name changes to a valid custom name", function()
        for _, pair in
            {
                { "Default", "Default" },
                { "Shipped", "Default" },
                { "", "Default" },
                { "Own preset", "Own preset" },
                { "", "" },
                { "bad!", "Default" },
            }
        do
            assert(not schema.canSavePresetName(pair[1], pair[2]), pair[1])
        end
        assert(schema.canSavePresetName("Own preset", "Default"), "renamed default cannot save")
        assert(schema.canSavePresetName("Copy", "Own preset"), "renamed custom cannot save")
        assert(schema.canSavePresetName("After deletion", ""), "blank editor cannot create a named copy")
        assert(not schema.canSavePresetName("Copy", "Copy"), "saved name should disable save again")
    end)
end
