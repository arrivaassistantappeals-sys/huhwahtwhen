-- Func #081: Loop Kill | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopKill", type = "toggle", name = "Loop Kill",
    tooltip = "Repeatedly kill the selected target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hum = target.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}