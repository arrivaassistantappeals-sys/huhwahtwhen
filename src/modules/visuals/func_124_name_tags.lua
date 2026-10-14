-- Func #124: Name Tags | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, tags = {} }

return {
    id = "NameTags", type = "toggle", name = "Name Tags",
    tooltip = "Large names above players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tags = {}
        task.spawn(function()
            while State.running do
                task.wait(1)
                for _, p in pairs(Players:GetPlayers()) do
                    if p == LocalPlayer then continue end
                    if p.Character then
                        local head = p.Character:FindFirstChild("Head")
                        if head and not State.tags[p] then
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "ResonanceNameTag"
                            bb.Size = UDim2.new(0, 200, 0, 50)
                            bb.AlwaysOnTop = true
                            bb.StudsOffset = Vector3.new(0, 2, 0)
                            bb.Adornee = head
                            bb.Parent = head
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextColor3 = Color3.fromRGB(255, 200, 0)
                            label.TextStrokeTransparency = 0
                            label.TextScaled = true
                            label.Font = Enum.Font.GothamBold
                            label.Text = p.Name
                            label.Parent = bb
                            State.tags[p] = bb
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, tag in pairs(State.tags) do pcall(function() tag:Destroy() end) end
        State.tags = {}
    end
}