-- Func #161: Anti-AFK | toggle
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AntiAfkUtil", type = "toggle", name = "Anti-AFK",
    tooltip = "Prevent AFK kicks", tab = "Utility", default = true,
    onEnable = function(Settings, Utils)
        _G.ResonanceAntiAfkUtilConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end,
    onDisable = function()
        if _G.ResonanceAntiAfkUtilConn then
            _G.ResonanceAntiAfkUtilConn:Disconnect()
            _G.ResonanceAntiAfkUtilConn = nil
        end
    end
}