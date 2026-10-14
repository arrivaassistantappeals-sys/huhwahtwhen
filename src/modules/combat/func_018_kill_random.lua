-- Func #018: Kill Random | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillRandom", type = "button", name = "Kill Random",
    tooltip = "Kill a random player", tab = "Combat",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local hum = list[math.random(1, #list)].Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}