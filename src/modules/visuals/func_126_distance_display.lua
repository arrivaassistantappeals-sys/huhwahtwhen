-- Func #126: Distance Display | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, labels = {} }

local function createLabel(player)
    if State.labels[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceDistance"
    bb.Size = UDim2.new(0, 100, 0, 30)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, -3, 0)
    bb.Adornee = hrp
    bb.Parent = hrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(0, 255, 100)
    label.TextStrokeTransparency = 0
    label.TextSize = 16
    label.Font = Enum.Font.GothamBold
    label.Parent = bb
    State.labels[player] = { gui = bb, label = label }
end

local function removeLabel(player)
    if State.labels[player] then
        pcall(function() State.labels[player].gui:Destroy() end)
        State.labels[player] = nil
    end
end

return {
    id = "DistanceDisplay", type = "toggle", name = "Distance Display",
    tooltip = "Distance to players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.labels = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeLabel(p)
                else
                    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if not State.labels[p] then createLabel(p) end
                        local entry = State.labels[p]
                        local myHRP = Utils.getHRP()
                        if entry and myHRP then
                            local dist = (p.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                            entry.label.Text = math.floor(dist) .. "m"
                        end
                    else
                        removeLabel(p)
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.labels) do removeLabel(p) end
        State.labels = {}
    end
}