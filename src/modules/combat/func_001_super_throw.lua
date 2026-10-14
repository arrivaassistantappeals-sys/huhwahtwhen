-- Func #001: Super Throw | toggle

local Workspace = game:GetService("Workspace")
local Debris    = game:GetService("Debris")
local Camera    = Workspace.CurrentCamera

return {
    id = "SuperThrow", type = "toggle", name = "Super Throw",
    tooltip = "Stronger object throws", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceSuperThrowConn = Workspace.ChildAdded:Connect(function(model)
            if not Settings.SuperThrow then return end
            if model.Name ~= "GrabParts" then return end
            local grab = model:FindFirstChild("GrabPart")
            if not grab then return end
            local weld = grab:FindFirstChild("WeldConstraint")
            if not weld or not weld.Part1 then return end
            local part = weld.Part1
            local bv = Instance.new("BodyVelocity", part)
            model:GetPropertyChangedSignal("Parent"):Connect(function()
                if not model.Parent then
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Camera.CFrame.LookVector * (Settings.FlingPower or 350) * (Settings.ThrowPowerMult or 1)
                    Debris:AddItem(bv, 0.5)
                end
            end)
        end)
    end,
    onDisable = function()
        if _G.ResonanceSuperThrowConn then
            _G.ResonanceSuperThrowConn:Disconnect()
            _G.ResonanceSuperThrowConn = nil
        end
    end
}