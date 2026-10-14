-- Func #146: Copy PlaceID | button
return {
    id = "CopyPlaceId", type = "button", name = "Copy PlaceID",
    tooltip = "Copy the game's PlaceID", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            Utils.notify("Resonance", "PlaceID copied", Settings)
        end
    end
}