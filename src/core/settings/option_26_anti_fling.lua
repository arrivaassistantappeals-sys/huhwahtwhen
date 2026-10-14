return {
    id = "AntiFling", type = "toggle", name = "Anti-Fling",
    section = "Protection", tab = "Protection",
    default = true,
    tooltip = "Fling immunity",
    onChanged = function(v, S) S.AntiFling = v end
}