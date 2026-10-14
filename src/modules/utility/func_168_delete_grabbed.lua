-- Func #168: Delete Grabbed | button
local Workspace = game:GetService("Workspace")

return {
    id = "DeleteGrabbed", type = "button", name = "Delete Grabbed",
    tooltip = "Remove GrabParts", tab = "Utility",
    onClick = function(Settings, Utils)
        local gp = Workspace:FindFirstChild("GrabParts")
        if gp then
            gp:Destroy()
            Utils.notify("Resonance", "GrabParts removed", Settings)
        end
    end
}