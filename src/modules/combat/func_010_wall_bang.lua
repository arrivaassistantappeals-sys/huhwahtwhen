-- Func #010: Wall Bang | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "WallBang", type = "toggle", name = "Wall Bang",
    tooltip = "Damage through walls", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude < 30 then
                            hum:TakeDamage(10)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}