-- Func #156: Leave Game | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "LeaveGame", type = "button", name = "Leave Game",
    tooltip = "Leave the game", tab = "Server",
    onClick = function(Settings, Utils)
        LocalPlayer:Kick("Resonance: leave")
    end
}