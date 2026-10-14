-- Func #048: Plot Kicker
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "PlotKicker", type = "toggle", name = "Plot Kicker",
    tooltip = "Throw intruders off your plot",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.PlotKicker then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = hrp.CFrame + Vector3.new(0, 100, 0)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}