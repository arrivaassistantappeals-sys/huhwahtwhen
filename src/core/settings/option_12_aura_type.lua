return {
    id = "AuraType", type = "dropdown", name = "Aura Type",
    section = "Aura", tab = "Auras",
    default = "Fling", options = {"Fling","Kill","Freeze","Fire","Void"},
    multiple = false,
    tooltip = "Aura mode",
    onChanged = function(opt, S) S.AuraType = opt[1] end
}