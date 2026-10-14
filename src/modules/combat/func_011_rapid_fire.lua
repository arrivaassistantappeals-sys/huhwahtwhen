-- Func #011: Rapid Fire | toggle
local State = { running = false }

return {
    id = "RapidFire", type = "toggle", name = "Rapid Fire",
    tooltip = "Rapid fire", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local char = Utils.getChar()
                if char then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        pcall(function() tool:Activate() end)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}