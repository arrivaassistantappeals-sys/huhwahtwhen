-- Func #019: Burn All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BurnAll", type = "button", name = "Burn All",
    tooltip = "Set everyone on fire", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then Debris:AddItem(Instance.new("Fire", hrp), 5) end
            end
        end
    end
}