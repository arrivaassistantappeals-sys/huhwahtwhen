-- Func #106: Low Gravity | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "LowGravity", type = "toggle", name = "Low Gravity",
    tooltip = "Low gravity", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceOrigGravity = Workspace.Gravity
        Workspace.Gravity = (Settings.Gravity or 196.2) / 4
    end,
    onDisable = function()
        Workspace.Gravity = _G.ResonanceOrigGravity or 196.2
    end
}