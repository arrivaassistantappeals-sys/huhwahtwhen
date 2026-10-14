-- Func #088: TP to Target | button
local Players = game:GetService("Players")

return {
    id = "TpToTarget", type = "button", name = "TP to Target",
    tooltip = "Teleport to target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 3, 0)) end
    end
}