-- Func #032: Reset All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ResetAll", type = "button", name = "Reset All",
    tooltip = "Reset everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                pcall(function() p.Character:BreakJoints() end)
            end
        end
    end
}