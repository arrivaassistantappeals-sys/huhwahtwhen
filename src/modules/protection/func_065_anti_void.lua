-- Func #065: Anti-Void | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local State = {
    running = false,
    conn = nil,
    lastSafeCFrame = nil,
    recoveries = 0,
    lastRecovery = 0
}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function saveSafe(hrp)
    if hrp.Position.Y > 10 then
        State.lastSafeCFrame = hrp.CFrame
    end
end

local function recover(hrp)
    if tick() - State.lastRecovery < 1 then return end
    hrp.CFrame = State.lastSafeCFrame or CFrame.new(0, 50, 0)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    State.recoveries = State.recoveries + 1
    State.lastRecovery = tick()
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end
    local y = hrp.Position.Y
    if y > 10 then saveSafe(hrp) end
    if y < -30 then
        if hrp.AssemblyLinearVelocity.Y < -100 then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -50, hrp.AssemblyLinearVelocity.Z)
        end
    end
    if y < -100 then recover(hrp) end
end

return {
    id = "AntiVoid", type = "toggle", name = "Anti-Void",
    tooltip = "Automatically return after falling", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.recoveries = 0
        State.lastSafeCFrame = nil
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { recoveries = State.recoveries } end
}