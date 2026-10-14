-- Func #033: Anchor All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AnchorAll", type = "button", name = "Anchor All",
    tooltip = "Anchor everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = true end
            end
        end
    end
}