-- ============================================================
-- Resonance v4.0 — core/remote_resolver.lua
-- Find kick / grab / action remotes for the specific game
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Resolver = {}

Resolver.keywords = {
    grab = {"grab","hold","carry","lift","pickup","grabplayer","holdplayer"},
    kick = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"},
    throw = {"throw","toss","launch","yeet","fling"},
    admin = {"admin","mod","warn","notify"}
}

Resolver.knownGames = {
    [301549746]  = "VoteKick",
    [2788229376] = "KickPlayer",
    [286090429]  = "AdminKick",
    [3260590327] = "ModKick",
    [606849621]  = "VoteKick"
}

local function matches(name, list)
    local l = name:lower()
    for _, kw in ipairs(list) do
        if l:find(kw) then return true end
    end
    return false
end

function Resolver.findAll(kind)
    local keywords = Resolver.keywords[kind] or {}
    local out = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matches(obj.Name, keywords) then
                table.insert(out, obj)
            end
        end
    end
    return out
end

function Resolver.findKickRemote()
    if Resolver.knownGames[game.PlaceId] then
        local name = Resolver.knownGames[game.PlaceId]
        local found = ReplicatedStorage:FindFirstChild(name, true)
        if found then return found end
    end
    local list = Resolver.findAll("kick")
    return list[1]
end

function Resolver.findGrabRemotes()
    return Resolver.findAll("grab")
end

-- FIXED: collect varargs into args before pcall,
-- because varargs are unavailable inside the anonymous function
function Resolver.fire(remote, ...)
    if not remote then return false end
    local args = {...}
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args))
        end
    end)
    return ok
end

function Resolver.tryKick(target, reason)
    local remote = Resolver.findKickRemote()
    if not remote then return false end
    return Resolver.fire(remote, target, reason)
end

function Resolver.dump()
    local remotes = Resolver.findAll("kick")
    print("[Resolver] kick-remotes: " .. #remotes)
    for i, r in ipairs(remotes) do
        print("  " .. i .. ". " .. r:GetFullName())
    end
    return remotes
end

return Resolver
