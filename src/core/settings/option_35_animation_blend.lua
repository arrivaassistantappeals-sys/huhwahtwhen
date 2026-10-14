return {
    id = "AnimBlend", type = "slider", name = "Blend Weight",
    section = "Animations", tab = "Animations",
    default = 1, range = {0, 1}, increment = 0.05, suffix = " w",
    tooltip = "Animation blend weight",
    onChanged = function(v, S) S.AnimBlend = v end
}