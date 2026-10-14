-- Func #014: Fling Random | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingRandom", type = "button", name = "Fling Random",
    tooltip = "Fling a random player", tab = "Combat",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 300) end
    end
}