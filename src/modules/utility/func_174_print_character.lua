-- Func #174: Print Character Tree | button
return {
    id = "PrintCharacter", type = "button", name = "Print Character Tree",
    tooltip = "Print the character hierarchy to the console", tab = "Utility",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        print("[Resonance] Character tree:")
        for _, v in pairs(char:GetDescendants()) do
            print("  " .. v:GetFullName())
        end
        Utils.notify("Resonance", "Hierarchy printed to the console", Settings)
    end
}