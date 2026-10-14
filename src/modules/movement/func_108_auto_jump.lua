-- Func #108: Auto Jump | toggle
local State = { running = false }

return {
    id = "AutoJump", type = "toggle", name = "Auto Jump",
    tooltip = "Auto jump", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hum = Utils.getHum()
                if hum and hum.FloorMaterial ~= Enum.Material.Air then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}