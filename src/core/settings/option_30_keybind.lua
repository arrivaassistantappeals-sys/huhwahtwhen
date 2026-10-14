return {
    id = "Keybind", type = "keybind", name = "Menu Keybind",
    section = "Interface", tab = "Settings",
    default = "RightShift",
    tooltip = "Menu toggle key",
    onChanged = function(v, S) S.Keybind = v end
}