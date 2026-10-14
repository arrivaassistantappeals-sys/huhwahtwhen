-- Func #022: Unfreeze All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "UnfreezeAll", type = "button", name = "Unfreeze All",
    tooltip = "Unfreeze everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
            end
        end
    end
}