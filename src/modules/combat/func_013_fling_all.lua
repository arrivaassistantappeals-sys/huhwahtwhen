-- Func #013: Fling All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingAll", type = "button", name = "Fling All",
    tooltip = "Fling all players", tab = "Combat",
    onClick = function(Settings, Utils)
        local power = Settings.FlingPower or 300
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then Utils.fling(hrp, power) end
            end
        end
    end
}