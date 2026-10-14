return {
    id = "KickReason", type = "input", name = "Kick Reason",
    section = "Kick", tab = "Kick",
    default = "You have been removed",
    tooltip = "Kick reason",
    onChanged = function(txt, S) S.KickReason = txt end
}