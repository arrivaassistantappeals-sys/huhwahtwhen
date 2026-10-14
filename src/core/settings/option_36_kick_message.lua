return {
    id = "KickMessage", type = "input", name = "Kick Message",
    section = "Kick", tab = "Kick",
    default = "Resonance kicked you",
    tooltip = "Message for the target",
    onChanged = function(txt, S) S.KickMessage = txt end
}