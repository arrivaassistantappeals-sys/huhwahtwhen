-- Func #132: Remove Textures | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveTextures", type = "toggle", name = "Remove Textures",
    tooltip = "Hide Decal/Texture", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
    end,
    onDisable = function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 0
            end
        end
    end
}