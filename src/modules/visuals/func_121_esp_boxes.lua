-- Func #121: ESP Boxes | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, boxes = {} }

local function createBox(player)
    if player == LocalPlayer or State.boxes[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Size = Vector3.new(4, 6, 2)
    box.Adornee = hrp
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.5
    box.Color3 = Color3.fromRGB(255, 0, 0)
    box.Parent = hrp
    State.boxes[player] = box
end

local function removeBox(player)
    if State.boxes[player] then
        pcall(function() State.boxes[player]:Destroy() end)
        State.boxes[player] = nil
    end
end

return {
    id = "ESPBoxes", type = "toggle", name = "ESP Boxes",
    tooltip = "Boxes around players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.boxes = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeBox(p)
                elseif Settings.ESPBoxes then
                    createBox(p)
                else
                    removeBox(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.boxes) do removeBox(p) end
        State.boxes = {}
    end
}