-- Func #170: Full Screen | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "FullScreen", type = "toggle", name = "Full Screen",
    tooltip = "Unlock the cursor from the center", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end,
    onDisable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
}