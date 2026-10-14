-- Func #024: Explode All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ExplodeAll", type = "button", name = "Explode All",
    tooltip = "Explode everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local e = Instance.new("Explosion")
                    e.Position = hrp.Position
                    e.BlastRadius = 15
                    e.BlastPressure = 500000
                    e.Parent = workspace
                end
            end
        end
    end
}