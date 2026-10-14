return {
    id = "RGBMode", type = "toggle", name = "RGB / Rainbow Mode",
    section = "Visuals", tab = "Visuals",
    default = false,
    tooltip = "Cycle elements through all colors",
    onChanged = function(v, S) S.RGBMode = v end
}