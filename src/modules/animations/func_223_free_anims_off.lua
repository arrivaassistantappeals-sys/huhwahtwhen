-- Func #223: Free Animations Off
-- Category: Animations | Type: toggle
-- Disable default movement animations

return {
    id = "FreeAnimsOff", type = "toggle", name = "Free Animations Off",
    tooltip = "Disable movement animations (walk/idle/jump)",
    tab = "Animations", default = false,
    onEnable = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, t in pairs(hum:GetPlayingAnimationTracks()) do
                pcall(function() t:Stop(0.2) end)
            end
        end
    end,
    onDisable = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = false end
    end
}