-- Func #190: Rainbow Self | toggle
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local State = { running = false, hue = 0, conn = nil }

return {
    id = "RainbowSelf", type = "toggle", name = "Rainbow Self",
    tooltip = "Rainbow colors on your character", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function(dt)
            if not State.running then return end
            State.hue = (State.hue + dt * 0.3) % 1
            local color = Color3.fromHSV(State.hue, 1, 1)
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.Color = color end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}