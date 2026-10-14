-- Func #103: Fly | toggle
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera

local bv, bg

return {
    id = "Fly", type = "toggle", name = "Fly",
    tooltip = "Fly (WASD + Space/LCTRL)", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end

        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp

        bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 1000
        bg.D = 50
        bg.Parent = hrp

        _G.ResonanceFlyConn = RunService.RenderStepped:Connect(function()
            if not Settings.Fly then return end
            local char = Utils.getChar()
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root or not bv then return end
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            bv.Velocity = moveDir * (Settings.FlySpeed or 50)
            bg.CFrame = Camera.CFrame
        end)
    end,
    onDisable = function()
        if bv then bv:Destroy(); bv = nil end
        if bg then bg:Destroy(); bg = nil end
        if _G.ResonanceFlyConn then
            _G.ResonanceFlyConn:Disconnect()
            _G.ResonanceFlyConn = nil
        end
    end
}