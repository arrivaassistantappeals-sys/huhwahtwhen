-- Func #197: Fire Trail | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "FireTrail", type = "toggle", name = "Fire Trail",
    tooltip = "Leave a fire trail", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if hrp then
                    local f = Instance.new("Fire", hrp)
                    Debris:AddItem(f, 0.5)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}