-- Func #080: Rejoin on Damage | toggle
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, triggered = false, lastHP = 100 }
local THRESHOLD = 50

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.2)
        local hum = getHum(); if not hum then continue end
        local hp = hum.Health
        local maxHP = hum.MaxHealth

        if hp <= 0 and not State.triggered then
            State.triggered = true
            task.wait(1)
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            break
        end

        if maxHP > 0 then
            local percent = (hp / maxHP) * 100
            if percent < THRESHOLD and State.lastHP >= THRESHOLD and not State.triggered then
                State.triggered = true
                task.wait(1)
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
                break
            end
        end

        State.lastHP = hp
    end
end

return {
    id = "RejoinDamage", type = "toggle", name = "Rejoin on Damage",
    tooltip = "Rejoin when damaged", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.triggered = false
        State.lastHP = 100
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { triggered = State.triggered } end
}