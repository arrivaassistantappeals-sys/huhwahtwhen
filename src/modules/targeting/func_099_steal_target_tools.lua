-- Func #099: Steal Target Tools | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "StealTargetTools", type = "button", name = "Steal Target Tools",
    tooltip = "Steal the target's tools", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        for _, t in pairs(target.Character:GetChildren()) do
            if t:IsA("Tool") then
                pcall(function() t.Parent = myChar end)
            end
        end
    end
}