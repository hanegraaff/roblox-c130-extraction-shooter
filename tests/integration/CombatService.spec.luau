--!strict
-- P05 A1-A3: pure server readiness, exact fire shape and level envelope.
type API = typeof(require(game:GetService("ServerScriptService").Server.CombatService))
return function(test: (string, () -> ()) -> (), candidate: unknown)
    local combat = candidate :: API
    test("P19 howitzer radius includes 25 studs and preserves the light impact radius", function()
        local radius = combat.profiles.M102.radius
        assert(radius == 25 and combat.profiles.GAU23.radius == 4, "unexpected heavy or light radius")
        assert(
            combat.withinBlast(18.01, radius) and combat.withinBlast(24.999, radius),
            "blast rejected an exposed target inside 25 studs"
        )
        assert(
            combat.withinBlast(25, radius) and not combat.withinBlast(25.001, radius),
            "blast missed the inclusive radius boundary or reached past it"
        )
        assert(
            not combat.withinBlast(0 / 0, radius) and not combat.withinBlast(-1, radius),
            "invalid blast distance was admitted"
        )
    end)
    local defaults = {
        centerX = 0,
        centerZ = 0,
        groundY = 0,
        radiusStuds = 360,
        orbitCenterX = 0,
        orbitCenterZ = 0,
        orbitRadiusStuds = 360,
        focusX = 0,
        focusY = 0,
        focusZ = 0,
        altitudeStuds = 140,
        killY = -30,
    }
    local function fixture()
        local service = combat.new(defaults, -1, 32)
        service.reset(1)
        return service
    end
    local function request(sequence: number, weapon: string)
        return { roundId = 1, sequence = sequence, weapon = weapon, x = 0, y = 0, z = 0 }
    end
    test("P05 chain gun sustains nine seconds without forced reload", function()
        local owner = fixture()
        for i = 1, 61 do
            assert(owner.fire(1, request(i, "GAU23"), "GAU23", true, (i - 1) * 0.15, 360, 140, 0))
        end
        assert(assert(owner.readiness("GAU23", 9.1), "readiness").ammo == 39, "combat invariant")
    end)
    test(
        "P25 A1 howitzer reload survives selection, stale and duplicate fire and opens at exactly 12 seconds",
        function()
            local owner = fixture()
            assert(owner.fire(1, request(1, "M102"), "M102", true, 0, 360, 140, 0))
            assert(owner.fire(1, request(2, "GAU23"), "GAU23", true, 1, 360, 140, 0))
            local early = 11.999
            local replay = request(1, "M102")
            local stale = { roundId = 2, sequence = 100, weapon = "M102", x = 0, y = 0, z = 0 }
            assert(not owner.fire(1, replay, "M102", true, early, 360, 140, 0), "duplicate accepted")
            assert(not owner.fire(1, stale, "M102", true, early, 360, 140, 0), "stale round accepted")
            assert(not owner.fire(1, request(3, "M102"), "M102", true, early, 360, 140, 0), "early fire")
            local spent = assert(owner.readiness("M102", early), "spent howitzer readiness missing")
            assert(spent.ammo == 0 and spent.reloadUntil == 12, "rejected fire changed reload deadline")
            assert(not owner.fire(1, replay, "M102", true, 12, 360, 140, 0), "duplicate fired after reload")
            assert(not owner.fire(1, stale, "M102", true, 12, 360, 140, 0), "stale round fired after reload")
            assert(owner.fire(1, request(3, "M102"), "M102", true, 12, 360, 140, 0), "missed boundary")
            local spentAgain =
                assert(owner.readiness("M102", 23.999), "second spent howitzer readiness missing")
            assert(
                spentAgain.ammo == 0 and spentAgain.reloadUntil == 24,
                "second shot lost independent reload"
            )
            local chain = assert(owner.readiness("GAU23", 12), "chain-gun readiness missing")
            assert(chain.ammo == 99 and chain.reloadUntil == 0, "howitzer fire changed chain-gun readiness")
        end
    )
    test("P05 forged, stale, nonfinite and unauthorized fire reject without spending", function()
        local owner = fixture()
        local bad: { unknown } = {
            {},
            { roundId = 1, sequence = 1, weapon = "GAU23", x = 0, y = 0, z = 0, damage = 1000 },
            { roundId = 1, sequence = 1, weapon = "GAU23", x = 0 / 0, y = 0, z = 0 },
            { roundId = 1, sequence = 1, weapon = "GAU23", x = math.huge, y = 0, z = 0 },
            { roundId = 1, sequence = 1, weapon = "GAU23", x = 361, y = 0, z = 0 },
            { roundId = 1, sequence = 1, weapon = "GAU23", x = 0, y = 33, z = 0 },
            { roundId = 2, sequence = 1, weapon = "GAU23", x = 0, y = 0, z = 0 },
        }
        for _, payload in bad do
            assert(not owner.fire(1, payload, "GAU23", true, 0, 360, 140, 0), "combat invariant")
        end
        assert(not owner.fire(1, request(1, "GAU23"), "GAU23", false, 0, 360, 140, 0), "combat invariant")
        assert(assert(owner.readiness("GAU23", 0), "readiness").ammo == 100, "combat invariant")
        assert(owner.fire(1, request(1, "GAU23"), "GAU23", true, 0, 360, 140, 0))
        assert(not owner.fire(1, request(1, "GAU23"), "GAU23", true, 1, 360, 140, 0), "combat invariant")
        assert(assert(owner.readiness("GAU23", 1), "readiness").ammo == 99, "combat invariant")
    end)
    test("P05 chain gun cadence and magazine reload exact boundaries", function()
        local owner = fixture()
        assert(owner.fire(1, request(1, "GAU23"), "GAU23", true, 0, 360, 140, 0))
        assert(
            not owner.fire(1, request(2, "GAU23"), "GAU23", true, 0.149, 360, 140, 0),
            "early chain-gun cadence accepted"
        )
        assert(owner.fire(1, request(2, "GAU23"), "GAU23", true, 0.15, 360, 140, 0))
        for i = 3, 100 do
            assert(owner.fire(1, request(i, "GAU23"), "GAU23", true, (i - 1) * 0.151, 360, 140, 0))
        end
        local before = assert(owner.readiness("GAU23", 14.949), "readiness unavailable")
        assert(before.ammo == 0 and before.reloadUntil > 14.949, "empty magazine did not start reload")
        assert(
            not owner.fire(1, request(101, "GAU23"), "GAU23", true, before.reloadUntil - 0.001, 360, 140, 0),
            "reload completed early"
        )
        assert(owner.fire(1, request(101, "GAU23"), "GAU23", true, before.reloadUntil, 360, 140, 0))
        assert(
            assert(owner.readiness("GAU23", before.reloadUntil), "readiness unavailable").ammo == 99,
            "reload boundary did not replenish once"
        )
    end)
    test("P05 bounded range and weapon-specific readiness reject without sequence mutation", function()
        local owner = fixture()
        assert(
            not owner.fire(1, request(1, "GAU23"), "GAU23", true, 0, 1000, 140, 0),
            "out-of-range muzzle accepted"
        )
        assert(
            not owner.fire(1, request(1, "GAU23"), "M102", true, 0, 360, 140, 0),
            "unselected weapon fired"
        )
        local first = owner.fire(1, request(1, "GAU23"), "GAU23", true, 0, 360, 140, 0)
        assert(first and first.shotId == 1, "valid shot did not recover")
        owner.reset(2)
        local stale = request(2, "GAU23")
        assert(not owner.fire(1, stale, "GAU23", true, 1, 360, 140, 0), "old round fired after reset")
        local nextShot = owner.fire(
            1,
            { roundId = 2, sequence = 1, weapon = "GAU23", x = 0, y = 0, z = 0 },
            "GAU23",
            true,
            1,
            360,
            140,
            0
        )
        assert(
            nextShot and nextShot.shotId == 1 and nextShot.roundId == 2,
            "new round did not reset shot identity/readiness"
        )
    end)
    test("P05 each profile bounds swept distance and expires only after its exact lifetime", function()
        for _, profile in { combat.profiles.GAU23, combat.profiles.M102 } do
            local distance, expired = combat.flight(profile, profile.lifetime, 10, 10)
            assert(not expired and distance == 10, "lifetime equality or remaining-distance clamp changed")
            distance, expired = combat.flight(profile, profile.lifetime + 0.001, 10, 0.1)
            assert(expired and distance == 0, "projectile flew past its bounded lifetime")
            distance, expired = combat.flight(profile, 0.5, 100, 0.01)
            assert(
                not expired and math.abs(distance - profile.speed * 0.01) < 1e-9,
                "frame step did not use configured speed"
            )
            distance, expired = combat.flight(profile, 0.5, 100, -1)
            assert(not expired and distance == 0, "negative frame time advanced flight")
            distance, expired = combat.flight(profile, math.huge, 100, 0.1)
            assert(expired and distance == 0, "nonfinite elapsed time advanced flight")
        end
    end)
    test("P05 alternate level bounds replace industrial coordinates", function()
        local alternate = table.clone(defaults)
        alternate.centerX = 1000
        alternate.centerZ = -500
        alternate.orbitCenterX = 1000
        alternate.orbitCenterZ = -500
        alternate.focusX = 1000
        alternate.focusZ = -500
        local owner = combat.new(alternate, -1, 32)
        owner.reset(1)
        assert(not owner.fire(1, request(1, "GAU23"), "GAU23", true, 0, 1360, 140, -500), "combat invariant")
        assert(
            owner.fire(
                1,
                { roundId = 1, sequence = 1, weapon = "GAU23", x = 1000, y = 0, z = -500 },
                "GAU23",
                true,
                0,
                1360,
                140,
                -500
            )
        )
    end)
    test("P26 custom aircraft profiles keep separate server readiness", function()
        local profiles = table.clone(combat.profiles)
        local heavy, light = table.clone(profiles.M102), table.clone(profiles.GAU23)
        heavy.cadence, heavy.reload = 4, 3
        light.cadence, light.reload, light.capacity = 0.5, 1.25, 2
        profiles.M102, profiles.GAU23 = heavy, light
        local owner = combat.new(defaults, -1, 32, profiles)
        owner.reset(1)
        assert(owner.fire(1, request(1, "M102"), "M102", true, 0, 360, 140, 0), "first 105mm rejected")
        assert(owner.fire(1, request(2, "GAU23"), "GAU23", true, 0, 360, 140, 0), "first 30mm rejected")
        assert(
            not owner.fire(1, request(3, "GAU23"), "GAU23", true, 0.49, 360, 140, 0),
            "early 30mm shot accepted"
        )
        assert(owner.fire(1, request(3, "GAU23"), "GAU23", true, 0.5, 360, 140, 0), "30mm rejected on time")
        assert(
            assert(owner.readiness("GAU23", 1), "missing 30mm state").reloadUntil == 1.75,
            "incorrect empty-magazine deadline"
        )
        assert(
            not owner.fire(1, request(4, "M102"), "M102", true, 3, 360, 140, 0),
            "105mm ignored its longer cadence"
        )
        assert(
            owner.fire(1, request(4, "M102"), "M102", true, 4, 360, 140, 0),
            "105mm rejected at ready time"
        )
    end)
end
