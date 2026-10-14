-- Func #109: Bunny Hop | toggle
local State = { running = false }

return {
    id = "BunnyHop", type = "toggle", name = "Bunny Hop",
    tooltip = "Jump while moving", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if hum and hum.MoveDirection.Magnitude > 0 then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}