-- Func #021: Freeze All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FreezeAll", type = "button", name = "Freeze All",
    tooltip = "Freeze everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
            end
        end
    end
}