-- Func #192: Ghost Self | button
return {
    id = "GhostSelf", type = "button", name = "Ghost Self",
    tooltip = "Make yourself translucent", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0.5 end
        end
    end
}