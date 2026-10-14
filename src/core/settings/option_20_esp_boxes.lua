return {
    id = "ESPBoxes", type = "toggle", name = "ESP Boxes",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Boxes around players",
    onChanged = function(v, S) S.ESPBoxes = v end
}