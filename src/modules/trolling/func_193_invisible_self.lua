-- Func #193: Invisible Self | button
return {
    id = "InvisibleSelf", type = "button", name = "Invisible Self",
    tooltip = "Make yourself invisible", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 1
            end
        end
        for _, acc in pairs(char:GetChildren()) do
            if acc:IsA("Accessory") then
                for _, h in pairs(acc:GetDescendants()) do
                    if h:IsA("BasePart") then h.Transparency = 1 end
                end
            end
        end
    end
}