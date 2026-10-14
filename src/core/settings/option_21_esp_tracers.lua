return {
    id = "ESPTracers", type = "toggle", name = "ESP Tracers",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Lines from the bottom of the screen to players",
    onChanged = function(v, S) S.ESPTracers = v end
}