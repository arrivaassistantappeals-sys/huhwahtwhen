-- Func #063: Anti-Freeze | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, unfreezes = 0, anchorRestores = 0 }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.1)
        local char = getChar(); if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end

        if hrp.Anchored then hrp.Anchored = false; State.anchorRestores = State.anchorRestores + 1 end
        if hum.PlatformStand then hum.PlatformStand = false; State.unfreezes = State.unfreezes + 1 end
        if hum.Sit then hum.Sit = false; hum.Jump = true; State.unfreezes = State.unfreezes + 1 end
        if hum.WalkSpeed < 16 and hum.WalkSpeed > 0 then hum.WalkSpeed = 16 end
        if hum.WalkSpeed == 0 then hum.WalkSpeed = 16 end
        if hum.JumpPower < 50 and hum.JumpPower > 0 then hum.JumpPower = 50 end
    end
end

return {
    id = "AntiFreeze", type = "toggle", name = "Anti-Freeze",
    tooltip = "Protection against freezing", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.unfreezes = 0
        State.anchorRestores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function()
        return { unfreezes = State.unfreezes, anchorRestores = State.anchorRestores }
    end
}