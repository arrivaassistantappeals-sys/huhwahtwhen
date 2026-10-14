return {
    id = "FlingPower", type = "slider", name = "Fling Power",
    section = "Distances", tab = "Combat",
    default = 300, range = {50, 1000}, increment = 10, suffix = " p",
    tooltip = "Fling power",
    onChanged = function(v, S) S.FlingPower = v end
}