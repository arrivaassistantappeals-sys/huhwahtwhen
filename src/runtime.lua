-- ============================================================
-- Resonance v4.0 — runtime.lua
-- Global handlers: RGB binding, Anti-AFK, auto respawn
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local Settings = _G.ResonanceSettings or {}
local RGB      = _G.ResonanceRGB
local Utils    = _G.ResonanceUtils

local function log(msg)
    print("[Resonance Runtime] " .. tostring(msg))
end

-- ============================================================
-- 1. RGB BIND
-- ============================================================
if RGB and RGB.bind then
    pcall(function()
        RGB.bind(Settings)
        log("RGB binding enabled")
    end)
end

-- ============================================================
-- 2. ANTI-AFK
-- ============================================================
local antiAfkConn = LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
log("Anti-AFK enabled")

-- ============================================================
-- 3. AUTO-REJOIN ON KICK
-- ============================================================
-- Monitor for a kick if the player disappears from Players
task.spawn(function()
    while true do
        task.wait(2)
        if Settings.AutoRejoin then
            if not Players:FindFirstChild(LocalPlayer.Name) then
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
                break
            end
        end
    end
end)

-- ============================================================
-- 4. ON TELEPORT LOG
-- ============================================================
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        log("Teleport started")
    elseif state == Enum.TeleportState.Failed then
        log("Teleport failed")
    end
end)

-- ============================================================
-- 5. CHARACTER ADDED HOOK
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    log("Character respawned")

    -- Automatically apply movement settings
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if Settings.WalkSpeed then hum.WalkSpeed = Settings.WalkSpeed end
        if Settings.JumpPower then hum.JumpPower = Settings.JumpPower end
    end
end)

-- ============================================================
-- 6. WATCHDOG FPS/PING (optional)
-- ============================================================
if Settings.PingDisplay or Settings.FPSDisplay then
    task.spawn(function()
        while true do
            task.wait(5)
            if Settings.PingDisplay then
                local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                log("Ping: " .. ping .. " ms")
            end
            if Settings.FPSDisplay then
                local fps = math.floor(1 / RunService.RenderStepped:Wait())
                log("FPS: " .. fps)
            end
        end
    end)
end

-- ============================================================
-- 7. GLOBAL API FOR OTHER MODULES
-- ============================================================
_G.ResonanceRuntime = {
    log = log,
    antiAfkConn = antiAfkConn
}

log("Runtime fully loaded")