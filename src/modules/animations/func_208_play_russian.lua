-- Func #208: Russian dance
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771919"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayRussian",
    type    = "button",
    name    = "Russian dance",
    tooltip = "Play the Russian dance animation",
    tab     = "Animations",
    onClick = playAnim
}