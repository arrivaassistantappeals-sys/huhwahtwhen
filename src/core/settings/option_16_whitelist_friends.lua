return {
    id = "WhitelistFriends", type = "toggle", name = "Whitelist Friends",
    section = "Exclusions", tab = "Filters",
    default = true,
    tooltip = "Ignore your friends",
    onChanged = function(v, S) S.WhitelistFriends = v end
}