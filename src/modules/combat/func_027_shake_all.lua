-- Func #027: Shake All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShakeAll", type = "button", name = "Shake All",
    tooltip = "Shake everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    task.spawn(function()
                        for i = 1, 20 do
                            if not hrp.Parent then break end
                            hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), math.random(-3,3), math.random(-3,3))
                            task.wait(0.05)
                        end
                    end)
                end
            end
        end
    end
}