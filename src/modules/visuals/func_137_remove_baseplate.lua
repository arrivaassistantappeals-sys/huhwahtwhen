-- Func #137: Remove Baseplate | button
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveBaseplate", type = "button", name = "Remove Baseplate",
    tooltip = "Remove Baseplate", tab = "Visuals",
    onClick = function(Settings, Utils)
        local bp = Workspace:FindFirstChild("Baseplate")
        if bp then
            bp:Destroy()
            Utils.notify("Resonance", "Baseplate removed", Settings)
        end
    end
}