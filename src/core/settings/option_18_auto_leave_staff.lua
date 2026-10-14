return {
    id = "AutoLeaveStaff", type = "toggle", name = "Auto-Leave on Staff",
    section = "Exclusions", tab = "Filters",
    default = false,
    tooltip = "Leave immediately when a moderator is detected",
    onChanged = function(v, S) S.AutoLeaveStaff = v end
}