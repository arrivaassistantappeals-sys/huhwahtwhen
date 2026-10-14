-- Func #187: Grow All | button
local Players = game:GetService("Players")

return {
    id = "GrowAll", type = "button", name = "Grow All",
    tooltip = "Enlarge all players", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.BodyDepthScale.Value = 3
                    hum.BodyWidthScale.Value = 3
                    hum.BodyHeightScale.Value = 3
                end
            end
        end
    end
}