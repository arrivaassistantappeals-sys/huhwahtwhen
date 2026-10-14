-- Func #085: Loop Void | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopVoid", type = "toggle", name = "Loop Void",
    tooltip = "Repeatedly send the target into the void", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}