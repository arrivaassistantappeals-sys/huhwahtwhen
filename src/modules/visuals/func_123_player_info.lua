-- Func #123: Player Info | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, tags = {} }

local function createTag(player)
    if State.tags[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceInfo"
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.Adornee = hrp
    bb.Parent = hrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Text = player.Name
    label.Parent = bb
    State.tags[player] = { gui = bb, label = label }
end

local function removeTag(player)
    if State.tags[player] then
        pcall(function() State.tags[player].gui:Destroy() end)
        State.tags[player] = nil
    end
end

return {
    id = "PlayerInfo", type = "toggle", name = "Player Info",
    tooltip = "Name, HP, and distance", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tags = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeTag(p)
                elseif Settings.ESPInfo then
                    if not p.Character then removeTag(p); continue end
                    if not State.tags[p] then createTag(p) end
                    local entry = State.tags[p]
                    if entry then
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local myHRP = Utils.getHRP()
                        local dist = (hrp and myHRP) and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
                        local hp = hum and math.floor(hum.Health) or 0
                        entry.label.Text = string.format("%s | %dHP | %dm", p.Name, hp, dist)
                    end
                else
                    removeTag(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.tags) do removeTag(p) end
        State.tags = {}
    end
}