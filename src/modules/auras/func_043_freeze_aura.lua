-- Func #043: Freeze Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FreezeAura", type = "toggle", name = "Freeze Aura",
    tooltip = "Stop everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                if not Settings.FreezeAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.WalkSpeed = 0
                            hum.JumpPower = 0
                            hrp.Anchored = true
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hrp then hrp.Anchored = false end
                if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
            end
        end
    end
}