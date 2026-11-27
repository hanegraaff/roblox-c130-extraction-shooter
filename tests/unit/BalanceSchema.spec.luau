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
end
