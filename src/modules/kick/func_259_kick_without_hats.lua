-- Func #259: Kick Without Hats
-- Category: Kick | Type: button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

local function findKickRemote()
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name, KICK_KEYWORDS) then return obj end
        end
    end
    return nil
end

local function fireKick(target, reason)
    local remote = findKickRemote()
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(target, reason or "Resonance")
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(target, reason or "Resonance")
        end
    end)
    return ok
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

local function tryKick(target, Settings)
    if not target then return false end
    task.wait((Settings.KickDelay or 0) / 1000)
    if not fireKick(target, Settings.KickReason) then
        pseudoKick(target)
        return true
    end
    return true
end

return {
    id = "KickWithoutHats", type = "button", name = "Kick Without Hats",
    tooltip = "Kick players without hats", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hasHat = false
                for _, a in pairs(p.Character:GetChildren()) do
                    if a:IsA("Accessory") then hasHat = true; break end
                end
                if not hasHat then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}