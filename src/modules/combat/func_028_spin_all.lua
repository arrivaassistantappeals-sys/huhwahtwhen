-- Func #028: Spin All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SpinAll", type = "button", name = "Spin All",
    tooltip = "Spin everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local av = Instance.new("BodyAngularVelocity")
                    av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    av.AngularVelocity = Vector3.new(0, 50, 0)
                    av.Parent = hrp
                    Debris:AddItem(av, 3)
                end
            end
        end
    end
}