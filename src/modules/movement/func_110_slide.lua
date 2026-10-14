-- Func #110: Slide | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "Slide", type = "toggle", name = "Slide",
    tooltip = "Slide with Shift", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    hum.WalkSpeed = 150
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