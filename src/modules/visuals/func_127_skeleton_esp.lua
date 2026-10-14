-- Func #127: Skeleton ESP | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, lines = {} }

local BONES = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function createLine(player)
    local lines = {}
    for i = 1, #BONES do
        local line = Instance.new("LineHandleAdornment")
        line.Thickness = 2
        line.Color3 = Color3.fromRGB(0, 255, 255)
        line.AlwaysOnTop = true
        line.Parent = Workspace
        table.insert(lines, line)
    end
    State.lines[player] = lines
end

local function removeLine(player)
    if State.lines[player] then
        for _, l in ipairs(State.lines[player]) do
            pcall(function() l:Destroy() end)
        end
        State.lines[player] = nil
    end
end

return {
    id = "SkeletonESP", type = "toggle", name = "Skeleton ESP",
    tooltip = "Player skeletons", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lines = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeLine(p)
                else
                    if not p.Character then removeLine(p); continue end
                    if not State.lines[p] then createLine(p) end
                    local lines = State.lines[p]
                    for i, pair in ipairs(BONES) do
                        local a = p.Character:FindFirstChild(pair[1])
                        local b = p.Character:FindFirstChild(pair[2])
                        if a and b and lines[i] then
                            lines[i].Adornee = a
                            lines[i].CFrame = CFrame.new(a.Position, b.Position)
                            lines[i].Length = (a.Position - b.Position).Magnitude
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.lines) do removeLine(p) end
        State.lines = {}
    end
}