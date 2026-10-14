-- Func #095: Spin Target | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "SpinTarget", type = "button", name = "Spin Target",
    tooltip = "Spin the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local av = Instance.new("BodyAngularVelocity")
            av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            av.AngularVelocity = Vector3.new(0, 100, 0)
            av.Parent = hrp
            Debris:AddItem(av, 5)
        end
    end
}