-- Func #152: Auto Rejoin on Kick | toggle
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AutoRejoinKick", type = "toggle", name = "Auto Rejoin on Kick",
    tooltip = "Automatically rejoin when kicked", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAutoRejoin = true
    end,
    onDisable = function()
        _G.ResonanceAutoRejoin = false
    end
}