return {
    id = "KickRepeat", type = "toggle", name = "Repeat Kick",
    section = "Kick", tab = "Kick",
    default = false,
    tooltip = "Repeat kicks in a loop",
    onChanged = function(v, S) S.KickRepeat = v end
}