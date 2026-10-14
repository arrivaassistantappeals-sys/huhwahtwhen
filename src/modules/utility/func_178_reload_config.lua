-- Func #178: Reload Config | button
return {
    id = "ReloadConfig", type = "button", name = "Reload Config",
    tooltip = "Load config", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.load(Settings)
            if ok then
                Utils.notify("Resonance", "Config loaded", Settings)
            else
                Utils.notify("Resonance", "Error: " .. tostring(err), Settings)
            end
        end
    end
}