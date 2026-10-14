return {
    id = "KickDelay", type = "slider", name = "Kick Delay",
    section = "Kick", tab = "Kick",
    default = 0, range = {0, 5000}, increment = 100, suffix = " ms",
    tooltip = "Delay before kicking",
    onChanged = function(v, S) S.KickDelay = v end
}