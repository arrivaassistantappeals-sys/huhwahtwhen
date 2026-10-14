-- Func #100: Copy Target Skin | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CopyTargetSkin", type = "button", name = "Copy Target Skin",
    tooltip = "Copy the target character's colors", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        for _, part in pairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then
                local src = target.Character:FindFirstChild(part.Name)
                if src and src:IsA("BasePart") then
                    part.Color = src.Color
                    part.Material = src.Material
                end
            end
        end
    end
}