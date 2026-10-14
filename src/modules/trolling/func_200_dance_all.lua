-- Func #200: Dance All | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "DanceAll", type = "button", name = "Dance All",
    tooltip = "Make everyone dance", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local animator = p.Character:FindFirstChildOfClass("Animator")
                if not animator then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum then animator = hum:FindFirstChildOfClass("Animator") end
                end
                if animator then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://507771019"
                    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
                    if ok and track then
                        pcall(function() track:Play() end)
                    end
                end
            end
        end
    end
}