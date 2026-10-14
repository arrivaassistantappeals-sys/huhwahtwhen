-- Func #067: Anti-Kick | toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}
local State = { running = false, hooks = {}, connections = {}, blocked = 0, remotes = {} }

local function matchKeywords(name)
    local l = name:lower()
    for _, kw in ipairs(KICK_KEYWORDS) do if l:find(kw) then return true end end
    return false
end

local function isKickRemote(obj)
    if not (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return false end
    return matchKeywords(obj.Name)
end

local function installNamecallHook()
    if not hookmetamethod or not getnamecallmethod then return false end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        local m = getnamecallmethod()
        if m == "Kick" then
            State.blocked = State.blocked + 1
            return nil
        end
        if m == "FireServer" or m == "InvokeServer" then
            for _, a in ipairs({...}) do
                if type(a) == "string" then
                    local lower = a:lower()
                    if lower:find("kick") or lower:find("ban") or lower:find("remove") then
                        State.blocked = State.blocked + 1
                        return nil
                    end
                end
            end
        end
        return old(self, ...)
    end)
    table.insert(State.hooks, old)
    return true
end

local function installIndexHook()
    if not hookmetamethod then return end
    local old
    old = hookmetamethod(game, "__index", function(self, key)
        if not State.running then return old(self, key) end
        if key == "Kick" or key == "Ban" then return function() end end
        return old(self, key)
    end)
    table.insert(State.hooks, old)
end

local function scanRemotes()
    State.remotes = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if isKickRemote(obj) then table.insert(State.remotes, obj) end
    end
end

local function monitorNewRemotes()
    local conn = ReplicatedStorage.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if isKickRemote(obj) then table.insert(State.remotes, obj) end
    end)
    table.insert(State.connections, conn)
end

local function blockReset()
    pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
    task.spawn(function()
        while State.running do
            task.wait(1)
            pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
        end
    end)
end

return {
    id = "AntiKick", type = "toggle", name = "Anti-Kick",
    tooltip = "Layered kick protection", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.hooks = {}
        State.connections = {}
        installNamecallHook()
        installIndexHook()
        scanRemotes()
        monitorNewRemotes()
        blockReset()
    end,
    onDisable = function()
        State.running = false
        for _, h in ipairs(State.hooks) do
            if type(h) == "userdata" and h.Disconnect then pcall(function() h:Disconnect() end) end
        end
        State.hooks = {}
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { blocked = State.blocked } end
}