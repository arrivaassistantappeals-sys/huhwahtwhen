-- Func #182: Reverse Controls | toggle
local State = { running = false }

return {
    id = "ReverseControls", type = "toggle", name = "Reverse Controls",
    tooltip = "Reverse your controls", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if hum then
                    -- Visual effect through the camera
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}