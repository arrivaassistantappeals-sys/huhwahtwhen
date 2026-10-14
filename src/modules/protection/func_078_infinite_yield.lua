-- Func #078: Infinite Yield | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, respawns = 0, lastDeath = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.5)
        local hum = getHum()
        if hum and hum.Health <= 0 then
            if tick() - State.lastDeath > 0.5 then
                State.lastDeath = tick()
                pcall(function() LocalPlayer:LoadCharacter() end)
                State.respawns = State.respawns + 1
            end
        end
    end
end

return {
    id = "InfiniteYield", type = "toggle", name = "Infinite Yield",
    tooltip = "Automatically respawn on death", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.respawns = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { respawns = State.respawns } end
}