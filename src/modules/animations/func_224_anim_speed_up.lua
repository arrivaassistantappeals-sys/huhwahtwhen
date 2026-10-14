-- Func #224: Anim Speed Up
-- Category: Animations | Type: button

return {
    id = "AnimSpeedUp", type = "button", name = "Speed up animations",
    tooltip = "Increase animation speed by +0.25x",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        Settings.AnimSpeed = math.min(5, (Settings.AnimSpeed or 1) + 0.25)
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:AdjustSpeed(Settings.AnimSpeed) end)
        end
        Utils.notify("Resonance", "Anim Speed: " .. Settings.AnimSpeed .. "x", Settings)
    end
}