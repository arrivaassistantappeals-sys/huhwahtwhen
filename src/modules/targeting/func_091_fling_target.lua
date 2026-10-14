-- Func #091: Fling Target | button
local Players = game:GetService("Players")

return {
    id = "FlingTarget", type = "button", name = "Fling Target",
    tooltip = "Fling the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 400) end
    end
}