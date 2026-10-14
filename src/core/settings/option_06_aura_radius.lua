return {
    id = "AuraRadius", type = "slider", name = "Aura Radius",
    section = "Aura", tab = "Auras",
    default = 15, range = {1, 100}, increment = 1, suffix = " studs",
    tooltip = "Aura range",
    onChanged = function(v, S) S.AuraRadius = v end
}