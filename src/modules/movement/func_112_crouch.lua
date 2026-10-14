-- Func #112: Crouch | toggle
return {
    id = "Crouch", type = "toggle", name = "Crouch",
    tooltip = "Crouch", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if not hum then return end
        hum.BodyHeightScale.Value = 0.5
        hum.WalkSpeed = 8
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if not hum then return end
        hum.BodyHeightScale.Value = 1
        hum.WalkSpeed = Settings.WalkSpeed or 16
    end
}