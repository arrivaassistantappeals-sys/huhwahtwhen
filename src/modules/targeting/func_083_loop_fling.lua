-- Func #083: Loop Fling | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopFling", type = "toggle", name = "Loop Fling",
    tooltip = "Repeatedly fling the target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then Utils.fling(hrp, Settings.FlingPower or 400) end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}