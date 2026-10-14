-- Func #068: Anti-Teleport | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local State = {
    running = false,
    conn = nil,
    lastPos = nil,
    lastCFrame = nil,
    allowedUntil = 0,
    graceUntil = 0,
    reversals = 0
}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isMoving()
    return UserInputService:IsKeyDown(Enum.KeyCode.W)
        or UserInputService:IsKeyDown(Enum.KeyCode.A)
        or UserInputService:IsKeyDown(Enum.KeyCode.S)
        or UserInputService:IsKeyDown(Enum.KeyCode.D)
        or UserInputService:IsKeyDown(Enum.KeyCode.Space)
end

local function allowTeleport(duration)
    State.allowedUntil = tick() + (duration or 1)
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end

    local pos = hrp.Position
    local t = tick()

    if t < State.allowedUntil then
        State.lastPos = pos
        State.lastCFrame = hrp.CFrame
        return
    end

    if State.lastPos then
        local delta = (pos - State.lastPos).Magnitude
        if delta > 30 and t > State.graceUntil and not isMoving() then
            if State.lastCFrame then
                hrp.CFrame = State.lastCFrame
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                State.reversals = State.reversals + 1
                State.graceUntil = t + 0.3
            end
        else
            State.lastPos = pos
            State.lastCFrame = hrp.CFrame
        end
    else
        State.lastPos = pos
        State.lastCFrame = hrp.CFrame
    end
end

return {
    id = "AntiTeleport", type = "toggle", name = "Anti-Teleport",
    tooltip = "Detect and reverse external teleports", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lastPos = nil
        State.lastCFrame = nil
        State.reversals = 0
        State.allowedUntil = 0
        State.graceUntil = 0
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
        _G.ResonanceAllowTeleport = allowTeleport
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        _G.ResonanceAllowTeleport = nil
    end,
    getStats = function() return { reversals = State.reversals } end,
    allowTeleport = allowTeleport
}