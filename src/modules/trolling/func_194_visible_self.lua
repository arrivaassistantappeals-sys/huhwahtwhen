-- Func #194: Visible Self | button
return {
    id = "VisibleSelf", type = "button", name = "Visible Self",
    tooltip = "Restore visibility", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0 end
        end
    end
}