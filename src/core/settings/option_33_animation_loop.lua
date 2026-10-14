return {
    id = "AnimLoop", type = "toggle", name = "Loop Animations",
    section = "Animations", tab = "Animations",
    default = true,
    tooltip = "Loop the animation",
    onChanged = function(v, S) S.AnimLoop = v end
}