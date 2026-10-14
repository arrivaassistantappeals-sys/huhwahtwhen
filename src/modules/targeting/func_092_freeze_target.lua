-- Func #092: Freeze Target | button
local Players = game:GetService("Players")

return {
    id = "FreezeTarget", type = "button", name = "Freeze Target",
    tooltip = "Freeze the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hrp then hrp.Anchored = true end
        if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
    end
}