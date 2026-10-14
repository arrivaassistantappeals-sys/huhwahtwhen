-- Func #141: Rejoin | button
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "Rejoin", type = "button", name = "Rejoin",
    tooltip = "Rejoin the current server", tab = "Server",
    onClick = function(Settings, Utils)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end
}