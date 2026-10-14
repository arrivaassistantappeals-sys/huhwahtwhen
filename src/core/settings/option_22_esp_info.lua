return {
    id = "ESPInfo", type = "toggle", name = "Player Info",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Name, HP, and distance",
    onChanged = function(v, S) S.ESPInfo = v end
}