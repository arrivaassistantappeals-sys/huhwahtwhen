-- Func #037: Hats Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "HatsOffAll", type = "button", name = "Hats Off All",
    tooltip = "Remove hats", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, a in pairs(p.Character:GetChildren()) do
                    if a:IsA("Accessory") then a:Destroy() end
                end
            end
        end
    end
}