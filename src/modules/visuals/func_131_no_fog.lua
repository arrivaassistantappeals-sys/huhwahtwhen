-- Func #131: No Fog | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "NoFog", type = "toggle", name = "No Fog",
    tooltip = "Remove fog", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.FogEnd
        Lighting.FogEnd = 1e6
    end,
    onDisable = function()
        Lighting.FogEnd = State.orig or 1000
    end
}