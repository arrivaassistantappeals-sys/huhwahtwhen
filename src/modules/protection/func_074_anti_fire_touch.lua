-- Func #074: Anti-Fire Touch | toggle
local Workspace = game:GetService("Workspace")

local FIRE_KEYWORDS = {"fire","flame","lava","burn","torch"}
local State = { running = false, connections = {}, disabled = 0 }

local function isFirePart(part)
    if not part:IsA("BasePart") then return false end
    local lower = part.Name:lower()
    for _, kw in ipairs(FIRE_KEYWORDS) do if lower:find(kw) then return true end end
    return false
end

local function disableTouch(part)
    if part.CanTouch then
        part.CanTouch = false
        State.disabled = State.disabled + 1
    end
end

local function scan()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if isFirePart(obj) then disableTouch(obj) end
    end
end

local function monitor()
    local conn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if isFirePart(obj) then
            task.wait(0.05)
            if obj.Parent then disableTouch(obj) end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(1)
        scan()
    end
end

return {
    id = "AntiFireTouch", type = "toggle", name = "Anti-Fire Touch",
    tooltip = "Prevent fire from touching you", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.disabled = 0
        State.connections = {}
        scan()
        monitor()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { disabled = State.disabled } end
}