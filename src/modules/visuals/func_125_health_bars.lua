-- Func #125: Health Bars | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, bars = {} }

local function createBar(player)
    if State.bars[player] then return end
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceHealthBar"
    bb.Size = UDim2.new(0, 100, 0, 10)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Adornee = head
    bb.Parent = head
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bg.BorderSizePixel = 0
    bg.Parent = bb
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bg
    State.bars[player] = { bg = bg, fill = fill }
end

local function removeBar(player)
    if State.bars[player] then
        pcall(function() State.bars[player].bg.Parent:Destroy() end)
        State.bars[player] = nil
    end
end

return {
    id = "HealthBars", type = "toggle", name = "Health Bars",
    tooltip = "HP bars above players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.bars = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeBar(p)
                else
                    if p.Character and p.Character:FindFirstChild("Head") then
                        if not State.bars[p] then createBar(p) end
                        local entry = State.bars[p]
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if entry and hum then
                            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            entry.fill.Size = UDim2.new(pct, 0, 1, 0)
                            entry.fill.BackgroundColor3 = Color3.fromRGB(
                                math.floor(255 * (1 - pct)),
                                math.floor(255 * pct),
                                0)
                        end
                    else
                        removeBar(p)
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.bars) do removeBar(p) end
        State.bars = {}
    end
}