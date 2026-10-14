return {
    id = "WhitelistPlots", type = "toggle", name = "Whitelist Plots",
    section = "Exclusions", tab = "Filters",
    default = false,
    tooltip = "Leave players on their plots alone",
    onChanged = function(v, S) S.WhitelistPlots = v end
}