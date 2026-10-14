return {
    id = "AnimSpeed", type = "slider", name = "Animation Speed",
    section = "Animations", tab = "Animations",
    default = 1, range = {0.1, 5}, increment = 0.1, suffix = "x",
    tooltip = "Animation playback speed",
    onChanged = function(v, S) S.AnimSpeed = v end
}