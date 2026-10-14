-- Func #017: Kill Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillClosest", type = "button", name = "Kill Closest",
    tooltip = "Kill the nearest player", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}