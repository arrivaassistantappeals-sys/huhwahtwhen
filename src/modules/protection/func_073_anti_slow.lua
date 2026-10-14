-- Func #073: Anti-Slow | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, wsRestores = 0, jpRestores = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.05)
        local hum = getHum(); if not hum then continue end
        if hum.WalkSpeed < 16 then
            hum.WalkSpeed = 16
            State.wsRestores = State.wsRestores + 1
        end
        if hum.JumpPower < 50 then
            hum.JumpPower = 50
            State.jpRestores = State.jpRestores + 1
        end
    end
end

return {
    id = "AntiSlow", type = "toggle", name = "Anti-Slow",
    tooltip = "Protection against speed reduction", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.wsRestores = 0
        State.jpRestores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { wsRestores = State.wsRestores, jpRestores = State.jpRestores } end
}