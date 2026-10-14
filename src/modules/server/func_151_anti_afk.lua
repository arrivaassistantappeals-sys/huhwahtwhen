-- Func #151: Anti-AFK | toggle
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AntiAfk", type = "toggle", name = "Anti-AFK",
    tooltip = "Prevent inactivity kicks", tab = "Server", default = true,
    onEnable = function(Settings, Utils)
        _G.ResonanceAntiAfkConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end,
    onDisable = function()
        if _G.ResonanceAntiAfkConn then
            _G.ResonanceAntiAfkConn:Disconnect()
            _G.ResonanceAntiAfkConn = nil
        end
    end
}