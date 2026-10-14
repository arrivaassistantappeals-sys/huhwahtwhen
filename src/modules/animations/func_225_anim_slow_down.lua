-- Func #225: Anim Slow Down
-- Category: Animations | Type: button

return {
    id = "AnimSlowDown", type = "button", name = "Slow down animations",
    tooltip = "Decrease animation speed by -0.25x",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        Settings.AnimSpeed = math.max(0.1, (Settings.AnimSpeed or 1) - 0.25)
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:AdjustSpeed(Settings.AnimSpeed) end)
        end
        Utils.notify("Resonance", "Anim Speed: " .. Settings.AnimSpeed .. "x", Settings)
    end
}