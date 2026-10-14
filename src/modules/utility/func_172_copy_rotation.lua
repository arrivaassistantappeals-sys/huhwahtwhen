-- Func #172: Copy Rotation | button
return {
    id = "CopyRotation", type = "button", name = "Copy Rotation",
    tooltip = "Copy rotation", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp and setclipboard then
            setclipboard(tostring(hrp.Orientation))
            Utils.notify("Resonance", "Rotation copied", Settings)
        end
    end
}