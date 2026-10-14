-- Func #169: Unlock Mouse | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "UnlockMouse", type = "toggle", name = "Unlock Mouse",
    tooltip = "Show cursor", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        UserInputService.MouseIconEnabled = true
    end,
    onDisable = function(Settings, Utils)
        UserInputService.MouseIconEnabled = false
    end
}