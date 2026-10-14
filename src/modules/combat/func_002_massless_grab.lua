-- Func #002: Massless Grab | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "MasslessGrab", type = "toggle", name = "Massless Grab",
    tooltip = "Make held objects weightless", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceMasslessConn = Workspace.ChildAdded:Connect(function(child)
            if not Settings.MasslessGrab then return end
            if child.Name ~= "GrabParts" then return end
            task.wait(0.1)
            for _, obj in pairs(child:GetDescendants()) do
                if obj:IsA("BasePart") then obj.Massless = true end
            end
        end)
    end,
    onDisable = function()
        if _G.ResonanceMasslessConn then
            _G.ResonanceMasslessConn:Disconnect()
            _G.ResonanceMasslessConn = nil
        end
    end
}