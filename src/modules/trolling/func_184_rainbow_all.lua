-- Func #184: Rainbow All | button
local Players = game:GetService("Players")

return {
    id = "RainbowAll", type = "button", name = "Rainbow All",
    tooltip = "Color all players", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Color = Color3.fromHSV(math.random(), 1, 1)
                    end
                end
            end
        end
    end
}