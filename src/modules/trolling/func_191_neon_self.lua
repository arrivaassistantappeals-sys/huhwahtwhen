-- Func #191: Neon Self | button
return {
    id = "NeonSelf", type = "button", name = "Neon Self",
    tooltip = "Make yourself neon", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Material = Enum.Material.Neon end
        end
    end
}