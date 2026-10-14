-- Func #142: Server Hop | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ServerHop", type = "button", name = "Server Hop",
    tooltip = "Join a random server", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data and #res.data > 0 then
            local srv = res.data[math.random(1, #res.data)]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
            end)
        end
    end
}