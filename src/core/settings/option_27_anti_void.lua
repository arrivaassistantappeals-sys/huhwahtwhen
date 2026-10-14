return {
    id = "AntiVoid", type = "toggle", name = "Anti-Void",
    section = "Protection", tab = "Protection",
    default = true,
    tooltip = "Automatically return after falling below the map",
    onChanged = function(v, S) S.AntiVoid = v end
}