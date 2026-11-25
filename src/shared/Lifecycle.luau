--!strict
--[=[
    Lifecycle: pure explicit composition of nonyielding resource-owning component starts.
    Each start returns a nonthrowing cleanup callback. Starts and stops are idempotent;
    partial start failure rolls back in reverse order and returns the failure reason.
    Dependencies are injected; this module owns no engine resources itself.
]=]
local Lifecycle = {}
export type Cleanup = () -> ()
export type Component = () -> Cleanup
export type Controller = { start: () -> (boolean, string?), stop: () -> (), isRunning: () -> boolean }

-- Creates an independent controller. Components must not yield or reenter this controller.
function Lifecycle.new(components: { Component }): Controller
    local cleanups: { Cleanup } = {}
    local running = false
    local function stop()
        for index = #cleanups, 1, -1 do
            cleanups[index]()
        end
        table.clear(cleanups)
        running = false
    end
    local function start(): (boolean, string?)
        if running then
            return true, nil
        end
        for _, component in components do
            local ok, cleanup = pcall(component)
            if not ok then
                stop()
                return false, tostring(cleanup)
            end
            table.insert(cleanups, cleanup)
        end
        running = true
        return true, nil
    end
    return {
        start = start,
        stop = stop,
        isRunning = function()
            return running
        end,
    }
end
return Lifecycle
