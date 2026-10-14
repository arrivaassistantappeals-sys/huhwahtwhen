-- ============================================================
-- Resonance v4.0 — core/utils.lua
-- Utilities: character, players, filters, physics, notifications
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local Debris           = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Utils = {}

-- ---------- CHARACTER ----------
function Utils.getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Utils.getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Utils.getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Utils.getAnimator()
    local c = LocalPlayer.Character
    if not c then return nil end
    return c:FindFirstChildOfClass("Animator")
        or (c:FindFirstChildOfClass("Humanoid") and c.Humanoid:FindFirstChildOfClass("Animator"))
end

-- ---------- PLAYERS ----------
function Utils.getAllPlayers(includeSelf)
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if (includeSelf or p ~= LocalPlayer) and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then table.insert(list, p) end
        end
    end
    return list
end

function Utils.getClosestPlayer(Settings)
    local myHRP = Utils.getHRP()
    if not myHRP then return nil end
    local best, dist = nil, math.huge
    for _, p in pairs(Utils.getAllPlayers(false)) do
        if not Utils.isWhitelisted(p, Settings) then
            local hrp = p.Character.HumanoidRootPart
            local d = (hrp.Position - myHRP.Position).Magnitude
            if d < dist then dist, best = d, p end
        end
    end
    return best, dist
end

function Utils.getFarthestPlayer(Settings)
    local myHRP = Utils.getHRP()
    if not myHRP then return nil end
    local best, dist = nil, -1
    for _, p in pairs(Utils.getAllPlayers(false)) do
        if not Utils.isWhitelisted(p, Settings) then
            local hrp = p.Character.HumanoidRootPart
            local d = (hrp.Position - myHRP.Position).Magnitude
            if d > dist then dist, best = d, p end
        end
    end
    return best, dist
end

function Utils.getPlayerByName(name)
    if not name or name == "" then return nil end
    return Players:FindFirstChild(name)
end

-- ---------- FILTERS ----------
function Utils.isWhitelisted(player, Settings)
    if not player then return true end
    if player == LocalPlayer then return true end
    if Settings and Settings.WhitelistFriends then
        local ok, isFriend = pcall(function()
            return LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if ok and isFriend then return true end
    end
    return false
end

function Utils.passesTeamCheck(player, Settings)
    if not Settings or not Settings.ESPTeamCheck then return true end
    return player.Team ~= LocalPlayer.Team
end

-- ---------- GEOMETRY ----------
function Utils.distanceTo(target)
    local myHRP = Utils.getHRP()
    if not myHRP or not target then return math.huge end
    local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return math.huge end
    return (hrp.Position - myHRP.Position).Magnitude
end

function Utils.isInRange(target, range)
    return Utils.distanceTo(target) <= range
end

-- ---------- PHYSICS ----------
function Utils.fling(hrpTarget, power)
    if not hrpTarget then return end
    power = power or 300
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(
        math.random(-power, power),
        power,
        math.random(-power, power)
    )
    bv.Parent = hrpTarget
    Debris:AddItem(bv, 0.25)
end

function Utils.teleportTo(cf)
    local hrp = Utils.getHRP()
    if hrp and cf then
        if _G.ResonanceAllowTeleport then _G.ResonanceAllowTeleport(1.0) end
        hrp.CFrame = cf
    end
end

-- ---------- NOTIFICATIONS ----------
function Utils.notify(title, text, Settings)
    if Settings and Settings.Notifications == false then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Resonance",
            Text = text or "",
            Duration = 3
        })
    end)
end

-- ---------- MOUSE ----------
function Utils.getMouseTarget()
    local mouse = LocalPlayer:GetMouse()
    if not mouse then return nil, nil end
    return mouse.Target, mouse.Hit
end

-- ---------- METRICS ----------
function Utils.getPing()
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    return ok and math.floor(ping * 1000) or 0
end

function Utils.getFPS()
    return math.floor(1 / RunService.RenderStepped:Wait())
end

function Utils.wait(seconds)
    task.wait(seconds or 0.1)
end

-- ---------- CONSISTENT KEYS ----------
function Utils.isKeyDown(key)
    return UserInputService:IsKeyDown(key)
end

return Utils