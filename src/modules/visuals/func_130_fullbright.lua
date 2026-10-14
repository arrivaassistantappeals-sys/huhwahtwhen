-- Func #130: Fullbright | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = {} }

return {
    id = "Fullbright", type = "toggle", name = "Fullbright",
    tooltip = "Full brightness", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig.Ambient = Lighting.Ambient
        State.orig.OutdoorAmbient = Lighting.OutdoorAmbient
        State.orig.Brightness = Lighting.Brightness
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 3
    end,
    onDisable = function()
        if State.orig.Ambient then Lighting.Ambient = State.orig.Ambient end
        if State.orig.OutdoorAmbient then Lighting.OutdoorAmbient = State.orig.OutdoorAmbient end
        if State.orig.Brightness then Lighting.Brightness = State.orig.Brightness end
    end
}