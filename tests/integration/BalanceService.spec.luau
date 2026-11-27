--!strict
-- P26 A1/A2/A5. Two independent servers share only the injected persistent record.
type API = typeof(require(game:GetService("ServerScriptService").Server.BalanceService))
type RecordAPI = typeof(require(game:GetService("ServerScriptService").Server.BalanceRecord))
local loadModule = (require :: unknown) :: (string) -> unknown
local Record = if script
    then require(game:GetService("ServerScriptService").Server.BalanceRecord)
    else loadModule("../../src/server/BalanceRecord") :: RecordAPI
return function(test: (string, () -> ()) -> (), raw: unknown)
    local api = raw :: API
    local function online(): boolean
        return true
    end
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
                restarted.round().settings.medkitHeal == 55 and not restarted.round().settings.medkitSingleUse,
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
end
