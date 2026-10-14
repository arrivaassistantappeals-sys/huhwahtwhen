-- Func #222: Stop All Anims
-- Category: Animations | Type: button

return {
    id = "StopAllAnims", type = "button", name = "Stop all animations",
    tooltip = "Stop all currently playing character animation tracks",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0.1) end)
        end
        _G.ResonanceCurrentAnim = nil
    end
}