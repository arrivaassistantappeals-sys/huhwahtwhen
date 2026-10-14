-- Func #196: Fake Death All | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FakeDeathAll", type = "button", name = "Fake Death All",
    tooltip = "Simulate everyone's death", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local maxHP = hum.MaxHealth
                    hum.Health = 0
                    task.wait(0.1)
                    hum.Health = maxHP
                end
            end
        end
    end
}