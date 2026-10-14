-- Func #084: Loop Freeze | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopFreeze", type = "toggle", name = "Loop Freeze",
    tooltip = "Repeatedly freeze the target", tab = "Targeting", default = false,
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
                    local hum = target.Character:FindFirstChildOfClass("Humanoid")
                    if hrp then hrp.Anchored = true end
                    if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if target and target.Character then
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            local hum = target.Character:FindFirstChildOfClass("Humanoid")
            if hrp then hrp.Anchored = false end
            if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
        end
    end
}