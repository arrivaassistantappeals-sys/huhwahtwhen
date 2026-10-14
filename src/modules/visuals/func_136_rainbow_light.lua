-- Func #136: Rainbow Light | toggle
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local State = { running = false, conn = nil, hue = 0 }

return {
    id = "RainbowLight", type = "toggle", name = "Rainbow Light",
    tooltip = "Rainbow lighting", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function(dt)
            if not State.running then return end
            State.hue = (State.hue + dt * 0.3) % 1
            Lighting.Ambient = Color3.fromHSV(State.hue, 1, 1)
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
    end
}