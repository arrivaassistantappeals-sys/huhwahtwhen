-- ============================================================
-- Resonance v4.0 — core/loop.lua
-- Loop manager: start / stop / conditional
-- ============================================================

local Loop = {}
Loop.tasks = {}

-- Start a named loop
function Loop.start(name, fn, delay)
    Loop.stop(name)
    Loop.tasks[name] = task.spawn(function()
        while Loop.tasks[name] do
            local ok, err = pcall(fn)
            if not ok then
                warn("[Resonance Loop:" .. name .. "] " .. tostring(err))
                task.wait(1)
            end
            local d = delay
            if type(d) == "function" then d = d() end
            task.wait(d or 0.1)
        end
    end)
end

function Loop.stop(name)
    if Loop.tasks[name] then
        task.cancel(Loop.tasks[name])
        Loop.tasks[name] = nil
    end
end

function Loop.stopAll()
    for name in pairs(Loop.tasks) do
        Loop.stop(name)
    end
end

function Loop.isRunning(name)
    return Loop.tasks[name] ~= nil
end

-- Conditional loop: stop when condition() returns false
function Loop.conditional(name, condition, fn, delay)
    Loop.start(name, function()
        if not condition() then
            Loop.stop(name)
            return
        end
        fn()
    end, delay)
end

-- Wait with a condition
function Loop.awaitCondition(condition, timeout)
    local start = tick()
    timeout = timeout or 10
    while not condition() do
        if tick() - start > timeout then return false end
        task.wait(0.1)
    end
    return true
end

return Loop