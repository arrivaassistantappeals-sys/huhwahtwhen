-- ============================================================
-- Resonance v4.0 — core/config.lua
-- Save/load config using the executor API
-- ============================================================

local HttpService = game:GetService("HttpService")

local Config = {}
Config.folder = "Resonance"
Config.file = "config.json"

local function getPath()
    if writefile and isfolder then
        if not isfolder(Config.folder) then makefolder(Config.folder) end
        return Config.folder .. "/" .. Config.file
    end
    return nil
end

local function sanitize(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        local tv = type(v)
        if tv ~= "function" and tv ~= "userdata" and tv ~= "thread" then
            out[k] = (tv == "table") and sanitize(v) or v
        end
    end
    return out
end

function Config.save(Settings)
    local path = getPath()
    if not path then return false, "executor has no filesystem support" end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(sanitize(Settings))
    end)
    if not ok then return false, "serialization error" end
    local ok2, err = pcall(function() writefile(path, encoded) end)
    return ok2, err
end

function Config.load(Settings)
    local path = getPath()
    if not path then return false, "executor has no filesystem support" end
    if not (isfile and isfile(path)) then return false, "config not found" end
    local ok, data = pcall(function() return readfile(path) end)
    if not ok then return false, "read error" end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if not ok2 then return false, "invalid JSON" end
    for k, v in pairs(decoded) do Settings[k] = v end
    return true
end

function Config.delete()
    local path = getPath()
    if path and delfile and isfile and isfile(path) then
        delfile(path)
        return true
    end
    return false
end

function Config.exists()
    local path = getPath()
    return path and isfile and isfile(path) or false
end

return Config