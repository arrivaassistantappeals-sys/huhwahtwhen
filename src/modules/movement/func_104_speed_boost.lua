-- Func #104: Speed Boost | toggle
return {
    id = "SpeedBoost", type = "toggle", name = "Speed Boost",
    tooltip = "Speed boost", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = Settings.WalkSpeed or 100 end
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}