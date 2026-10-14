return {
    id = "Notifications", type = "toggle", name = "Notifications",
    section = "Interface", tab = "Settings",
    default = true,
    tooltip = "Show popup notifications",
    onChanged = function(v, S) S.Notifications = v end
}