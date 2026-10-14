-- Func #079: God Mode | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, heals = 0, connections = {} }
local MAX_HP = 1000000

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function applyGod(hum)
    if not hum then return end
    pcall(function()
        hum.MaxHealth = MAX_HP
        if hum.Health < MAX_HP then
            hum.Health = MAX_HP
            State.heals = State.heals + 1
        end
        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
    end)
end

local function loop()
    while State.running do
        task.wait(0.1)
        applyGod(getHum())
    end
end

return {
    id = "GodMode", type = "toggle", name = "God Mode",
    tooltip = "Invincibility", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.heals = 0
        State.connections = {}
        applyGod(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            applyGod(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        local hum = getHum()
        if hum then
            pcall(function()
                hum.MaxHealth = 100
                hum.Health = 100
                hum.NameDisplayDistance = 100
                hum.HealthDisplayDistance = 100
            end)
        end
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { heals = State.heals } end
}