-- Func #107: Zero Gravity | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "ZeroGravity", type = "toggle", name = "Zero Gravity",
    tooltip = "Weightlessness", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceOrigGravity2 = Workspace.Gravity
        Workspace.Gravity = 0
    end,
    onDisable = function()
        Workspace.Gravity = _G.ResonanceOrigGravity2 or 196.2
    end
}