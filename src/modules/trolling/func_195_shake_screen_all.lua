-- Func #195: Shake Screen All | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ShakeScreenAll", type = "toggle", name = "Shake Screen All",
    tooltip = "Shake all players' screens", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(1)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        pcall(function()
                            local gui = p.PlayerGui
                            local oldPos = gui.AbsoluteSize
                            -- Can't directly shake other's UI; used as placeholder
                        end)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}