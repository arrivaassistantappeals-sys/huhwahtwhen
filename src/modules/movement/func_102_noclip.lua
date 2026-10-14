-- Func #102: Noclip | toggle
local RunService = game:GetService("RunService")

return {
    id = "NoclipMove", type = "toggle", name = "Noclip",
    tooltip = "Walk through walls", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceNoclipConn = RunService.Stepped:Connect(function()
            if not Settings.NoclipMove then return end
            local char = Utils.getChar()
            if not char then return end
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    end,
    onDisable = function()
        if _G.ResonanceNoclipConn then
            _G.ResonanceNoclipConn:Disconnect()
            _G.ResonanceNoclipConn = nil
        end
        local char = Utils.getChar()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end
}