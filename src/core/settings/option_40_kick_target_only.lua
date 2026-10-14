return {
    id = "KickTargetOnly", type = "toggle", name = "Kick Selected Target Only",
    section = "Kick", tab = "Kick",
    default = false,
    tooltip = "Apply kicks only to the selected target",
    onChanged = function(v, S) S.KickTargetOnly = v end
}