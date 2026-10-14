return {
    id = "SpinRadius", type = "slider", name = "Spin Radius",
    section = "Tornado", tab = "Auras",
    default = 5, range = {1, 50}, increment = 1, suffix = " studs",
    tooltip = "Orbit radius around you",
    onChanged = function(v, S) S.SpinRadius = v end
}