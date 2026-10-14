-- Func #008: Kill Aura | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "KillAuraCombat", type = "toggle", name = "Kill Aura",
    tooltip = "Kill everyone within range", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.Health = 0
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}