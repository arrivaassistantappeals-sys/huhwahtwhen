-- Func #030: Speed All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SpeedAll", type = "button", name = "Speed All",
    tooltip = "Speed everyone up", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 200 end
            end
        end
    end
}