-- Func #128: Chams | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "Chams", type = "toggle", name = "Chams",
    tooltip = "Highlight players with color", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        _G.ResonanceChamsConn = game:GetService("RunService").RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then continue end
                if p.Character then
                    for _, part in pairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.Material = Enum.Material.ForceField
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if _G.ResonanceChamsConn then
            _G.ResonanceChamsConn:Disconnect()
            _G.ResonanceChamsConn = nil
        end
    end
}