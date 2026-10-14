-- Func #035: Shirt Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShirtOffAll", type = "button", name = "Shirt Off All",
    tooltip = "Remove shirts", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local s = p.Character:FindFirstChildOfClass("Shirt")
                if s then s:Destroy() end
            end
        end
    end
}