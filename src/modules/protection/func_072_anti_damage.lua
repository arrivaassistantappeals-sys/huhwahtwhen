-- Func #072: Anti-Damage | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, heals = 0, damagesBlocked = 0, hookRef = nil }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not State.running then return end
        if hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
            State.heals = State.heals + 1
        end
    end)
    table.insert(State.connections, conn)
end

local function installHook()
    if not hookmetamethod or not getnamecallmethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        if getnamecallmethod() == "TakeDamage" and self == getHum() then
            State.damagesBlocked = State.damagesBlocked + 1
            return nil
        end
        return old(self, ...)
    end)
    State.hookRef = old
end

local function loop()
    while State.running do
        task.wait(0.1)
        local hum = getHum()
        if hum and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
            State.heals = State.heals + 1
        end
    end
end

return {
    id = "AntiDamage", type = "toggle", name = "Anti-Damage",
    tooltip = "Prevent damage", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.heals = 0
        State.damagesBlocked = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        installHook()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        State.hookRef = nil
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { heals = State.heals, damagesBlocked = State.damagesBlocked } end
}