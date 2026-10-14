-- Func #188: Head Spin All | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "HeadSpinAll", type = "button", name = "Head Spin All",
    tooltip = "Spin every player's head", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local av = Instance.new("BodyAngularVelocity")
                    av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    av.AngularVelocity = Vector3.new(0, 50, 0)
                    av.Parent = head
                    Debris:AddItem(av, 5)
                end
            end
        end
    end
}