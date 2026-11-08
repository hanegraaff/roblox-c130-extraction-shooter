--!strict
-- R01/R15/P01 A2: real lifecycle composition with controlled listener/task adapters.
return function(
    test: (string, () -> ()) -> (),
    Lifecycle: {
        new: (
            { () -> () -> () }
        ) -> { start: () -> (boolean, string?), stop: () -> (), isRunning: () -> boolean },
    }
)
    test("two start stop cycles own one listener and task and clean both", function()
        local listeners, tasks = 0, 0
        local runtime = Lifecycle.new({
            function()
                listeners += 1
                tasks += 1
                return function()
                    listeners -= 1
                    tasks -= 1
                end
            end,
        })
        for _ = 1, 2 do
            assert(runtime.start(), "expected runtime.start()")
            assert(runtime.start(), "expected runtime.start()")
            assert(runtime.isRunning(), "expected runtime.isRunning()")
            assert(listeners == 1 and tasks == 1, "expected listeners == 1 and tasks == 1")
            runtime.stop()
            runtime.stop()
            assert(
                not runtime.isRunning() and listeners == 0 and tasks == 0,
                "expected not runtime.isRunning() and listeners == 0 and tasks == 0"
            )
        end
    end)
    test("partial initialization rolls back in reverse order and can retry", function()
        local live = 0
        local fail = true
        local runtime = Lifecycle.new({
            function()
                live += 1
                return function()
                    live -= 1
                end
            end,
            function()
                if fail then
                    error("injected start failure")
                end
                return function() end
            end,
        })
        local ok, reason = runtime.start()
        assert(
            not ok and reason and live == 0 and not runtime.isRunning(),
            "expected not ok and reason and live == 0 and not runtime.isRunning()"
        )
        fail = false
        assert(runtime.start(), "expected runtime.start()")
        runtime.stop()
        assert(live == 0, "expected live == 0")
    end)
end
