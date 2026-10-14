-- Func #061: Anti-Grab | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local BODY_MOVERS = {
    BodyVelocity=true, BodyPosition=true, BodyGyro=true, BodyAngularVelocity=true,
    BodyForce=true, BodyThrust=true, BodyTorque=true, RocketPropulsion=true,
    VectorForce=true, LinearVelocity=true, AngularVelocity=true,
    AlignPosition=true, AlignOrientation=true, Torque=true
}
local CONSTRAINTS = { WeldConstraint=true, Weld=true, ManualWeld=true, Motor6D=true, Snap=true }
local GRAB_KEYWORDS = {"grab","hold","carry","lift","pickup","fling","throw"}

local State = {
    running = false,
    connections = {},
    grabAttempts = 0,
    weldsRemoved = 0,
    bodyMoversRemoved = 0
}

local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function isOwn(inst)
    if not inst then return false end
    local ok, v = pcall(function() return inst:GetAttribute("ResonanceOwn") end)
    return ok and v == true
end
local function isBodyMover(inst) return BODY_MOVERS[inst.ClassName] == true end
local function isConstraint(inst) return CONSTRAINTS[inst.ClassName] == true end

local function cleanBodyMovers(hrp)
    local n = 0
    for _, o in pairs(hrp:GetChildren()) do
        if isBodyMover(o) and not isOwn(o) then
            if pcall(function() o:Destroy() end) then
                n = n + 1
                State.bodyMoversRemoved = State.bodyMoversRemoved + 1
            end
        end
    end
    return n
end

local function cleanWelds(hrp)
    local n = 0
    local myChar = getChar()
    for _, o in pairs(hrp:GetChildren()) do
        if isConstraint(o) and not isOwn(o) then
            local p0, p1
            if o:IsA("WeldConstraint") then p0 = o.Part0; p1 = o.Part1 end
            local ext = false
            if p0 and not p0:IsDescendantOf(myChar) then ext = true end
            if p1 and not p1:IsDescendantOf(myChar) then ext = true end
            if ext then
                pcall(function() o:Destroy() end)
                n = n + 1
                State.weldsRemoved = State.weldsRemoved + 1
            end
        end
    end
    return n
end

local function detectVelocity(hrp)
    local v = hrp.AssemblyLinearVelocity
    if v.Magnitude > 100 then
        local vy = v.Y
        if math.abs(vy) < 200 then
            hrp.AssemblyLinearVelocity = Vector3.new(0, vy * 0.3, 0)
        else
            hrp.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
        end
        State.grabAttempts = State.grabAttempts + 1
    end
end

local function detectAngular(hrp)
    if hrp.AssemblyAngularVelocity.Magnitude > 30 then
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        State.grabAttempts = State.grabAttempts + 1
    end
end

local function loop()
    while State.running do
        task.wait(0.05)
        local hrp = getHRP()
        if not hrp then continue end
        cleanBodyMovers(hrp)
        cleanWelds(hrp)
        detectVelocity(hrp)
        detectAngular(hrp)
    end
end

return {
    id = "AntiGrab", type = "toggle", name = "Anti-Grab",
    tooltip = "Layered grab protection", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.grabAttempts = 0
        State.weldsRemoved = 0
        State.bodyMoversRemoved = 0
        State.connections = {}
        task.spawn(loop)
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
        end))
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function()
        return { grabAttempts = State.grabAttempts, weldsRemoved = State.weldsRemoved, bodyMoversRemoved = State.bodyMoversRemoved }
    end
}