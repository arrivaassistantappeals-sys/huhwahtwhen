-- Func #135: Green Ambient | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "GreenAmbient", type = "toggle", name = "Green Ambient",
    tooltip = "Green lighting", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.Ambient
        Lighting.Ambient = Color3.fromRGB(0, 255, 0)
    end,
    onDisable = function()
        Lighting.Ambient = State.orig or Color3.fromRGB(0, 0, 0)
    end
}