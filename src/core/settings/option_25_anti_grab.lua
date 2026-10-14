return {
    id = "AntiGrab", type = "toggle", name = "Anti-Grab",
    section = "Protection", tab = "Protection",
    default = true,
    tooltip = "Immunity to other players' grabs",
    onChanged = function(v, S) S.AntiGrab = v end
}