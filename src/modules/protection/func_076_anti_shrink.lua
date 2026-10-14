-- Func #076: Anti-Shrink | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, restores = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.2)
        local hum = getHum(); if not hum then continue end
        local r = false
        if hum.BodyDepthScale.Value < 0.95 then hum.BodyDepthScale.Value = 1; r = true end
        if hum.BodyWidthScale.Value < 0.95 then hum.BodyWidthScale.Value = 1; r = true end
        if hum.BodyHeightScale.Value < 0.95 then hum.BodyHeightScale.Value = 1; r = true end
        if r then State.restores = State.restores + 1 end
    end
end

return {
    id = "AntiShrink", type = "toggle", name = "Anti-Shrink",
    tooltip = "Prevent character shrinking", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.restores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { restores = State.restores } end
}