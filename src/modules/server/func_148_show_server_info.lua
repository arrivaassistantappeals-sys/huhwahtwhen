-- Func #148: Show Server Info | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShowServerInfo", type = "button", name = "Show Server Info",
    tooltip = "Show server information", tab = "Server",
    onClick = function(Settings, Utils)
        local count = #Players:GetPlayers()
        local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        Utils.notify("Server Info", "Players: " .. count .. " | Ping: " .. ping .. " ms", Settings)
    end
}