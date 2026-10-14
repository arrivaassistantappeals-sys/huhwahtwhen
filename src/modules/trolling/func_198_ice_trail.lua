-- Func #198: Ice Trail | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "IceTrail", type = "toggle", name = "Ice Trail",
    tooltip = "Leave an ice trail", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if hrp then
                    local s = Instance.new("Smoke", hrp)
                    s.Color = Color3.fromRGB(180, 220, 255)
                    s.Size = 2
                    Debris:AddItem(s, 0.5)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}