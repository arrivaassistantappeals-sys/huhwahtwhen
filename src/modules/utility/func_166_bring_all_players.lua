-- Func #166: Bring All Players | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BringAllPlayers", type = "button", name = "Bring All Players",
    tooltip = "Teleport all players to you", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                if thrp then
                    thrp.CFrame = hrp.CFrame + Vector3.new(math.random(-5,5), 3, math.random(-5,5))
                end
            end
        end
    end
}