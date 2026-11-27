--!strict
-- P26 A1. Tests the exact decoder and transaction transform sent to UpdateAsync.
type API = typeof(require(game:GetService("ServerScriptService").Server.BalanceRecord))
return function(test: (string, () -> ()) -> (), raw: unknown)
    local rules = raw :: API
    test("P26 admin requests reject unknown fields, actors, malformed collections and names", function()
        local invalid: { unknown } = {
            { action = "read", userId = 1 },
            { action = "save", name = "x", revision = 0, settings = {} },
            { action = "grant", revision = 0, userId = 0 },
            { action = "grant", revision = 0, userId = math.huge },
            { action = "grant", revision = 0, userId = 3, owner = true },
            { action = "revoke", revision = 0.25, userId = 3 },
            { action = "apply", revision = 0, name = string.rep("a", 33) },
            { action = "restore", revision = -1 },
        }
        for _, request in invalid do
            assert(not rules.request(request), "invalid command was accepted")
        end
        local initial = rules.initial()
        assert(not rules.decode({ version = 2 }), "unknown storage schema accepted")
        assert(rules.decode(nil))
        local broken = table.clone(initial)
        broken.trusted = { [2] = 8 }
        assert(not rules.decode(broken), "sparse trust list accepted")
        broken.trusted = { 8, 8 }
        assert(not rules.decode(broken), "duplicate tester accepted")
    end)
    test("P26 permissions and compare-and-swap reject stale or revoked testers without mutation", function()
        local base = rules.initial()
        local grant = assert(rules.request({ action = "grant", revision = 0, userId = 2 }))
        assert(not rules.apply(base, grant, 2, 1), "tester granted their own access")
        local granted = assert(rules.apply(base, grant, 1, 1))
        assert(
            granted.revision == 1 and #base.trusted == 0 and rules.allowed(granted, 2, 1),
            "grant changed its source or lost its revision"
        )
        assert(not rules.apply(granted, grant, 1, 1), "stale owner command accepted")
        local revoke = assert(rules.request({ action = "revoke", revision = 1, userId = 2 }))
        assert(not rules.apply(granted, revoke, 2, 1), "tester revoked access")
        local revoked = assert(rules.apply(granted, revoke, 1, 1))
        local apply = assert(rules.request({ action = "apply", revision = 2, name = "Shipped" }))
        assert(
            not rules.apply(revoked, apply, 2, 1) and revoked.revision == 2,
            "revoked actor wrote settings"
        )
        assert(not rules.allowed(revoked, 1, 3), "former owner retained access")
    end)
    test(
        "Preset deletion preserves live rules and rejects stale, unauthorized and built-in deletion",
        function()
            local base = rules.initial()
            local save = assert(
                rules.request({ action = "save", revision = 0, name = "Trial", settings = base.settings })
            )
            local saved = assert(rules.apply(base, save, 1, 1))
            local live = assert(
                rules.apply(
                    saved,
                    assert(rules.request({ action = "apply", revision = 1, name = "Trial" })),
                    1,
                    1
                )
            )
            local request = assert(rules.request({ action = "delete", revision = 2, name = "Trial" }))
            assert(not rules.apply(live, request, 2, 1), "ordinary player deleted a preset")
            local deleted = assert(rules.apply(live, request, 1, 1))
            assert(
                deleted.presets.Trial == nil and live.presets.Trial ~= nil,
                "delete mutated prior snapshot"
            )
            assert(
                deleted.revision == 3
                    and deleted.activeRevision == live.activeRevision
                    and deleted.settings == live.settings,
                "delete changed live rules"
            )
            assert(rules.decode(deleted), "deleted active name broke stored state")
            assert(not rules.apply(deleted, request, 1, 1), "stale deletion replay accepted")
            assert(
                not rules.apply(
                    deleted,
                    assert(rules.request({ action = "delete", revision = 3, name = "Shipped" })),
                    1,
                    1
                ),
                "built-in deleted"
            )
            assert(
                not rules.apply(
                    deleted,
                    assert(rules.request({ action = "delete", revision = 3, name = "Missing" })),
                    1,
                    1
                ),
                "missing preset deleted"
            )
            assert(
                not rules.request({ action = "delete", revision = 3, name = "Trial", settings = {} }),
                "delete accepted extra payload"
            )
        end
    )
    test("Default is read only and legacy stored presets retain their active selection", function()
        local initial = rules.initial()
        for _, name in { "Shipped", "Default" } do
            local request = assert(
                rules.request({ action = "save", revision = 0, name = name, settings = initial.settings })
            )
            assert(not rules.apply(initial, request, 1, 1), "built-in name overwritten")
        end
        local stored = table.clone(initial)
        stored.presets = table.clone(initial.presets)
        stored.presets.Production = initial.settings
        stored.activeName = "Production"
        local decoded = assert(rules.decode(stored))
        assert(decoded.activeName == "Production" and decoded.presets.Shipped ~= nil, "legacy selection lost")
    end)
end
