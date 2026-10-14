return {
    id = "ReachDistance", type = "slider", name = "Reach Distance",
    section = "Distances", tab = "Main",
    default = 20, range = {1, 1000}, increment = 1, suffix = " studs",
    tooltip = "Object or player grab distance",
    onChanged = function(v, S) S.ReachDistance = v end
}