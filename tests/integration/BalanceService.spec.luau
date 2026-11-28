--!strict
-- P26 A1/A2/A5. Two independent servers share only the injected persistent record.
type API = typeof(require(game:GetService("ServerScriptService").Server.BalanceService))
type RecordAPI = typeof(require(game:GetService("ServerScriptService").Server.BalanceRecord))
local loadModule = (require :: unknown) :: (string) -> unknown
local Record = if script
    then require(game:GetService("ServerScriptService").Server.BalanceRecord)
    else loadModule("../../src/server/BalanceRecord") :: RecordAPI
local AircraftHealth = (
    if script
        then require(game:GetService("ServerScriptService").Server.AircraftHealth)
        else loadModule("../../src/server/AircraftHealth")
) :: typeof(require(game:GetService("ServerScriptService").Server.AircraftHealth))
return function(test: (string, () -> ()) -> (), raw: unknown)
    local api = raw :: API
    local function online(): boolean
        return true
    end
    test("Updated Production Settings persist under the same name and apply on deployment", function()
        local stored: unknown = nil
        local storage = {
            read = function(): unknown
                return stored
            end,
            update = function(change: (unknown) -> unknown): unknown
                local updated = change(stored)
                if updated ~= nil then
                    stored = updated
                end
                return updated
            end,
        }
        local server = api.new(storage)
        local name = "Production Settings"
        local values = table.clone(server.latest().settings)
        local function write(service: typeof(server), action: string, revision: number, settings: unknown?)
            return service.write(
                assert(
                    Record.request({ action = action, revision = revision, name = name, settings = settings })
                ),
                1,
                1,
                online
            )
        end

        assert(write(server, "save", 0, values))
        assert(write(server, "apply", 1))
        local edited = table.clone(server.latest().presets[name])
        edited.rocketDamage = 175
        edited.aircraftHealthPerGround = 900
        edited.m7Damage = 7
        assert(write(server, "save", 2, edited))

        local restarted = api.new(storage)
        assert(restarted.refresh())
        assert(restarted.latest().presets[name].rocketDamage == 175, "same-name save was lost")
        assert(
            restarted.latest().activeName == name and restarted.latest().settings.rocketDamage == 150,
            "save changed the live snapshot"
        )
        restarted.capture()
        assert(write(restarted, "apply", 3))
        assert(restarted.round().settings.rocketDamage == 150, "apply changed the captured round")
        restarted.capture()
        assert(restarted.round().settings.rocketDamage == 175, "deployment missed the applied values")

        local deployed = restarted.round().settings
        local aircraft =
            AircraftHealth.new(deployed.aircraftHealthPerGround, deployed.m7Damage, deployed.rocketDamage)
        assert(aircraft.reset(1, 2), "aircraft did not initialize for two Ground players")
        assert(aircraft.snapshot().maximum == 1800, "aircraft did not use the saved health multiplier")
        assert(aircraft.impact(1, "rocket", "RocketLauncher", true) == 175, "rocket used the wrong damage")
        assert(aircraft.impact(1, "rifle", "M7", true) == 7, "rifle used the wrong damage")
        assert(aircraft.snapshot().health == 1618, "aircraft did not retain both hits")

        local anotherServer = api.new(storage)
        assert(
            anotherServer.refresh() and anotherServer.latest().settings.rocketDamage == 175,
            "fresh server missed applied values"
        )
    end)
    test("Save and apply atomically overwrites the live preset for the next round", function()
        local stored: unknown = nil
        local storage = {
            read = function(): unknown
                return stored
            end,
            update = function(change: (unknown) -> unknown): unknown
                local replacement = change(stored)
                if replacement ~= nil then
                    stored = replacement
                end
                return replacement
            end,
        }
        local server = api.new(storage)
        local function request(revision: number, health: number)
            local values = table.clone(server.latest().settings)
            values.groundHealth = health
            return {
                action = "saveAndApply",
                revision = revision,
                name = "Production Settings",
                settings = values,
            }
        end
        local first = assert(Record.request(request(0, 123)))
        assert(not server.write(first, 2, 1, online), "ordinary player could apply a draft")
        assert(server.write(first, 1, 1, online))
        server.capture()
        assert(Record.request(request(1, 0)) == nil, "invalid draft was accepted")
        local edited = assert(Record.request(request(1, 193)))
        assert(server.write(edited, 1, 1, online))
        assert(not server.write(edited, 1, 1, online), "stale draft was accepted twice")
        local live = server.latest()
        assert(live.revision == 2 and live.activeRevision == 2, "edit must commit once")
        assert(live.presets["Production Settings"].groundHealth == 193, "edit did not save")
        assert(live.settings.groundHealth == 193, "edit did not apply")
        assert(server.round().settings.groundHealth == 123, "edit changed existing round")
        server.capture()
        assert(server.round().settings.groundHealth == 193, "next round missed edit")

        local restarted = api.new(storage)
        assert(
            restarted.refresh() and restarted.latest().settings.groundHealth == 193,
            "restart lost applied edit"
        )
        local restore = assert(Record.request({ action = "restore", revision = 2 }))
        assert(restarted.write(restore, 1, 1, online))
        assert(restarted.latest().settings.groundHealth == 123, "prior live snapshot was lost")
    end)
    test(
        "P26 two servers recover missed notifications, keep the round snapshot, restore and survive restart",
        function()
            local stored: unknown = nil
            local deps = {
                read = function(): unknown
                    return stored
                end,
                update = function(transform: (unknown) -> unknown): unknown
                    local nextValue = transform(stored)
                    if nextValue ~= nil then
                        stored = nextValue
                    end
                    return nextValue
                end,
            }
            local a, b = api.new(deps), api.new(deps)
            local grant = assert(Record.request({ action = "grant", revision = 0, userId = 2 }))
            assert(a.write(grant, 1, 1, online))
            assert(b.refresh())
            local values = table.clone(b.latest().settings)
            values.minimumPlayers = 4
            values.medkitHeal = 55
            values.medkitSingleUse = false
            values.intermission = 30
            local save =
                assert(Record.request({ action = "save", revision = 1, name = "Trial", settings = values }))
            assert(b.write(save, 2, 1, online))
            assert(not a.write(save, 1, 1, online), "stale save overwrote a newer edit")
            assert(
                b.write(
                    assert(Record.request({ action = "apply", revision = 2, name = "Trial" })),
                    2,
                    1,
                    online
                )
            )
            assert(b.round().settings.minimumPlayers == 2, "applying a preset changed the current match")
            assert(
                a.latest().revision == 1 and a.refresh() and a.latest().activeRevision == 3,
                "refresh missed authoritative revision"
            )
            a.capture()
            assert(a.round().settings.minimumPlayers == 4, "deployment missed new minimum")
            local restarted = api.new(deps)
            assert(restarted.refresh())
            restarted.capture()
            assert(
                restarted.round().settings.medkitHeal == 55 and restarted.round().settings.medkitSingleUse,
                "restart lost medkit settings"
            )
            assert(a.write(assert(Record.request({ action = "restore", revision = 3 })), 1, 1, online))
            assert(
                a.latest().activeRevision == 4 and a.latest().settings.minimumPlayers == 2,
                "rollback failed to advance and restore"
            )
            assert(a.round().settings.minimumPlayers == 4, "rollback changed an existing round")
            assert(b.refresh())
            b.capture()
            assert(
                b.round().activeRevision == 4 and b.round().settings.minimumPlayers == 2,
                "other server missed rollback"
            )
            local revoke = assert(Record.request({ action = "revoke", revision = 4, userId = 2 }))
            assert(a.write(revoke, 1, 1, online))
            local staleClient = assert(Record.request({ action = "apply", revision = 5, name = "Trial" }))
            assert(not b.write(staleClient, 2, 1, online), "revoked tester wrote from stale cache")
            assert(
                b.refresh() and b.latest().revision == 5 and #b.latest().trusted == 0,
                "revocation failed to converge"
            )
        end
    )
    test(
        "P26 read and write failures preserve confirmed settings, stop and disconnect cancel writes",
        function()
            local calls = 0
            local service = api.new({
                read = function(): unknown
                    error("read outage")
                end,
                update = function(_transform: (unknown) -> unknown): unknown
                    calls += 1
                    error("write outage")
                end,
            })
            local req = assert(Record.request({ action = "apply", revision = 0, name = "Shipped" }))
            assert(
                not service.refresh() and service.status() == "Storage unavailable",
                "outage was reported as success"
            )
            assert(not service.write(req, 2, 1, online) and calls == 0, "untrusted actor reached storage")
            assert(not service.write(req, 1, 1, function()
                return false
            end) and calls == 0, "disconnected actor reached storage")
            assert(not service.write(req, 1, 1, online) and calls == 1, "failed save was accepted")
            assert(
                service.latest().revision == 0 and service.round().settings.aircraftHealthPerGround == 1000,
                "outage replaced last good values"
            )
            service.stop()
            assert(
                not service.refresh() and not service.write(req, 1, 1, online) and calls == 1,
                "stopped service reached storage"
            )
        end
    )
    test(
        "Deleted preset remains deleted across another server and restart without changing the round",
        function()
            local stored: unknown = nil
            local deps = {
                read = function(): unknown
                    return stored
                end,
                update = function(change: (unknown) -> unknown): unknown
                    local nextValue = change(stored)
                    if nextValue ~= nil then
                        stored = nextValue
                    end
                    return nextValue
                end,
            }
            local a, b = api.new(deps), api.new(deps)
            local function write(service: typeof(a), action: string, revision: number, name: string)
                local payload: { [string]: unknown } = { action = action, revision = revision, name = name }
                if action == "save" then
                    payload.settings = service.latest().settings
                end
                return service.write(assert(Record.request(payload)), 1, 1, online)
            end
            assert(write(a, "save", 0, "Trial"), "save failed")
            assert(write(a, "apply", 1, "Trial"), "apply failed")
            assert(b.refresh(), "second server refresh")
            b.capture()
            assert(write(a, "delete", 2, "Trial"), "delete failed")
            assert(not write(b, "apply", 2, "Trial"), "stale apply after deletion")
            assert(b.refresh() and b.latest().presets.Trial == nil, "second server retained deleted preset")
            assert(b.round().activeName == "Trial", "delete changed running round")
            local restarted = api.new(deps)
            assert(
                restarted.refresh() and restarted.latest().presets.Trial == nil,
                "restart revived deleted preset"
            )
        end
    )
end
