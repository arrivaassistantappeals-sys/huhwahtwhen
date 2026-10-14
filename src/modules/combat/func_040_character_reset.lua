-- Func #040: Character Reset (Self) | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CharacterReset", type = "button", name = "Character Reset (Self)",
    tooltip = "Reset yourself", tab = "Combat",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if char then pcall(function() char:BreakJoints() end) end
    end
}