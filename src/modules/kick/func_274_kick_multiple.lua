-- Func #274: Kick Multiple
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}

local function matchKeywords(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do if l:find(kw) then return true end end
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
    return pcall(function()
        if remote:IsA("RemoteEvent") then remote:FireServer(target, reason)
        else remote:InvokeServer(target, reason) end
    end)
end

local function pseudoKick(player)
    if not player or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.CFrame = CFrame.new(0, 100000, 0) end
    if hum then hum.Health = 0 end
end

return {
    id = "KickMultiple", type = "button", name = "Kick Multiple",
    tooltip = "Kick multiple players at once", tab = "Kick",
    onClick = function(Settings, Utils)
        task.wait((Settings.KickDelay or 0) / 1000)
        local count = 0
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                count = count + 1
            end
        end
        Utils.notify("Kick", "Kicked: " .. count, Settings)
    end
}