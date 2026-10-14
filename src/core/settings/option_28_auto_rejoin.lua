return {
    id = "AutoRejoin", type = "toggle", name = "Auto Rejoin",
    section = "Server", tab = "Server",
    default = false,
    tooltip = "Automatically rejoin after being kicked",
    onChanged = function(v, S) S.AutoRejoin = v end
}