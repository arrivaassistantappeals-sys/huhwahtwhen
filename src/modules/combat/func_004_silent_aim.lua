-- Func #004: Silent Aim | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "SilentAim", type = "toggle", name = "Silent Aim",
    tooltip = "Smoothly aim the camera at the nearest player", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceSilentAimConn = RunService.RenderStepped:Connect(function()
            if not Settings.SilentAim then return end
            local target = Utils.getClosestPlayer(Settings)
            if not target then return end
            local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local myPos = Camera.CFrame.Position
            local lookDir = (hrp.Position - myPos).Unit
            local currentLook = Camera.CFrame.LookVector
            Camera.CFrame = CFrame.new(myPos, myPos + currentLook:Lerp(lookDir, 0.15))
        end)
    end,
    onDisable = function()
        if _G.ResonanceSilentAimConn then
            _G.ResonanceSilentAimConn:Disconnect()
            _G.ResonanceSilentAimConn = nil
        end
    end
}