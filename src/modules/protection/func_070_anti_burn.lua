-- Func #070: Anti-Burn | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PARTICLE_WHITELIST = {
    ["Fire"] = true, ["Smoke"] = true, ["Sparkles"] = true,
    ["ParticleEmitter"] = true, ["Trail"] = true, ["Beam"] = true,
    ["PointLight"] = true, ["SpotLight"] = true, ["SurfaceLight"] = true
}

local State = { running = false, connections = {}, cleared = 0 }

local function getChar() return LocalPlayer.Character end

local function shouldClear(obj)
    return PARTICLE_WHITELIST[obj.ClassName] == true
end

local function clearEffects(char)
    if not char then return end
    for _, obj in pairs(char:GetDescendants()) do
        if shouldClear(obj) then
            pcall(function() obj:Destroy() end)
            State.cleared = State.cleared + 1
        end
    end
end

local function bindChar(char)
    if not char then return end
    local conn = char.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if shouldClear(obj) then
            task.wait(0.05)
            if obj.Parent then
                pcall(function() obj:Destroy() end)
                State.cleared = State.cleared + 1
            end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(0.2)
        clearEffects(getChar())
    end
end

return {
    id = "AntiBurn", type = "toggle", name = "Anti-Burn",
    tooltip = "Remove fire and effects from your character", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.cleared = 0
        State.connections = {}
        bindChar(getChar())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindChar(c)
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { cleared = State.cleared } end
}