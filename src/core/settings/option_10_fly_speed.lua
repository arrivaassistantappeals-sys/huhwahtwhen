return {
    id = "FlySpeed", type = "slider", name = "Fly Speed",
    section = "Movement", tab = "Movement",
    default = 50, range = {10, 500}, increment = 5, suffix = " studs",
    tooltip = "Fly speed",
    onChanged = function(v, S) S.FlySpeed = v end
}