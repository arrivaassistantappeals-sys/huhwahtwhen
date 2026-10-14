return {
    id = "Fullbright", type = "toggle", name = "Fullbright",
    section = "Lighting", tab = "Visuals",
    default = false,
    tooltip = "Full brightness",
    onChanged = function(v, S)
        S.Fullbright = v
        local L = game:GetService("Lighting")
        L.Ambient = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
        L.OutdoorAmbient = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
    end
}