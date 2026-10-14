-- ============================================================
-- Resonance v4.0 — init.lua
-- Entry point: load core → settings → modules → ui → runtime
-- ============================================================

-- Replace with your own repository
local BASE = "https://raw.githubusercontent.com/a32435629-collab/resonance/main/src/"

local function load(rel)
    return loadstring(game:HttpGet(BASE .. rel))()
end

-- ============================================================
-- DUPLICATE LOAD PROTECTION
-- ============================================================
if _G.ResonanceLoaded then
    warn("[Resonance] Script is already loaded. Skipping duplicate execution.")
    return
end
_G.ResonanceLoaded = true

local log = function(msg)
    print("[Resonance] " .. tostring(msg))
end

local logErr = function(msg)
    warn("[Resonance ERROR] " .. tostring(msg))
end

-- ============================================================
-- 1. CORE
-- ============================================================
log("Loading Core...")

local coreFiles = {
    ["ResonanceUtils"]         = "core/utils.lua",
    ["ResonanceLoop"]          = "core/loop.lua",
    ["ResonanceKeybind"]       = "core/keybind.lua",
    ["ResonanceConfig"]        = "core/config.lua",
    ["ResonanceRGB"]           = "core/rgb.lua",
    ["ResonanceManifest"]      = "core/manifest.lua",
    ["ResonanceResolver"]      = "core/remote_resolver.lua"
}

for name, path in pairs(coreFiles) do
    local ok, mod = pcall(load, path)
    if ok and mod then
        _G[name] = mod
    else
        logErr("Failed to load " .. path .. ": " .. tostring(mod))
    end
end

-- ============================================================
-- 2. SETTINGS
-- ============================================================
log("Loading Settings...")

local ok, settings = pcall(load, "core/settings/init.lua")
if ok and settings then
    _G.ResonanceSettings = settings
else
    logErr("Failed to load settings: " .. tostring(settings))
    _G.ResonanceSettings = {}
end

-- ============================================================
-- 3. MODULES
-- ============================================================
log("Loading modules...")

local Registry = {
    Combat = {}, Auras = {}, Protection = {}, Targeting = {},
    Movement = {}, Visuals = {}, Server = {}, Utility = {},
    Trolling = {}, Animations = {}, Kick = {}
}

local CATEGORIES = {
    Combat     = "combat",
    Auras      = "auras",
    Protection = "protection",
    Targeting  = "targeting",
    Movement   = "movement",
    Visuals    = "visuals",
    Server     = "server",
    Utility    = "utility",
    Trolling   = "trolling",
    Animations = "animations",
    Kick       = "kick"
}

local Manifest = _G.ResonanceManifest or {}
local totalLoaded = 0
local totalFailed = 0

for cat, folder in pairs(CATEGORIES) do
    local files = Manifest[cat] or {}
    for _, file in ipairs(files) do
        local path = "modules/" .. folder .. "/" .. file .. ".lua"
        local ok, mod = pcall(load, path)
        if ok and mod then
            table.insert(Registry[cat], mod)
            totalLoaded = totalLoaded + 1
        else
            totalFailed = totalFailed + 1
            logErr("Failed to load " .. file .. ": " .. tostring(mod))
        end
    end
end

_G.ResonanceRegistry = Registry
log("Modules loaded: " .. totalLoaded .. " | errors: " .. totalFailed)

-- ============================================================
-- 4. UI
-- ============================================================
log("Building UI...")

local ok, ui = pcall(load, "ui/build.lua")
if ok and ui then
    _G.ResonanceLibrary = ui
else
    logErr("Failed to load UI: " .. tostring(ui))
end

-- ============================================================
-- 5. RUNTIME
-- ============================================================
log("Starting Runtime...")

local ok, runtime = pcall(load, "runtime.lua")
if not ok then
    logErr("Failed to load runtime: " .. tostring(runtime))
end

-- ============================================================
-- FINAL
-- ============================================================
log("============================================")
log("Resonance v4.0 loaded successfully!")
log("Functions: " .. totalLoaded)
log("Options: " .. (function()
    local c = 0
    for _ in pairs(_G.ResonanceOptions or {}) do c = c + 1 end
    return c
end)())
log("Right Shift — open menu")
log("============================================")