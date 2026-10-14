-- Func #180: Wipe Cache | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return {
    id = "WipeCache", type = "button", name = "Wipe Cache",
    tooltip = "Clear ESP/UI cache", tab = "Utility",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name:find("ResonanceESP") or obj.Name:find("ResonanceBlind") then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        for _, p in pairs(Players:GetPlayers()) do
            local pg = p:FindFirstChild("PlayerGui")
            if pg then
                local blind = pg:FindFirstChild("ResonanceBlind")
                if blind then blind:Destroy(); count = count + 1 end
            end
        end
        Utils.notify("Resonance", "Cleared: " .. count, Settings)
    end
}