-- Func #051: Damage Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }
local DAMAGE_PER_TICK = 5

return {
    id = "DamageAura", type = "toggle", name = "Damage Aura",
    tooltip = "Damage everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.DamageAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum:TakeDamage(DAMAGE_PER_TICK)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}