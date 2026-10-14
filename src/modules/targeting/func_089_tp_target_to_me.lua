-- Func #089: TP Target to Me | button
local Players = game:GetService("Players")

return {
    id = "TpTargetToMe", type = "button", name = "TP Target to Me",
    tooltip = "Teleport the target to you", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local thrp = target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Utils.getHRP()
        if thrp and myHRP then
            thrp.CFrame = myHRP.CFrame + Vector3.new(0, 3, 0)
        end
    end
}