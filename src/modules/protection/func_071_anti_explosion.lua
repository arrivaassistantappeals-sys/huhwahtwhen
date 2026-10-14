-- Func #071: Anti-Explosion | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, neutralized = 0 }
local DESTROY_RADIUS = 60

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function neutralize(explosion)
    pcall(function()
        explosion.BlastPressure = 0
        explosion.BlastRadius = 0
        explosion:Destroy()
    end)
    State.neutralized = State.neutralized + 1
end

local function scan()
    local hrp = getHRP(); if not hrp then return end
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Explosion") then
            if (obj.Position - hrp.Position).Magnitude < DESTROY_RADIUS then neutralize(obj) end
        end
    end
end

local function monitor()
    local conn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if obj:IsA("Explosion") then
            task.wait(0.02)
            local hrp = getHRP(); if not hrp then return end
            if (obj.Position - hrp.Position).Magnitude < DESTROY_RADIUS then neutralize(obj) end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(0.1)
        scan()
    end
end

return {
    id = "AntiExplosion", type = "toggle", name = "Anti-Explosion",
    tooltip = "Neutralize nearby explosions", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.neutralized = 0
        State.connections = {}
        monitor()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { neutralized = State.neutralized } end
}