-- Func #044: Fire Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FireAura", type = "toggle", name = "Fire Aura",
    tooltip = "Set everyone within range on fire",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.FireAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            if not hrp:FindFirstChild("ResonanceFire") then
                                local f = Instance.new("Fire")
                                f.Name = "ResonanceFire"
                                f.Size = 5
                                f.Heat = 10
                                f.Parent = hrp
                                Debris:AddItem(f, 3)
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}