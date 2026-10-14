-- Func #120: Reset Speed | button
return {
    id = "ResetSpeed", type = "button", name = "Reset Speed",
    tooltip = "Reset speed and jump", tab = "Movement",
    onClick = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        Settings.WalkSpeed = 16
        Settings.JumpPower = 50
        Utils.notify("Resonance", "Speed reset", Settings)
    end
}