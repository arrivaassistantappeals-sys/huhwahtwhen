-- Func #153: Rejoin Delay | button
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "RejoinDelay", type = "button", name = "Rejoin in 3s",
    tooltip = "Rejoin after 3 seconds", tab = "Server",
    onClick = function(Settings, Utils)
        Utils.notify("Resonance", "Rejoining in 3 seconds...", Settings)
        task.wait(3)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
}