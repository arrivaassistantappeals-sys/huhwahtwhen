-- Func #179: Save Config | button
return {
    id = "SaveConfig", type = "button", name = "Save Config",
    tooltip = "Save config", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.save(Settings)
            if ok then
                Utils.notify("Resonance", "Config saved", Settings)
            else
                Utils.notify("Resonance", "Error: " .. tostring(err), Settings)
            end
        end
    end
}