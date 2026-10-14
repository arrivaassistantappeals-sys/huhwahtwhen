-- Func #090: Kill Target | button
local Players = game:GetService("Players")

return {
    id = "KillTarget", type = "button", name = "Kill Target",
    tooltip = "Kill the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}