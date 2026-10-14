-- Func #183: Fling Random Aura | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FlingRandomAura", type = "toggle", name = "Fling Random Aura",
    tooltip = "Randomly fling nearby players", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(2)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                local list = {}
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude < (Settings.AuraRadius or 15) then
                            table.insert(list, hrp)
                        end
                    end
                end
                if #list > 0 then
                    Utils.fling(list[math.random(1, #list)], Settings.FlingPower or 400)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}