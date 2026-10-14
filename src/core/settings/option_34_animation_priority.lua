return {
    id = "AnimPriority", type = "dropdown", name = "Animation Priority",
    section = "Animations", tab = "Animations",
    default = "Action",
    options = {"Idle","Movement","Action","Action2","Action3","Action4","Core"},
    multiple = false,
    tooltip = "Animation priority",
    onChanged = function(opt, S) S.AnimPriority = opt[1] end
}