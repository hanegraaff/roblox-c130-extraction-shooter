--!strict
-- P17 preparation boundary only: canonical import metadata, never cloud access.
type API = typeof(require(game:GetService("ServerScriptService").Server.PanelAssetRules))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local Rules = candidate :: API
    local identity = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
    test(
        "P17AssetCatalog metadata accepts bounded rigid canonical geometry and exact hex receipts",
        function()
            assert(
                Rules.geometry({ 16, 8, 1.2 }, identity, { 8, 4, 0.9 }),
                "P17 assertion: Rules.geometry({ 16, 8, 1.2 }, identity, { 8, 4, 0.9 })"
            )
            assert(
                Rules.geometry({ 2, 4, 1 }, { 2, 0, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, { 8, 4, 0.9 }),
                "P17 assertion: Rules.geometry({ 2, 4, 1 }, { 2, 0, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1 }, { 8, 4, 0.9 })"
            )
            assert(Rules.receipt(string.rep("a0", 32)), 'P17 assertion: Rules.receipt(string.rep("a0", 32))')
        end
    )
    test(
        "P17AssetCatalog metadata rejects invalid bounds dimensions and transforms without mutation",
        function()
            for _, invalid in { 0, -1, math.huge, -math.huge, 0 / 0, 41 } do
                assert(
                    not Rules.geometry({ invalid, 8, 1 }, identity, { 8, 4, 0.9 }),
                    "P17 assertion: not Rules.geometry({ invalid, 8, 1 }, identity, { 8, 4, 0.9 })"
                )
            end
            for _, invalid in { math.huge, -math.huge, 0 / 0, 0.1 } do
                local pose = table.clone(identity)
                pose[4] = invalid
                assert(
                    not Rules.geometry({ 16, 8, 1 }, pose, { 8, 4, 0.9 }),
                    "P17 assertion: not Rules.geometry({ 16, 8, 1 }, pose, { 8, 4, 0.9 })"
                )
            end
            local reflected = table.clone(identity)
            reflected[4] = -1
            assert(
                not Rules.geometry({ 16, 8, 1 }, reflected, { 8, 4, 0.9 }),
                "P17 assertion: not Rules.geometry({ 16, 8, 1 }, reflected, { 8, 4, 0.9 })"
            )
            local shifted = table.clone(identity)
            shifted[1] = 0.01
            assert(
                not Rules.geometry({ 16, 8, 1 }, shifted, { 8, 4, 0.9 }),
                "P17 assertion: not Rules.geometry({ 16, 8, 1 }, shifted, { 8, 4, 0.9 })"
            )
            assert(identity[1] == 0 and identity[4] == 1, "validation mutated input")
            assert(
                not Rules.geometry({}, identity, { 8, 4, 0.9 }),
                "P17 assertion: not Rules.geometry({}, identity, { 8, 4, 0.9 })"
            )
            assert(
                not Rules.geometry({ 16, 8, 1 }, identity, { 0, 4, 0.9 }),
                "P17 assertion: not Rules.geometry({ 16, 8, 1 }, identity, { 0, 4, 0.9 })"
            )
        end
    )
    test("P17AssetCatalog receipt rejects nonhex wrong-length and nonscalar identities", function()
        local invalids: { unknown } =
            { string.rep("g", 64), string.rep("a", 63), string.rep("A", 64), "", 1, false, {} }
        for _, invalid in invalids do
            assert(not Rules.receipt(invalid), "P17 assertion: not Rules.receipt(invalid)")
        end
        assert(not Rules.receipt(nil), "P17 assertion: not Rules.receipt(nil)")
    end)
end
