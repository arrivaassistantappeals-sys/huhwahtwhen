return {
    id = "ESPTeamCheck", type = "toggle", name = "Team Check",
    section = "ESP", tab = "Visuals",
    default = true,
    tooltip = "Hide allies",
    onChanged = function(v, S) S.ESPTeamCheck = v end
}