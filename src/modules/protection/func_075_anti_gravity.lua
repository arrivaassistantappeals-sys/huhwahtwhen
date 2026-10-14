-- Func #075: Anti-Gravity | toggle
local Workspace = game:GetService("Workspace")

local State = { running = false, conn = nil, restores = 0 }
local BASE = 196.2

local function restore()
    if math.abs(Workspace.Gravity - BASE) > 5 then
        Workspace.Gravity = BASE
        State.restores = State.restores + 1
    end
end

local function loop()
    while State.running do
        task.wait(0.5)
        restore()
    end
end

return {
    id = "AntiGravity", type = "toggle", name = "Anti-Gravity",
    tooltip = "Protection against gravity changes", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.restores = 0
        State.conn = Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
            if State.running then restore() end
        end)
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { restores = State.restores } end
}