return {
    id = "TargetLockMethod", type = "dropdown", name = "Target Lock Method",
    section = "Aiming", tab = "Combat",
    default = "Nearest player",
    options = {"By cursor","Nearest player","By username from the list"},
    multiple = false,
    tooltip = "Aim assist algorithm",
    onChanged = function(opt, S) S.TargetLockMethod = opt[1] end
}