-- Func #133: Blue Sky | toggle
local Lighting = game:GetService("Lighting")

return {
    id = "BlueSky", type = "toggle", name = "Blue Sky",
    tooltip = "Blue sky", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Name = "ResonanceSky"
            sky.SkyboxBk = "rbxassetid://159454299"
            sky.SkyboxDn = "rbxassetid://159454296"
            sky.SkyboxFt = "rbxassetid://159454293"
            sky.SkyboxLf = "rbxassetid://159454286"
            sky.SkyboxRt = "rbxassetid://159454300"
            sky.SkyboxUp = "rbxassetid://159454288"
            sky.Parent = Lighting
        end
    end,
    onDisable = function()
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if sky then sky:Destroy() end
    end
}