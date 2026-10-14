-- Func #157: Reset Character | button
return {
    id = "ResetCharacter", type = "button", name = "Reset Character",
    tooltip = "Reset your character", tab = "Server",
    onClick = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.Health = 0 end
    end
}