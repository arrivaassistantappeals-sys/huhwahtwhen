-- Func #007: Auto Throw | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "AutoThrow", type = "toggle", name = "Auto Throw",
    tooltip = "Automatically release the grabbed object", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAutoThrowConn = Workspace.ChildAdded:Connect(function(model)
            if not Settings.AutoThrow then return end
            if model.Name ~= "GrabParts" then return end
            task.wait(0.3)
            local grab = model:FindFirstChild("GrabPart")
            if grab then pcall(function() grab:Destroy() end) end
        end)
    end,
    onDisable = function()
        if _G.ResonanceAutoThrowConn then
            _G.ResonanceAutoThrowConn:Disconnect()
            _G.ResonanceAutoThrowConn = nil
        end
    end
}