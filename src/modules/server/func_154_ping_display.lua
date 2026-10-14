-- Func #154: Ping Display | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false }

local function loop()
    while State.running do
        task.wait(2)
        local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        print("[Resonance] Ping: " .. ping .. " ms")
    end
end

return {
    id = "PingDisplay", type = "toggle", name = "Ping Display",
    tooltip = "Print ping to the console", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end
}