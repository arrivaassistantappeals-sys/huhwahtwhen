-- Func #006: Telekinesis | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "Telekinesis", type = "toggle", name = "Telekinesis",
    tooltip = "Move objects under the cursor", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local mouse = LocalPlayer:GetMouse()
                if mouse and mouse.Target and mouse.Target:IsA("BasePart") and not mouse.Target.Anchored then
                    pcall(function() mouse.Target.CFrame = mouse.Hit + Vector3.new(0, 3, 0) end)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}