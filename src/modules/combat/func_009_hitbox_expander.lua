-- Func #009: Hitbox Expander | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "HitboxExpander", type = "toggle", name = "Hitbox Expander",
    tooltip = "Enlarge player hitboxes", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Size = Vector3.new(20, 20, 20)
                            hrp.Transparency = 0.7
                            hrp.CanCollide = false
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                end
            end
        end
    end
}