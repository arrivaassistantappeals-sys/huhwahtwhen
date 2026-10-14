-- Func #189: Random Color Self | button
return {
    id = "RandomColorSelf", type = "button", name = "Random Color Self",
    tooltip = "Give yourself random colors", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Color = Color3.fromHSV(math.random(), 1, 1)
            end
        end
    end
}