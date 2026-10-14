-- Func #087: View Target | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "ViewTarget", type = "toggle", name = "View Target",
    tooltip = "Spectate the target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            local name = Settings.TargetName or Settings.TargetPlayerName
            if not name or name == "" then return end
            local target = Players:FindFirstChild(name)
            if not target or not target.Character then return end
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}