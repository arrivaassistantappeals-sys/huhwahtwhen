-- Func #064: Anti-Ragdoll | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local RAGDOLL_STATES = {
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll] = true
}

local State = { running = false, blocks = 0, connections = {} }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum.StateChanged:Connect(function(_, newState)
        if not State.running then return end
        if RAGDOLL_STATES[newState] then
            task.defer(function()
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end)
            State.blocks = State.blocks + 1
        end
    end)
    table.insert(State.connections, conn)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
end

local function loop()
    while State.running do
        task.wait(0.1)
        local hum = getHum()
        if hum then
            local st = hum:GetState()
            if RAGDOLL_STATES[st] then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                State.blocks = State.blocks + 1
            end
        end
    end
end

return {
    id = "AntiRagdoll", type = "toggle", name = "Anti-Ragdoll",
    tooltip = "Prevent ragdoll", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocks = 0
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
        local hum = getHum()
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end)
        end
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { blocks = State.blocks } end
}