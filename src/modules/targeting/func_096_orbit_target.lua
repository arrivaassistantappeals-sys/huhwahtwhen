-- Func #096: Orbit Target | button
local Players = game:GetService("Players")

return {
    id = "OrbitTarget", type = "button", name = "Orbit Target",
    tooltip = "Make the target orbit you", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local thrp = target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Utils.getHRP()
        if not thrp or not myHRP then return end
        task.spawn(function()
            for i = 1, 200 do
                if not thrp.Parent then break end
                local angle = i * 0.2
                local r = Settings.SpinRadius or 5
                thrp.CFrame = myHRP.CFrame * CFrame.new(math.cos(angle) * r, 3, math.sin(angle) * r)
                task.wait(0.05)
            end
        end)
    end
}