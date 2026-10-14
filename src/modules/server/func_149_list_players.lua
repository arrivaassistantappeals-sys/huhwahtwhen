-- Func #149: List Players | button
local Players = game:GetService("Players")

return {
    id = "ListPlayers", type = "button", name = "List Players",
    tooltip = "Print the player list to the console", tab = "Server",
    onClick = function(Settings, Utils)
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(names, p.Name .. " (ID: " .. p.UserId .. ")")
        end
        print("[Resonance] Players:")
        for _, n in ipairs(names) do print("  " .. n) end
        Utils.notify("Resonance", "Player list printed to the console", Settings)
    end
}