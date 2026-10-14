-- Func #158: Character Respawn | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CharacterRespawn", type = "button", name = "Character Respawn",
    tooltip = "Force character respawn", tab = "Server",
    onClick = function(Settings, Utils)
        pcall(function()
            LocalPlayer:LoadCharacter()
        end)
    end
}