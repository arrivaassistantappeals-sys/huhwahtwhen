-- Func #036: Pants Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "PantsOffAll", type = "button", name = "Pants Off All",
    tooltip = "Remove pants", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local s = p.Character:FindFirstChildOfClass("Pants")
                if s then s:Destroy() end
            end
        end
    end
}