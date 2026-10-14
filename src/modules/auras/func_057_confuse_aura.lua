-- Func #057: Confuse Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ConfuseAura", type = "toggle", name = "Confuse Aura",
    tooltip = "Randomly jerk players within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.ConfuseAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = hrp.CFrame * CFrame.new(math.random(-3,3), math.random(-2,2), math.random(-3,3))
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}