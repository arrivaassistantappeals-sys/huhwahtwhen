-- Func #144: Join Largest Server | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JoinLargest", type = "button", name = "Join Largest Server",
    tooltip = "Join the fullest server", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
        end)
        if ok and res and res.data and #res.data > 0 then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, res.data[1].id, LocalPlayer)
            end)
        end
    end
}