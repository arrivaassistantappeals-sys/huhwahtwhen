-- Func #113: Sprint | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "Sprint", type = "toggle", name = "Sprint",
    tooltip = "Sprint with Shift (×3)", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and hum.MoveDirection.Magnitude > 0 then
                    hum.WalkSpeed = (Settings.WalkSpeed or 16) * 3
                else
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}