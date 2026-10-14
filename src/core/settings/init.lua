-- ============================================================
-- Resonance v4.0 — core/settings/init.lua
-- Collect all 40 options into one table
-- ============================================================

local OPTION_FILES = {
    "option_01_reach_distance",
    "option_02_throw_power_multiplier",
    "option_03_fling_power",
    "option_04_spin_rpm",
    "option_05_spin_radius",
    "option_06_aura_radius",
    "option_07_loop_delay",
    "option_08_walk_speed",
    "option_09_jump_power",
    "option_10_fly_speed",
    "option_11_gravity",
    "option_12_aura_type",
    "option_13_punishment_type",
    "option_14_line_material",
    "option_15_target_lock_method",
    "option_16_whitelist_friends",
    "option_17_whitelist_plots",
    "option_18_auto_leave_staff",
    "option_19_rgb_mode",
    "option_20_esp_boxes",
    "option_21_esp_tracers",
    "option_22_esp_info",
    "option_23_esp_team_check",
    "option_24_fullbright",
    "option_25_anti_grab",
    "option_26_anti_fling",
    "option_27_anti_void",
    "option_28_auto_rejoin",
    "option_29_notifications",
    "option_30_keybind",
    "option_31_animation_pack",
    "option_32_animation_speed",
    "option_33_animation_loop",
    "option_34_animation_priority",
    "option_35_animation_blend",
    "option_36_kick_message",
    "option_37_kick_reason",
    "option_38_kick_delay",
    "option_39_kick_repeat",
    "option_40_kick_target_only"
}

local BASE = "https://raw.githubusercontent.com/a32435629-collab/resonance/main/src/core/settings/"

local Settings = {}
local Options = {}

for _, name in ipairs(OPTION_FILES) do
    local ok, opt = pcall(function()
        local bundled = _G.ResonanceBundledModules
        local path = "core/settings/" .. name .. ".lua"
        if bundled and bundled[path] then return bundled[path] end
        return loadstring(game:HttpGet(BASE .. name .. ".lua"))()
    end)
    if ok and opt then
        Options[opt.id] = opt
        Settings[opt.id] = opt.default
    else
        warn("[Resonance] Failed to load option: " .. name)
    end
end

_G.ResonanceSettings = Settings
_G.ResonanceOptions  = Options

return Settings