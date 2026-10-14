-- Func #186: Shrink All | button
local Players = game:GetService("Players")

return {
    id = "ShrinkAll", type = "button", name = "Shrink All",
    tooltip = "Shrink all players", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.BodyDepthScale.Value = 0.3
                    hum.BodyWidthScale.Value = 0.3
                    hum.BodyHeightScale.Value = 0.3
                end
            end
        end
    end
}