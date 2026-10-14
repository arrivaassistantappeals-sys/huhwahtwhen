-- Func #185: Neon All | button
local Players = game:GetService("Players")

return {
    id = "NeonAll", type = "button", name = "Neon All",
    tooltip = "Make everyone neon", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Material = Enum.Material.Neon
                    end
                end
            end
        end
    end
}