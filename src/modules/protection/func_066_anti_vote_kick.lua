-- Func #066: Anti-Vote Kick | toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local VOTE_KEYWORDS = {"vote","kick","ban","votekick"}
local State = { running = false, connections = {}, blocked = 0, destroyed = 0, hookRef = nil, remotes = {} }

local function matchKeywords(name)
    local l = name:lower()
    for _, kw in ipairs(VOTE_KEYWORDS) do if l:find(kw) then return true end end
    return false
end

local function blockReset()
    pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
end

local function scanRemotes()
    State.remotes = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name) then table.insert(State.remotes, obj) end
        end
    end
end

local function installHook()
    if not hookmetamethod or not getnamecallmethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        local m = getnamecallmethod()
        if m == "FireServer" or m == "InvokeServer" then
            for _, r in ipairs(State.remotes) do
                if self == r then
                    for _, a in ipairs({...}) do
                        if typeof(a) == "Instance" and (a == LocalPlayer or a == LocalPlayer.Character) then
                            State.blocked = State.blocked + 1
                            return nil
                        elseif type(a) == "string" and a:lower() == LocalPlayer.Name:lower() then
                            State.blocked = State.blocked + 1
                            return nil
                        end
                    end
                    break
                end
            end
        end
        return old(self, ...)
    end)
    State.hookRef = old
end

local function monitorUI()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    table.insert(State.connections, pg.ChildAdded:Connect(function(gui)
        if not State.running then return end
        if matchKeywords(gui.Name) then
            task.wait(0.05)
            pcall(function() gui:Destroy() end)
            State.destroyed = State.destroyed + 1
        end
    end))
end

local function loop()
    while State.running do
        task.wait(2)
        scanRemotes()
        blockReset()
    end
end

return {
    id = "AntiVoteKick", type = "toggle", name = "Anti-Vote Kick",
    tooltip = "Block votes against you", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.destroyed = 0
        State.connections = {}
        blockReset()
        scanRemotes()
        installHook()
        monitorUI()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
        State.hookRef = nil
        pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
    end,
    getStats = function() return { blocked = State.blocked, destroyed = State.destroyed } end
}