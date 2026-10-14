-- Func #199: Lightning Self | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "LightningSelf", type = "toggle", name = "Lightning Self",
    tooltip = "Lightning on your character", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                local hrp = Utils.getHRP()
                if hrp then
                    local sp = Instance.new("Sparkles", hrp)
                    sp.SparkleColor = Color3.fromRGB(150, 200, 255)
                    Debris:AddItem(sp, 0.6)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}