-- Func #176: Toggle UI | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ToggleUi", type = "button", name = "Toggle UI",
    tooltip = "Show/hide UI", tab = "Utility",
    onClick = function(Settings, Utils)
        local gui = LocalPlayer.PlayerGui:FindFirstChild("ResonanceMenu")
            or LocalPlayer.PlayerGui:FindFirstChildOfClass("ScreenGui")
        if gui then
            gui.Enabled = not gui.Enabled
        end
    end
}