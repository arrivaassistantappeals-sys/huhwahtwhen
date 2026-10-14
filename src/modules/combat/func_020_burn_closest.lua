-- Func #020: Burn Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BurnClosest", type = "button", name = "Burn Closest",
    tooltip = "Set the nearest player on fire", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Debris:AddItem(Instance.new("Fire", hrp), 5) end
    end
}