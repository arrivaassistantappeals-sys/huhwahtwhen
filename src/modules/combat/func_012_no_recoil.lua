-- Func #012: No Recoil | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "NoRecoil", type = "toggle", name = "No Recoil",
    tooltip = "Remove camera recoil", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceNoRecoilConn = RunService.RenderStepped:Connect(function()
            if not Settings.NoRecoil then return end
            local rot = Camera.CFrame - Camera.CFrame.Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position) * rot
        end)
    end,
    onDisable = function()
        if _G.ResonanceNoRecoilConn then
            _G.ResonanceNoRecoilConn:Disconnect()
            _G.ResonanceNoRecoilConn = nil
        end
    end
}