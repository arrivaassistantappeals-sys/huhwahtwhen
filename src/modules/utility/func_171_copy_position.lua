-- Func #171: Copy Position | button
return {
    id = "CopyPosition", type = "button", name = "Copy Position",
    tooltip = "Copy position", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp and setclipboard then
            setclipboard(tostring(hrp.Position))
            Utils.notify("Resonance", "Position copied", Settings)
        end
    end
}