-- ============================================================
-- Resonance v4.0 — ui/notifications.lua
-- Library:Notify wrapper for consistent notifications
-- ============================================================

local Notifications = {}

local function getLibrary()
    return _G.ResonanceLibrary
end

-- Basic notification
function Notifications.send(title, content, duration)
    local Library = getLibrary()
    if not Library then
        warn("[Resonance] Library is not loaded for notifications")
        return
    end
    pcall(function()
        Library:Notify({
            Title = title or "Resonance",
            Content = content or "",
            Duration = duration or 3
        })
    end)
end

-- Success
function Notifications.success(content, duration)
    Notifications.send("✓ Success", content, duration)
end

-- Error
function Notifications.error(content, duration)
    Notifications.send("✗ Error", content, duration)
end

-- Warning
function Notifications.warn(content, duration)
    Notifications.send("⚠ Warning", content, duration)
end

-- Information
function Notifications.info(content, duration)
    Notifications.send("ℹ Info", content, duration)
end

-- Debug mode only
function Notifications.debug(content)
    if _G.ResonanceSettings and _G.ResonanceSettings.Debug then
        Notifications.send("[DEBUG]", content, 2)
    end
end

-- Bind to Utils for use by modules
if _G.ResonanceUtils then
    _G.ResonanceUtils.notifyLib = Notifications.send
end

return Notifications