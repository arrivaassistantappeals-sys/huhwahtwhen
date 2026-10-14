-- Func #069: Anti-Sit | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, sitBlocked = 0, weldsRemoved = 0 }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function cleanSeatWelds(char)
    if not char then return end
    for _, obj in pairs(char:GetChildren()) do
        if obj:IsA("Weld") and obj.Name == "SeatWeld" then
            pcall(function() obj:Destroy() end)
            State.weldsRemoved = State.weldsRemoved + 1
        end
    end
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum:GetPropertyChangedSignal("Sit"):Connect(function()
        if not State.running then return end
        if hum.Sit then
            hum.Sit = false
            hum.Jump = true
            State.sitBlocked = State.sitBlocked + 1
        end
    end)
    table.insert(State.connections, conn)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Sitting, false) end)
end

local function loop()
    while State.running do
        task.wait(0.05)
        local char = getChar(); if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Sit then
            hum.Sit = false
            hum.Jump = true
            State.sitBlocked = State.sitBlocked + 1
        end
        cleanSeatWelds(char)
    end
end

return {
    id = "AntiSit", type = "toggle", name = "Anti-Sit",
    tooltip = "Prevent being seated", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.sitBlocked = 0
        State.weldsRemoved = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
        local hum = getHum()
        if hum then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Sitting, true) end)
        end
    end,
    getStats = function() return { sitBlocked = State.sitBlocked, weldsRemoved = State.weldsRemoved } end
}