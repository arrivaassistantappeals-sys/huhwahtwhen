-- Func #105: High Jump | toggle
return {
    id = "HighJump", type = "toggle", name = "High Jump",
    tooltip = "High jump", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.JumpPower = Settings.JumpPower or 200 end
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.JumpPower = 50 end
    end
}