-- Func #005: Aimbot | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "Aimbot", type = "toggle", name = "Aimbot",
    tooltip = "Snap the camera onto a player", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAimbotConn = RunService.RenderStepped:Connect(function()
            if not Settings.Aimbot then return end
            local target = Utils.getClosestPlayer(Settings)
            if not target then return end
            local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
        end)
    end,
    onDisable = function()
        if _G.ResonanceAimbotConn then
            _G.ResonanceAimbotConn:Disconnect()
            _G.ResonanceAimbotConn = nil
        end
    end
}