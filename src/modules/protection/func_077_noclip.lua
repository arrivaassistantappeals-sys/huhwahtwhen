-- Func #077: Noclip | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, conn = nil, saved = {}, lastChar = nil }

local function saveCollide(char)
    State.saved = {}
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            State.saved[part] = part.CanCollide
        end
    end
end

local function restore()
    for part, state in pairs(State.saved) do
        if part and part.Parent then
            pcall(function() part.CanCollide = state end)
        end
    end
    State.saved = {}
end

local function onStep()
    if not State.running then return end
    local char = LocalPlayer.Character
    if not char then return end
    if char ~= State.lastChar then
        State.lastChar = char
        saveCollide(char)
    end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanCollide then
            part.CanCollide = false
        end
    end
end

return {
    id = "NoclipProt", type = "toggle", name = "Noclip",
    tooltip = "Walk through walls", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lastChar = nil
        State.conn = RunService.Stepped:Connect(onStep)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        restore()
    end
}