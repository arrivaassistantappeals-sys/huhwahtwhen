-- Func #147: Copy Server Link | button
return {
    id = "CopyServerLink", type = "button", name = "Copy Server Link",
    tooltip = "Copy server link", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            local link = "roblox://placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId
            setclipboard(link)
            Utils.notify("Resonance", "Link copied", Settings)
        end
    end
}