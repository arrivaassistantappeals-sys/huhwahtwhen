-- Func #098: Blind Target | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "BlindTarget", type = "button", name = "Blind Target",
    tooltip = "Blind the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target then return end
        pcall(function()
            local sg = Instance.new("ScreenGui")
            sg.Name = "ResonanceBlind"
            sg.ResetOnSpawn = false
            local f = Instance.new("Frame", sg)
            f.Size = UDim2.fromScale(1, 1)
            f.BackgroundColor3 = Color3.new(0, 0, 0)
            sg.Parent = target.PlayerGui
            Debris:AddItem(sg, 5)
        end)
    end
}