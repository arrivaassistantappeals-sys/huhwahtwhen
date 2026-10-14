-- Func #129: X-Ray | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "XRay", type = "toggle", name = "X-Ray",
    tooltip = "Transparent walls (using LocalTransparencyModifier)", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0.5
                    end
                end
            end
        end
    end,
    onDisable = function()
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end
}