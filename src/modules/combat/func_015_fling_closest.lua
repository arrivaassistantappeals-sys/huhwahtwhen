-- Func #015: Fling Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingClosest", type = "button", name = "Fling Closest",
    tooltip = "Fling the nearest player", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 300) end
    end
}