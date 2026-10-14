-- Func #150: Hop Until Empty | toggle
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, hops = 0 }

local function loop()
    while State.running do
        task.wait(5)
        if #Players:GetPlayers() <= 1 then
            Utils_notify("Resonance", "Server is empty — stopping", Settings)
            State.running = false
            break
        end
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
            if best and count < #Players:GetPlayers() then
                State.hops = State.hops + 1
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
                break
            end
        end
    end
end

return {
    id = "HopUntilEmpty", type = "toggle", name = "Hop Until Empty",
    tooltip = "Server hop until an empty server is found", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        State.hops = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { hops = State.hops } end
}