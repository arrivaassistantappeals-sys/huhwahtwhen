-- Func #039: Forcefield Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ForcefieldOffAll", type = "button", name = "Forcefield Off All",
    tooltip = "Remove Forcefield", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local ff = p.Character:FindFirstChildOfClass("ForceField")
                if ff then ff:Destroy() end
            end
        end
    end
}