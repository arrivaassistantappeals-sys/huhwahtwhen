-- Func #138: Remove Lights | button
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveLights", type = "button", name = "Remove Lights",
    tooltip = "Remove all light sources", tab = "Visuals",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Light") then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        Utils.notify("Resonance", "Lights removed: " .. count, Settings)
    end
}