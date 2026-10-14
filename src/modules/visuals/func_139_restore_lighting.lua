-- Func #139: Restore Lighting | button
local Lighting = game:GetService("Lighting")

return {
    id = "RestoreLighting", type = "button", name = "Restore Lighting",
    tooltip = "Reset lighting", tab = "Visuals",
    onClick = function(Settings, Utils)
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
        Lighting.FogEnd = 1000
        Lighting.Brightness = 1
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if sky then sky:Destroy() end
        Utils.notify("Resonance", "Lighting reset", Settings)
    end
}