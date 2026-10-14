-- Func #062: Anti-Fling | toggle
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, conn = nil, blocked = 0 }
local MAX_VEL = 120
local MAX_ANG = 40

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function stabilize(hrp, hard)
    if hard then
        hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y * 0.1, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = CFrame.new(hrp.Position)
    else
        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * 0.4
        hrp.AssemblyAngularVelocity = hrp.AssemblyAngularVelocity * 0.4
    end
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end

    local v = hrp.AssemblyLinearVelocity.Magnitude
    local a = hrp.AssemblyAngularVelocity.Magnitude

    if v > MAX_VEL or a > MAX_ANG then
        State.blocked = State.blocked + 1
        stabilize(hrp, v > MAX_VEL * 2)
        for _, o in pairs(hrp:GetChildren()) do
            if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity") or o:IsA("BodyGyro") then
                if not o:GetAttribute("ResonanceOwn") then
                    pcall(function() o:Destroy() end)
                end
            end
        end
    end
end

return {
    id = "AntiFling", type = "toggle", name = "Anti-Fling",
    tooltip = "Protection against flinging", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { blocked = State.blocked } end
}