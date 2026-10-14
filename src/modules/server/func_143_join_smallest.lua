-- Func #143: Join Smallest Server | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JoinSmallest", type = "button", name = "Join Smallest Server",
    tooltip = "Join the server with the fewest players", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data then
            local best, count = nil, math.huge
            for _, s in pairs(res.data) do
                if s.playing and s.playing < count then
                    best, count = s, s.playing
                end
            end
            if best then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
            end
        end
    end
}