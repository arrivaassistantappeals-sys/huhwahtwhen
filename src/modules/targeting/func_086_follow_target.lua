-- Func #086: Follow Target | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "FollowTarget", type = "toggle", name = "Follow Target",
    tooltip = "Follow the target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function()
            if not State.running then return end
            local name = Settings.TargetName or Settings.TargetPlayerName
            if not name or name == "" then return end
            local target = Players:FindFirstChild(name)
            if not target or not target.Character then return end
            local thrp = target.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = Utils.getHRP()
            if thrp and myHRP then
                local dir = (thrp.Position - myHRP.Position).Unit
                myHRP.CFrame = CFrame.new(myHRP.Position, myHRP.Position + dir)
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}