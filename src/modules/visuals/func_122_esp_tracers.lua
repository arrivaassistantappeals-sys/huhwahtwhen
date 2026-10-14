-- Func #122: ESP Tracers | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, tracers = {} }

local function createTracer(player)
    if State.tracers[player] then return end
    local line = Instance.new("LineHandleAdornment")
    line.Thickness = 2
    line.Color3 = Color3.fromRGB(255, 0, 0)
    line.AlwaysOnTop = true
    line.ZIndex = 5
    line.Parent = Workspace
    State.tracers[player] = line
end

local function removeTracer(player)
    if State.tracers[player] then
        pcall(function() State.tracers[player]:Destroy() end)
        State.tracers[player] = nil
    end
end

return {
    id = "ESPTracers", type = "toggle", name = "ESP Tracers",
    tooltip = "Lines to players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tracers = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeTracer(p)
                elseif Settings.ESPTracers then
                    if not p.Character then removeTracer(p); continue end
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then removeTracer(p); continue end
                    if not State.tracers[p] then createTracer(p) end
                    local tracer = State.tracers[p]
                    if tracer then
                        tracer.Adornee = hrp
                        tracer.Length = 0
                        tracer.CFrame = CFrame.new(
                            Camera.CFrame.Position,
                            hrp.Position)
                    end
                else
                    removeTracer(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.tracers) do removeTracer(p) end
        State.tracers = {}
    end
}