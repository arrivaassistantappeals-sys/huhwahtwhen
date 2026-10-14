-- Resonance v4.0 — English bundle with corrected menu initialization
local __RESONANCE, __FACTORIES = {}, {}

-- === core/utils.lua ===
__FACTORIES["core/utils.lua"] = function()
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
end

-- === core/loop.lua ===
__FACTORIES["core/loop.lua"] = function()
-- ============================================================
-- Resonance v4.0 — core/loop.lua
-- Loop manager: start / stop / conditional
-- ============================================================

local Loop = {}
Loop.tasks = {}

-- Start a named loop
function Loop.start(name, fn, delay)
    Loop.stop(name)
    Loop.tasks[name] = task.spawn(function()
        while Loop.tasks[name] do
            local ok, err = pcall(fn)
            if not ok then
                warn("[Resonance Loop:" .. name .. "] " .. tostring(err))
                task.wait(1)
            end
            local d = delay
            if type(d) == "function" then d = d() end
            task.wait(d or 0.1)
        end
    end)
end

function Loop.stop(name)
    if Loop.tasks[name] then
        task.cancel(Loop.tasks[name])
        Loop.tasks[name] = nil
    end
end

function Loop.stopAll()
    for name in pairs(Loop.tasks) do
        Loop.stop(name)
    end
end

function Loop.isRunning(name)
    return Loop.tasks[name] ~= nil
end

-- Conditional loop: stop when condition() returns false
function Loop.conditional(name, condition, fn, delay)
    Loop.start(name, function()
        if not condition() then
            Loop.stop(name)
            return
        end
        fn()
    end, delay)
end

-- Wait with a condition
function Loop.awaitCondition(condition, timeout)
    local start = tick()
    timeout = timeout or 10
    while not condition() do
        if tick() - start > timeout then return false end
        task.wait(0.1)
    end
    return true
end

return Loop
end

-- === core/keybind.lua ===
__FACTORIES["core/keybind.lua"] = function()
-- ============================================================
-- Resonance v4.0 — core/keybind.lua
-- Hotkey system
-- ============================================================

local UserInputService = game:GetService("UserInputService")

local Keybind = {}
Keybind.bindings = {}
Keybind.connection = nil

function Keybind.bind(key, callback, options)
    options = options or {}
    local kc = type(key) == "string" and Enum.KeyCode[key] or key
    if not kc then return end
    Keybind.bindings[kc] = {
        callback = callback,
        gpe = options.gpe or false
    }
    Keybind._ensure()
end

function Keybind.unbind(key)
    local kc = type(key) == "string" and Enum.KeyCode[key] or key
    Keybind.bindings[kc] = nil
end

function Keybind.clear()
    Keybind.bindings = {}
end

function Keybind._ensure()
    if Keybind.connection then return end
    Keybind.connection = UserInputService.InputBegan:Connect(function(input, gpe)
        local b = Keybind.bindings[input.KeyCode]
        if not b then return end
        if gpe and not b.gpe then return end
        local ok, err = pcall(b.callback, input)
        if not ok then warn("[Resonance Keybind] " .. tostring(err)) end
    end)
end

function Keybind.toKeyCode(str)
    if type(str) == "userdata" then return str end
    local ok, key = pcall(function() return Enum.KeyCode[str] end)
    return ok and key or nil
end

-- Register the menu toggle on RightShift (or another key)
function Keybind.registerMenuToggle(keyStr, library)
    local key = Keybind.toKeyCode(keyStr or "RightShift")
    if not key then return end
    Keybind.bind(key, function()
        if library.Toggle then
            library:Toggle()
        elseif library.SetVisible then
            -- fallback
        end
    end, { gpe = true })
end

return Keybind
end

-- === core/config.lua ===
__FACTORIES["core/config.lua"] = function()
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
end

-- === core/rgb.lua ===
__FACTORIES["core/rgb.lua"] = function()
-- ============================================================
-- Resonance v4.0 — core/rgb.lua
-- Global RGB mode (rainbow for UI/objects)
-- ============================================================

local RunService = game:GetService("RunService")

local RGB = {}
RGB.hue = 0
RGB.speed = 0.5
RGB.targets = {}
RGB.running = false
RGB.conn = nil

local function step(dt)
    if not RGB.running then return end
    RGB.hue = (RGB.hue + dt * RGB.speed) % 1
    local color = Color3.fromHSV(RGB.hue, 1, 1)
    for obj, props in pairs(RGB.targets) do
        if typeof(obj) == "Instance" and obj.Parent then
            for _, prop in ipairs(props) do
                pcall(function() obj[prop] = color end)
            end
        else
            RGB.targets[obj] = nil
        end
    end
end

function RGB.start()
    if RGB.running then return end
    RGB.running = true
    RGB.conn = RunService.RenderStepped:Connect(step)
end

function RGB.stop()
    if not RGB.running then return end
    RGB.running = false
    if RGB.conn then RGB.conn:Disconnect(); RGB.conn = nil end
end

function RGB.register(obj, ...)
    local props = {...}
    if #props == 0 then props = {"Color"} end
    RGB.targets[obj] = props
end

function RGB.unregister(obj)
    RGB.targets[obj] = nil
end

function RGB.clear()
    RGB.targets = {}
end

function RGB.getColor()
    return Color3.fromHSV(RGB.hue, 1, 1)
end

function RGB.bind(Settings)
    task.spawn(function()
        while true do
            task.wait(0.5)
            if Settings.RGBMode then
                if not RGB.running then RGB.start() end
            else
                if RGB.running then RGB.stop() end
            end
        end
    end)
end

return RGB
end

-- === core/manifest.lua ===
__FACTORIES["core/manifest.lua"] = function()
-- ============================================================
-- Resonance v4.0 — core/manifest.lua
-- List of all feature modules (275 files)
-- ============================================================

return {
    Combat = {
        "func_001_super_throw","func_002_massless_grab","func_003_freeze_grab","func_004_silent_aim",
        "func_005_aimbot","func_006_telekinesis","func_007_auto_throw","func_008_kill_aura",
        "func_009_hitbox_expander","func_010_wall_bang","func_011_rapid_fire","func_012_no_recoil",
        "func_013_fling_all","func_014_fling_random","func_015_fling_closest","func_016_kill_all",
        "func_017_kill_closest","func_018_kill_random","func_019_burn_all","func_020_burn_closest",
        "func_021_freeze_all","func_022_unfreeze_all","func_023_ragdoll_all","func_024_explode_all",
        "func_025_void_all","func_026_sky_all","func_027_shake_all","func_028_spin_all",
        "func_029_slow_all","func_030_speed_all","func_031_jump_all","func_032_reset_all",
        "func_033_anchor_all","func_034_unanchor_all","func_035_shirt_off_all","func_036_pants_off_all",
        "func_037_hats_off_all","func_038_drop_tools_all","func_039_forcefield_off_all","func_040_character_reset"
    },
    Auras = {
        "func_041_fling_aura","func_042_kill_aura","func_043_freeze_aura","func_044_fire_aura",
        "func_045_void_aura","func_046_attraction_aura","func_047_auto_counter","func_048_plot_kicker",
        "func_049_gravity_aura","func_050_spin_aura","func_051_damage_aura","func_052_slow_aura",
        "func_053_ragdoll_aura","func_054_teleport_aura","func_055_blind_aura","func_056_kick_aura",
        "func_057_confuse_aura","func_058_mute_aura","func_059_shrink_aura","func_060_grow_aura"
    },
    Protection = {
        "func_061_anti_grab","func_062_anti_fling","func_063_anti_freeze","func_064_anti_ragdoll",
        "func_065_anti_void","func_066_anti_vote_kick","func_067_anti_kick","func_068_anti_teleport",
        "func_069_anti_sit","func_070_anti_burn","func_071_anti_explosion","func_072_anti_damage",
        "func_073_anti_slow","func_074_anti_fire_touch","func_075_anti_gravity","func_076_anti_shrink",
        "func_077_noclip","func_078_infinite_yield","func_079_god_mode","func_080_rejoin_on_damage"
    },
    Targeting = {
        "func_081_loop_kill","func_082_loop_burn","func_083_loop_fling","func_084_loop_freeze",
        "func_085_loop_void","func_086_follow_target","func_087_view_target","func_088_tp_to_target",
        "func_089_tp_target_to_me","func_090_kill_target","func_091_fling_target","func_092_freeze_target",
        "func_093_void_target","func_094_sky_target","func_095_spin_target","func_096_orbit_target",
        "func_097_ragdoll_target","func_098_blind_target","func_099_steal_target_tools","func_100_copy_target_skin"
    },
    Movement = {
        "func_101_infinite_jump","func_102_noclip","func_103_fly","func_104_speed_boost",
        "func_105_high_jump","func_106_low_gravity","func_107_zero_gravity","func_108_auto_jump",
        "func_109_bunny_hop","func_110_slide","func_111_wall_run","func_112_crouch",
        "func_113_sprint","func_114_tp_spawn","func_115_tp_random_player","func_116_tp_forward",
        "func_117_tp_up","func_118_tp_down","func_119_tp_cursor","func_120_reset_speed"
    },
    Visuals = {
        "func_121_esp_boxes","func_122_esp_tracers","func_123_player_info","func_124_name_tags",
        "func_125_health_bars","func_126_distance_display","func_127_skeleton_esp","func_128_chams",
        "func_129_xray","func_130_fullbright","func_131_no_fog","func_132_remove_textures",
        "func_133_blue_sky","func_134_red_ambient","func_135_green_ambient","func_136_rainbow_light",
        "func_137_remove_baseplate","func_138_remove_lights","func_139_restore_lighting","func_140_disable_shadows"
    },
    Server = {
        "func_141_rejoin","func_142_server_hop","func_143_join_smallest","func_144_join_largest",
        "func_145_copy_jobid","func_146_copy_placeid","func_147_copy_server_link","func_148_show_server_info",
        "func_149_list_players","func_150_hop_until_empty","func_151_anti_afk","func_152_auto_rejoin_kick",
        "func_153_rejoin_delay","func_154_ping_display","func_155_fps_display","func_156_leave_game",
        "func_157_reset_character","func_158_character_respawn","func_159_unlock_fps","func_160_show_fps"
    },
    Utility = {
        "func_161_anti_afk","func_162_auto_claim_cash","func_163_cash_magnet","func_164_item_magnet",
        "func_165_bring_all_items","func_166_bring_all_players","func_167_clear_workspace","func_168_delete_grabbed",
        "func_169_unlock_mouse","func_170_full_screen","func_171_copy_position","func_172_copy_rotation",
        "func_173_show_position","func_174_print_character","func_175_clear_notifications","func_176_toggle_ui",
        "func_177_re_execute","func_178_reload_config","func_179_save_config","func_180_wipe_cache"
    },
    Trolling = {
        "func_181_music_play","func_182_reverse_controls","func_183_fling_random_aura","func_184_rainbow_all",
        "func_185_neon_all","func_186_shrink_all","func_187_grow_all","func_188_head_spin_all",
        "func_189_random_color_self","func_190_rainbow_self","func_191_neon_self","func_192_ghost_self",
        "func_193_invisible_self","func_194_visible_self","func_195_shake_screen_all","func_196_fake_death_all",
        "func_197_fire_trail","func_198_ice_trail","func_199_lightning_self","func_200_dance_all"
    },
    Animations = {
        "func_201_play_dance","func_202_play_wave","func_203_play_point","func_204_play_laugh",
        "func_205_play_cheer","func_206_play_floss","func_207_play_dab","func_208_play_russian",
        "func_209_play_karate","func_210_play_salsa","func_211_play_hiphop","func_212_play_breakdance",
        "func_213_play_robot","func_214_play_backflip","func_215_play_frontflip","func_216_play_sit",
        "func_217_play_lay","func_218_play_crawl","func_219_play_sprint_anim","func_220_play_swim",
        "func_221_play_climb","func_222_stop_all_anims","func_223_free_anims_off","func_224_anim_speed_up",
        "func_225_anim_slow_down"
    },
    Kick = {
        "func_226_kick_all","func_227_kick_closest","func_228_kick_random","func_229_kick_by_name",
        "func_230_kick_farthest","func_231_kick_lowest_hp","func_232_kick_highest_hp","func_233_kick_friend",
        "func_234_kick_non_friend","func_235_kick_team","func_236_kick_enemy_team","func_237_kick_afk",
        "func_238_kick_talking","func_239_kick_silent","func_240_kick_walking","func_241_kick_standing",
        "func_242_kick_jumping","func_243_kick_flying","func_244_kick_glitched","func_245_kick_invisible",
        "func_246_kick_visible","func_247_kick_high_ping","func_248_kick_low_ping","func_249_kick_mobile",
        "func_250_kick_pc","func_251_kick_console","func_252_kick_vr","func_253_kick_guest",
        "func_254_kick_premium","func_255_kick_non_premium","func_256_kick_verified","func_257_kick_non_verified",
        "func_258_kick_with_hats","func_259_kick_without_hats","func_260_kick_with_tools","func_261_kick_without_tools",
        "func_262_kick_rich","func_263_kick_poor","func_264_kick_high_level","func_265_kick_low_level",
        "func_266_kick_owner","func_267_kick_admin","func_268_kick_moderator","func_269_kick_staff",
        "func_270_kick_bots","func_271_kick_alts","func_272_kick_by_userid","func_273_kick_by_display_name",
        "func_274_kick_multiple","func_275_kick_blacklist"
    }
}
end

-- === core/remote_resolver.lua ===
__FACTORIES["core/remote_resolver.lua"] = function()
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

end

-- === core/settings/init.lua ===
__FACTORIES["core/settings/init.lua"] = function()
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
end

-- === ui/theme.lua ===
__FACTORIES["ui/theme.lua"] = function()
-- ============================================================
-- Resonance v4.0 — ui/theme.lua
-- Custom Obsidian theme settings
-- ============================================================

local Theme = {
    -- Primary colors (hex)
    Accent      = Color3.fromRGB(120, 90, 255),
    AccentDark  = Color3.fromRGB(80, 60, 180),
    Background  = Color3.fromRGB(18, 18, 24),
    Panel       = Color3.fromRGB(26, 26, 36),
    Text        = Color3.fromRGB(240, 240, 255),
    TextDim     = Color3.fromRGB(150, 150, 170),
    Success     = Color3.fromRGB(80, 200, 120),
    Danger      = Color3.fromRGB(220, 80, 80),
    Warning     = Color3.fromRGB(240, 180, 60),

    -- Window settings
    Window = {
        Title = "Resonance",
        Icon = "rocket",
        Footer = "Resonance v4.0 | FTAP",
        CornerRadius = 20,
        Width = 600,
        Height = 500,
        MinWidth = 400,
        MinHeight = 300,
        NotifySide = "Right"
    },

    -- Animation settings
    Animations = {
        OpenTime  = 0.25,
        CloseTime = 0.2,
        HoverTime = 0.15,
        EasingStyle = Enum.EasingStyle.Quart,
        EasingDirection = Enum.EasingDirection.Out
    }
}

-- Apply the theme to Library (if supported)
function Theme.apply(Library)
    if not Library then return end
    local ok, err = pcall(function()
        if Library.SetAccentColor then
            Library:SetAccentColor(Theme.Accent)
        end
        if Library.SetCornerRadius then
            Library:SetCornerRadius(Theme.Window.CornerRadius)
        end
    end)
    if not ok then
        warn("[Resonance Theme] " .. tostring(err))
    end
end

return Theme
end

-- === ui/notifications.lua ===
__FACTORIES["ui/notifications.lua"] = function()
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
end

-- === ui/build.lua ===
__FACTORIES["ui/build.lua"] = function()
-- ============================================================
-- Resonance v4.0 — ui/build.lua
-- Generate the UI from Registry + Options using Obsidian
-- ============================================================

local LibraryUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(LibraryUrl .. "Library.lua"))()

local Registry = _G.ResonanceRegistry
local Options  = _G.ResonanceOptions
local Settings = _G.ResonanceSettings
local Utils    = _G.ResonanceUtils
local Keybind  = _G.ResonanceKeybind
local Notify   = _G.ResonanceNotifications

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Library:CreateWindow({
    Title = "Resonance",
    Icon = "rocket",
    Footer = "Resonance v4.0 | FTAP",
    NotifySide = "Right",
    ShowCustomCursor = true,
    Resizable = true,
    EnableSidebarResize = true,
    EnableCompacting = true,
    SidebarCompacted = true,
    MinSidebarWidth = 200,
    SidebarCompactWidth = 56
})

Window:SetCornerRadius(20)

-- ============================================================
-- TABS
-- ============================================================
local Tabs = {
    Home       = Window:AddTab("Home", "house", "Profile, statistics"),
    Main       = Window:AddTab("Main", "settings", "Main settings"),
    Combat     = Window:AddTab("Combat", "hand", "Grabbing / combat"),
    Auras      = Window:AddTab("Auras", "zap", "Automatic auras"),
    Protection = Window:AddTab("Protection", "shield", "Protection"),
    Targeting  = Window:AddTab("Targeting", "crosshair", "Target tools"),
    Movement   = Window:AddTab("Movement", "footprints", "Movement"),
    Visuals    = Window:AddTab("Visuals", "eye", "Visual features"),
    Server     = Window:AddTab("Server", "server", "Server tools"),
    Utility    = Window:AddTab("Utility", "wrench", "Utilities"),
    Trolling   = Window:AddTab("Trolling", "ghost", "Trolling"),
    Animations = Window:AddTab("Animations", "person-standing", "Animations"),
    Kick       = Window:AddTab("Kick", "user-x", "Kick features"),
    Filters    = Window:AddTab("Filters", "filter", "Exclusions"),
    Settings   = Window:AddTab("Settings", "sliders-horizontal", "GUI settings")
}

-- ============================================================
-- HOME
-- ============================================================
local HomeLeft = Tabs.Home:AddLeftGroupbox("Welcome", "rocket")
HomeLeft:AddLabel("Resonance v4.0")
HomeLeft:AddLabel("Created by the Rocket Way team")
HomeLeft:AddLabel("Loaded at: " .. os.date("%H:%M:%S"))

local HomeRight = Tabs.Home:AddRightGroupbox("Statistics", "activity")
local totalFuncs = 0
for _, mods in pairs(Registry or {}) do
    totalFuncs = totalFuncs + #mods
end
HomeRight:AddLabel("Functions: " .. totalFuncs)
HomeRight:AddLabel("Options: " .. (function() local c=0; for _ in pairs(Options or {}) do c=c+1 end; return c end)())
HomeRight:AddLabel("Categories: 11")

local HomeKeys = Tabs.Home:AddLeftGroupbox("Hotkeys", "keyboard")
HomeKeys:AddLabel("Right Shift — open/close menu")

-- ============================================================
-- OPTIONS — arranged by tab
-- ============================================================
local OptionGroups = {}

local function getGroup(tabName, sectionName)
    local tab = Tabs[tabName] or Tabs.Main
    local key = tostring(tabName) .. "::" .. tostring(sectionName)
    if not OptionGroups[key] then
        OptionGroups[key] = tab:AddLeftGroupbox(sectionName or "Settings", "settings-2")
    end
    return OptionGroups[key]
end

for _, opt in pairs(Options or {}) do
    local group = getGroup(opt.tab, opt.section)

    if opt.type == "slider" then
        group:AddSlider("Option_" .. opt.id, {
            Text = opt.name, Min = opt.range[1], Max = opt.range[2],
            Default = opt.default, Rounding = 2, Tooltip = opt.tooltip,
            Callback = function(v) opt.onChanged(v, Settings) end
        })
    elseif opt.type == "toggle" then
        group:AddToggle("Option_" .. opt.id, {
            Text = opt.name,
            Default = opt.default,
            Tooltip = opt.tooltip,
            Callback = function(v) opt.onChanged(v, Settings) end
        })
    elseif opt.type == "dropdown" then
        group:AddDropdown("Option_" .. opt.id, {
            Text = opt.name,
            Values = opt.options,
            Default = opt.default,
            Multi = opt.multiple or false,
            Tooltip = opt.tooltip,
            Callback = function(v)
                local val = type(v) == "table" and v or {v}
                opt.onChanged(val, Settings)
            end
        })
    elseif opt.type == "input" then
        group:AddInput("Option_" .. opt.id, {
            Text = opt.name,
            Default = opt.default,
            Placeholder = "Enter...",
            Tooltip = opt.tooltip,
            Callback = function(txt) opt.onChanged(txt, Settings) end
        })
    elseif opt.type == "keybind" then
        group:AddLabel(opt.name):AddKeyPicker("Option_" .. opt.id, {
            Default = opt.default, Mode = "Toggle",
            ChangedCallback = function(v)
                opt.onChanged(typeof(v) == "EnumItem" and v.Name or tostring(v), Settings)
            end
        })
    end
end

-- ============================================================
-- FEATURES — arranged by category
-- ============================================================
for cat, mods in pairs(Registry or {}) do
    local tab = Tabs[cat]
    if not tab then continue end

    local toggleGroup = nil
    local buttonGroup = nil

    for _, mod in ipairs(mods) do
        if mod.type == "toggle" then
            if not toggleGroup then
                toggleGroup = tab:AddLeftGroupbox("Toggles", "settings")
            end
            toggleGroup:AddToggle("Feature_" .. cat .. "_" .. mod.id, {
                Text = mod.name,
                Default = mod.default or false,
                Tooltip = mod.tooltip,
                Callback = function(v)
                    Settings[mod.id] = v
                    if v and mod.onEnable then
                        local ok, err = pcall(mod.onEnable, Settings, Utils)
                        if not ok then warn("[Resonance] onEnable " .. mod.id .. ": " .. tostring(err)) end
                    end
                    if not v and mod.onDisable then
                        local ok, err = pcall(mod.onDisable, Settings, Utils)
                        if not ok then warn("[Resonance] onDisable " .. mod.id .. ": " .. tostring(err)) end
                    end
                end
            })
        elseif mod.type == "button" then
            if not buttonGroup then
                buttonGroup = tab:AddRightGroupbox("Actions", "play")
            end
            buttonGroup:AddButton({
                Text = mod.name,
                Tooltip = mod.tooltip,
                Func = function()
                    if mod.onClick then
                        local ok, err = pcall(mod.onClick, Settings, Utils)
                        if not ok then warn("[Resonance] onClick " .. mod.id .. ": " .. tostring(err)) end
                    end
                end
            })
        end
    end
end

-- ============================================================
-- SETTINGS (GUI)
-- ============================================================
local GuiConfig = Tabs.Settings:AddLeftGroupbox("Config", "save")
GuiConfig:AddButton({
    Text = "Load config",
    Func = function()
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.load(Settings)
            if not ok then
                Library:Notify({ Title = "Config", Content = tostring(err), Duration = 3 })
            end
        end
    end
})
GuiConfig:AddButton({
    Text = "Save config",
    Func = function()
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.save(Settings)
            if not ok then
                Library:Notify({ Title = "Config", Content = tostring(err), Duration = 3 })
            end
        end
    end
})
GuiConfig:AddButton({
    Text = "Delete config",
    Func = function()
        local Config = _G.ResonanceConfig
        if Config then Config.delete() end
    end
})

local GuiInfo = Tabs.Settings:AddRightGroupbox("Information", "info")
GuiInfo:AddLabel("Version: 4.0")
GuiInfo:AddLabel("Loaded at: " .. os.date("%d.%m.%Y %H:%M"))

local GuiDanger = Tabs.Settings:AddLeftGroupbox("Danger zone", "alert-triangle")
GuiDanger:AddButton({
    Text = "Destroy UI",
    Func = function()
        Library:Unload()
    end
})

-- ============================================================
-- KEYBIND
-- ============================================================
if Keybind and Keybind.registerMenuToggle then
    Keybind.registerMenuToggle(Settings.Keybind or "RightShift", Library)
else
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            Library:Toggle()
        end
    end)
end

-- ============================================================
-- NOTIFY
-- ============================================================
Library:Notify({
    Title = "Resonance",
    Content = "Script loaded. Right Shift — open menu.",
    Duration = 5
})

_G.ResonanceLibrary = Library
_G.ResonanceTabs = Tabs

return Library
end

-- === modules/combat/func_001_super_throw.lua ===
__FACTORIES["modules/combat/func_001_super_throw.lua"] = function()
-- Func #001: Super Throw | toggle

local Workspace = game:GetService("Workspace")
local Debris    = game:GetService("Debris")
local Camera    = Workspace.CurrentCamera

return {
    id = "SuperThrow", type = "toggle", name = "Super Throw",
    tooltip = "Stronger object throws", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceSuperThrowConn = Workspace.ChildAdded:Connect(function(model)
            if not Settings.SuperThrow then return end
            if model.Name ~= "GrabParts" then return end
            local grab = model:FindFirstChild("GrabPart")
            if not grab then return end
            local weld = grab:FindFirstChild("WeldConstraint")
            if not weld or not weld.Part1 then return end
            local part = weld.Part1
            local bv = Instance.new("BodyVelocity", part)
            model:GetPropertyChangedSignal("Parent"):Connect(function()
                if not model.Parent then
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Camera.CFrame.LookVector * (Settings.FlingPower or 350) * (Settings.ThrowPowerMult or 1)
                    Debris:AddItem(bv, 0.5)
                end
            end)
        end)
    end,
    onDisable = function()
        if _G.ResonanceSuperThrowConn then
            _G.ResonanceSuperThrowConn:Disconnect()
            _G.ResonanceSuperThrowConn = nil
        end
    end
}
end

-- === modules/combat/func_002_massless_grab.lua ===
__FACTORIES["modules/combat/func_002_massless_grab.lua"] = function()
-- Func #002: Massless Grab | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "MasslessGrab", type = "toggle", name = "Massless Grab",
    tooltip = "Make held objects weightless", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceMasslessConn = Workspace.ChildAdded:Connect(function(child)
            if not Settings.MasslessGrab then return end
            if child.Name ~= "GrabParts" then return end
            task.wait(0.1)
            for _, obj in pairs(child:GetDescendants()) do
                if obj:IsA("BasePart") then obj.Massless = true end
            end
        end)
    end,
    onDisable = function()
        if _G.ResonanceMasslessConn then
            _G.ResonanceMasslessConn:Disconnect()
            _G.ResonanceMasslessConn = nil
        end
    end
}
end

-- === modules/combat/func_003_freeze_grab.lua ===
__FACTORIES["modules/combat/func_003_freeze_grab.lua"] = function()
-- Func #003: Freeze Grab | toggle
local Workspace = game:GetService("Workspace")
local State = { running = false }

return {
    id = "FreezeGrab", type = "toggle", name = "Freeze Grab",
    tooltip = "Lock the held object in place", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local gp = Workspace:FindFirstChild("GrabParts")
                if gp then
                    for _, obj in pairs(gp:GetDescendants()) do
                        if obj:IsA("BasePart") then obj.Anchored = true end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        local gp = Workspace:FindFirstChild("GrabParts")
        if gp then
            for _, obj in pairs(gp:GetDescendants()) do
                if obj:IsA("BasePart") then obj.Anchored = false end
            end
        end
    end
}
end

-- === modules/combat/func_004_silent_aim.lua ===
__FACTORIES["modules/combat/func_004_silent_aim.lua"] = function()
-- Func #004: Silent Aim | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "SilentAim", type = "toggle", name = "Silent Aim",
    tooltip = "Smoothly aim the camera at the nearest player", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceSilentAimConn = RunService.RenderStepped:Connect(function()
            if not Settings.SilentAim then return end
            local target = Utils.getClosestPlayer(Settings)
            if not target then return end
            local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local myPos = Camera.CFrame.Position
            local lookDir = (hrp.Position - myPos).Unit
            local currentLook = Camera.CFrame.LookVector
            Camera.CFrame = CFrame.new(myPos, myPos + currentLook:Lerp(lookDir, 0.15))
        end)
    end,
    onDisable = function()
        if _G.ResonanceSilentAimConn then
            _G.ResonanceSilentAimConn:Disconnect()
            _G.ResonanceSilentAimConn = nil
        end
    end
}
end

-- === modules/combat/func_005_aimbot.lua ===
__FACTORIES["modules/combat/func_005_aimbot.lua"] = function()
-- Func #005: Aimbot | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "Aimbot", type = "toggle", name = "Aimbot",
    tooltip = "Snap the camera onto a player", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAimbotConn = RunService.RenderStepped:Connect(function()
            if not Settings.Aimbot then return end
            local target = Utils.getClosestPlayer(Settings)
            if not target then return end
            local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
        end)
    end,
    onDisable = function()
        if _G.ResonanceAimbotConn then
            _G.ResonanceAimbotConn:Disconnect()
            _G.ResonanceAimbotConn = nil
        end
    end
}
end

-- === modules/combat/func_006_telekinesis.lua ===
__FACTORIES["modules/combat/func_006_telekinesis.lua"] = function()
-- Func #006: Telekinesis | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "Telekinesis", type = "toggle", name = "Telekinesis",
    tooltip = "Move objects under the cursor", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local mouse = LocalPlayer:GetMouse()
                if mouse and mouse.Target and mouse.Target:IsA("BasePart") and not mouse.Target.Anchored then
                    pcall(function() mouse.Target.CFrame = mouse.Hit + Vector3.new(0, 3, 0) end)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/combat/func_007_auto_throw.lua ===
__FACTORIES["modules/combat/func_007_auto_throw.lua"] = function()
-- Func #007: Auto Throw | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "AutoThrow", type = "toggle", name = "Auto Throw",
    tooltip = "Automatically release the grabbed object", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAutoThrowConn = Workspace.ChildAdded:Connect(function(model)
            if not Settings.AutoThrow then return end
            if model.Name ~= "GrabParts" then return end
            task.wait(0.3)
            local grab = model:FindFirstChild("GrabPart")
            if grab then pcall(function() grab:Destroy() end) end
        end)
    end,
    onDisable = function()
        if _G.ResonanceAutoThrowConn then
            _G.ResonanceAutoThrowConn:Disconnect()
            _G.ResonanceAutoThrowConn = nil
        end
    end
}
end

-- === modules/combat/func_008_kill_aura.lua ===
__FACTORIES["modules/combat/func_008_kill_aura.lua"] = function()
-- Func #008: Kill Aura | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "KillAuraCombat", type = "toggle", name = "Kill Aura",
    tooltip = "Kill everyone within range", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.Health = 0
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/combat/func_009_hitbox_expander.lua ===
__FACTORIES["modules/combat/func_009_hitbox_expander.lua"] = function()
-- Func #009: Hitbox Expander | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "HitboxExpander", type = "toggle", name = "Hitbox Expander",
    tooltip = "Enlarge player hitboxes", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Size = Vector3.new(20, 20, 20)
                            hrp.Transparency = 0.7
                            hrp.CanCollide = false
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                end
            end
        end
    end
}
end

-- === modules/combat/func_010_wall_bang.lua ===
__FACTORIES["modules/combat/func_010_wall_bang.lua"] = function()
-- Func #010: Wall Bang | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "WallBang", type = "toggle", name = "Wall Bang",
    tooltip = "Damage through walls", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude < 30 then
                            hum:TakeDamage(10)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/combat/func_011_rapid_fire.lua ===
__FACTORIES["modules/combat/func_011_rapid_fire.lua"] = function()
-- Func #011: Rapid Fire | toggle
local State = { running = false }

return {
    id = "RapidFire", type = "toggle", name = "Rapid Fire",
    tooltip = "Rapid fire", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local char = Utils.getChar()
                if char then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        pcall(function() tool:Activate() end)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/combat/func_012_no_recoil.lua ===
__FACTORIES["modules/combat/func_012_no_recoil.lua"] = function()
-- Func #012: No Recoil | toggle
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Camera     = Workspace.CurrentCamera

return {
    id = "NoRecoil", type = "toggle", name = "No Recoil",
    tooltip = "Remove camera recoil", tab = "Combat", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceNoRecoilConn = RunService.RenderStepped:Connect(function()
            if not Settings.NoRecoil then return end
            local rot = Camera.CFrame - Camera.CFrame.Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position) * rot
        end)
    end,
    onDisable = function()
        if _G.ResonanceNoRecoilConn then
            _G.ResonanceNoRecoilConn:Disconnect()
            _G.ResonanceNoRecoilConn = nil
        end
    end
}
end

-- === modules/combat/func_013_fling_all.lua ===
__FACTORIES["modules/combat/func_013_fling_all.lua"] = function()
-- Func #013: Fling All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingAll", type = "button", name = "Fling All",
    tooltip = "Fling all players", tab = "Combat",
    onClick = function(Settings, Utils)
        local power = Settings.FlingPower or 300
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then Utils.fling(hrp, power) end
            end
        end
    end
}
end

-- === modules/combat/func_014_fling_random.lua ===
__FACTORIES["modules/combat/func_014_fling_random.lua"] = function()
-- Func #014: Fling Random | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingRandom", type = "button", name = "Fling Random",
    tooltip = "Fling a random player", tab = "Combat",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 300) end
    end
}
end

-- === modules/combat/func_015_fling_closest.lua ===
__FACTORIES["modules/combat/func_015_fling_closest.lua"] = function()
-- Func #015: Fling Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FlingClosest", type = "button", name = "Fling Closest",
    tooltip = "Fling the nearest player", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 300) end
    end
}
end

-- === modules/combat/func_016_kill_all.lua ===
__FACTORIES["modules/combat/func_016_kill_all.lua"] = function()
-- Func #016: Kill All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillAll", type = "button", name = "Kill All",
    tooltip = "Kill everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Health = 0 end
            end
        end
    end
}
end

-- === modules/combat/func_017_kill_closest.lua ===
__FACTORIES["modules/combat/func_017_kill_closest.lua"] = function()
-- Func #017: Kill Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillClosest", type = "button", name = "Kill Closest",
    tooltip = "Kill the nearest player", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}
end

-- === modules/combat/func_018_kill_random.lua ===
__FACTORIES["modules/combat/func_018_kill_random.lua"] = function()
-- Func #018: Kill Random | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "KillRandom", type = "button", name = "Kill Random",
    tooltip = "Kill a random player", tab = "Combat",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local hum = list[math.random(1, #list)].Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}
end

-- === modules/combat/func_019_burn_all.lua ===
__FACTORIES["modules/combat/func_019_burn_all.lua"] = function()
-- Func #019: Burn All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BurnAll", type = "button", name = "Burn All",
    tooltip = "Set everyone on fire", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then Debris:AddItem(Instance.new("Fire", hrp), 5) end
            end
        end
    end
}
end

-- === modules/combat/func_020_burn_closest.lua ===
__FACTORIES["modules/combat/func_020_burn_closest.lua"] = function()
-- Func #020: Burn Closest | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BurnClosest", type = "button", name = "Burn Closest",
    tooltip = "Set the nearest player on fire", tab = "Combat",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Debris:AddItem(Instance.new("Fire", hrp), 5) end
    end
}
end

-- === modules/combat/func_021_freeze_all.lua ===
__FACTORIES["modules/combat/func_021_freeze_all.lua"] = function()
-- Func #021: Freeze All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FreezeAll", type = "button", name = "Freeze All",
    tooltip = "Freeze everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
            end
        end
    end
}
end

-- === modules/combat/func_022_unfreeze_all.lua ===
__FACTORIES["modules/combat/func_022_unfreeze_all.lua"] = function()
-- Func #022: Unfreeze All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "UnfreezeAll", type = "button", name = "Unfreeze All",
    tooltip = "Unfreeze everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
            end
        end
    end
}
end

-- === modules/combat/func_023_ragdoll_all.lua ===
__FACTORIES["modules/combat/func_023_ragdoll_all.lua"] = function()
-- Func #023: Ragdoll All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "RagdollAll", type = "button", name = "Ragdoll All",
    tooltip = "Ragdoll everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
            end
        end
    end
}
end

-- === modules/combat/func_024_explode_all.lua ===
__FACTORIES["modules/combat/func_024_explode_all.lua"] = function()
-- Func #024: Explode All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ExplodeAll", type = "button", name = "Explode All",
    tooltip = "Explode everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local e = Instance.new("Explosion")
                    e.Position = hrp.Position
                    e.BlastRadius = 15
                    e.BlastPressure = 500000
                    e.Parent = workspace
                end
            end
        end
    end
}
end

-- === modules/combat/func_025_void_all.lua ===
__FACTORIES["modules/combat/func_025_void_all.lua"] = function()
-- Func #025: Void All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "VoidAll", type = "button", name = "Void All",
    tooltip = "Send everyone into the void", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
            end
        end
    end
}
end

-- === modules/combat/func_026_sky_all.lua ===
__FACTORIES["modules/combat/func_026_sky_all.lua"] = function()
-- Func #026: Sky All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SkyAll", type = "button", name = "Sky All",
    tooltip = "Send everyone into the sky", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(0, 500, 0) end
            end
        end
    end
}
end

-- === modules/combat/func_027_shake_all.lua ===
__FACTORIES["modules/combat/func_027_shake_all.lua"] = function()
-- Func #027: Shake All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShakeAll", type = "button", name = "Shake All",
    tooltip = "Shake everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    task.spawn(function()
                        for i = 1, 20 do
                            if not hrp.Parent then break end
                            hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), math.random(-3,3), math.random(-3,3))
                            task.wait(0.05)
                        end
                    end)
                end
            end
        end
    end
}
end

-- === modules/combat/func_028_spin_all.lua ===
__FACTORIES["modules/combat/func_028_spin_all.lua"] = function()
-- Func #028: Spin All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SpinAll", type = "button", name = "Spin All",
    tooltip = "Spin everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local av = Instance.new("BodyAngularVelocity")
                    av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    av.AngularVelocity = Vector3.new(0, 50, 0)
                    av.Parent = hrp
                    Debris:AddItem(av, 3)
                end
            end
        end
    end
}
end

-- === modules/combat/func_029_slow_all.lua ===
__FACTORIES["modules/combat/func_029_slow_all.lua"] = function()
-- Func #029: Slow All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SlowAll", type = "button", name = "Slow All",
    tooltip = "Slow everyone down", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 4 end
            end
        end
    end
}
end

-- === modules/combat/func_030_speed_all.lua ===
__FACTORIES["modules/combat/func_030_speed_all.lua"] = function()
-- Func #030: Speed All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "SpeedAll", type = "button", name = "Speed All",
    tooltip = "Speed everyone up", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 200 end
            end
        end
    end
}
end

-- === modules/combat/func_031_jump_all.lua ===
__FACTORIES["modules/combat/func_031_jump_all.lua"] = function()
-- Func #031: Jump All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JumpAll", type = "button", name = "Jump All",
    tooltip = "Give everyone high jump", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = 500 end
            end
        end
    end
}
end

-- === modules/combat/func_032_reset_all.lua ===
__FACTORIES["modules/combat/func_032_reset_all.lua"] = function()
-- Func #032: Reset All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ResetAll", type = "button", name = "Reset All",
    tooltip = "Reset everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                pcall(function() p.Character:BreakJoints() end)
            end
        end
    end
}
end

-- === modules/combat/func_033_anchor_all.lua ===
__FACTORIES["modules/combat/func_033_anchor_all.lua"] = function()
-- Func #033: Anchor All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AnchorAll", type = "button", name = "Anchor All",
    tooltip = "Anchor everyone", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = true end
            end
        end
    end
}
end

-- === modules/combat/func_034_unanchor_all.lua ===
__FACTORIES["modules/combat/func_034_unanchor_all.lua"] = function()
-- Func #034: Unanchor All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "UnanchorAll", type = "button", name = "Unanchor All",
    tooltip = "Unanchor", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = false end
            end
        end
    end
}
end

-- === modules/combat/func_035_shirt_off_all.lua ===
__FACTORIES["modules/combat/func_035_shirt_off_all.lua"] = function()
-- Func #035: Shirt Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShirtOffAll", type = "button", name = "Shirt Off All",
    tooltip = "Remove shirts", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local s = p.Character:FindFirstChildOfClass("Shirt")
                if s then s:Destroy() end
            end
        end
    end
}
end

-- === modules/combat/func_036_pants_off_all.lua ===
__FACTORIES["modules/combat/func_036_pants_off_all.lua"] = function()
-- Func #036: Pants Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "PantsOffAll", type = "button", name = "Pants Off All",
    tooltip = "Remove pants", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local s = p.Character:FindFirstChildOfClass("Pants")
                if s then s:Destroy() end
            end
        end
    end
}
end

-- === modules/combat/func_037_hats_off_all.lua ===
__FACTORIES["modules/combat/func_037_hats_off_all.lua"] = function()
-- Func #037: Hats Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "HatsOffAll", type = "button", name = "Hats Off All",
    tooltip = "Remove hats", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, a in pairs(p.Character:GetChildren()) do
                    if a:IsA("Accessory") then a:Destroy() end
                end
            end
        end
    end
}
end

-- === modules/combat/func_038_drop_tools_all.lua ===
__FACTORIES["modules/combat/func_038_drop_tools_all.lua"] = function()
-- Func #038: Drop Tools All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "DropToolsAll", type = "button", name = "Drop Tools All",
    tooltip = "Drop tools", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:UnequipTools() end
            end
        end
    end
}
end

-- === modules/combat/func_039_forcefield_off_all.lua ===
__FACTORIES["modules/combat/func_039_forcefield_off_all.lua"] = function()
-- Func #039: Forcefield Off All | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ForcefieldOffAll", type = "button", name = "Forcefield Off All",
    tooltip = "Remove Forcefield", tab = "Combat",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local ff = p.Character:FindFirstChildOfClass("ForceField")
                if ff then ff:Destroy() end
            end
        end
    end
}
end

-- === modules/combat/func_040_character_reset.lua ===
__FACTORIES["modules/combat/func_040_character_reset.lua"] = function()
-- Func #040: Character Reset (Self) | button

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CharacterReset", type = "button", name = "Character Reset (Self)",
    tooltip = "Reset yourself", tab = "Combat",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if char then pcall(function() char:BreakJoints() end) end
    end
}
end

-- === modules/auras/func_041_fling_aura.lua ===
__FACTORIES["modules/auras/func_041_fling_aura.lua"] = function()
-- Func #041: Fling Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local State = { running = false }

return {
    id = "FlingAura", type = "toggle", name = "Fling Aura",
    tooltip = "Automatically fling everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                if not Settings.FlingAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bv.Velocity = Vector3.new(math.random(-500, 500), Settings.FlingPower or 400, math.random(-500, 500))
                            bv.Parent = hrp
                            Debris:AddItem(bv, 0.2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_042_kill_aura.lua ===
__FACTORIES["modules/auras/func_042_kill_aura.lua"] = function()
-- Func #042: Kill Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "KillAura", type = "toggle", name = "Kill Aura",
    tooltip = "Kill everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                if not Settings.KillAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.Health = 0
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_043_freeze_aura.lua ===
__FACTORIES["modules/auras/func_043_freeze_aura.lua"] = function()
-- Func #043: Freeze Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FreezeAura", type = "toggle", name = "Freeze Aura",
    tooltip = "Stop everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                if not Settings.FreezeAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.WalkSpeed = 0
                            hum.JumpPower = 0
                            hrp.Anchored = true
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hrp then hrp.Anchored = false end
                if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
            end
        end
    end
}
end

-- === modules/auras/func_044_fire_aura.lua ===
__FACTORIES["modules/auras/func_044_fire_aura.lua"] = function()
-- Func #044: Fire Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FireAura", type = "toggle", name = "Fire Aura",
    tooltip = "Set everyone within range on fire",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.FireAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            if not hrp:FindFirstChild("ResonanceFire") then
                                local f = Instance.new("Fire")
                                f.Name = "ResonanceFire"
                                f.Size = 5
                                f.Heat = 10
                                f.Parent = hrp
                                Debris:AddItem(f, 3)
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_045_void_aura.lua ===
__FACTORIES["modules/auras/func_045_void_aura.lua"] = function()
-- Func #045: Void Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "VoidAura", type = "toggle", name = "Void Aura",
    tooltip = "Send everyone within range into the void",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.VoidAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = CFrame.new(0, -500, 0)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_046_attraction_aura.lua ===
__FACTORIES["modules/auras/func_046_attraction_aura.lua"] = function()
-- Func #046: Attraction Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "AttractionAura", type = "toggle", name = "Attraction Aura",
    tooltip = "Attract all items to you",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                if not Settings.AttractionAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local owner = Players:GetPlayerFromCharacter(obj.Parent)
                        if not owner then
                            pcall(function()
                                obj.CFrame = myHRP.CFrame + Vector3.new(math.random(-3,3), 3, math.random(-3,3))
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_047_auto_counter.lua ===
__FACTORIES["modules/auras/func_047_auto_counter.lua"] = function()
-- Func #047: Auto-Counter
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "AutoCounter", type = "toggle", name = "Auto-Counter",
    tooltip = "Fling back when someone tries to grab you",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.15)
                if not Settings.AutoCounter then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                if myHRP.Velocity.Magnitude > 80 then
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                            if hrp and (hrp.Position - myHRP.Position).Magnitude < 20 then
                                local bv = Instance.new("BodyVelocity")
                                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                bv.Velocity = Vector3.new(math.random(-500,500), Settings.FlingPower or 400, math.random(-500,500))
                                bv.Parent = hrp
                                Debris:AddItem(bv, 0.25)
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_048_plot_kicker.lua ===
__FACTORIES["modules/auras/func_048_plot_kicker.lua"] = function()
-- Func #048: Plot Kicker
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "PlotKicker", type = "toggle", name = "Plot Kicker",
    tooltip = "Throw intruders off your plot",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.PlotKicker then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = hrp.CFrame + Vector3.new(0, 100, 0)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_049_gravity_aura.lua ===
__FACTORIES["modules/auras/func_049_gravity_aura.lua"] = function()
-- Func #049: Gravity Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "GravityAura", type = "toggle", name = "Gravity Aura",
    tooltip = "Launch players within range upward",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.GravityAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bv.Velocity = Vector3.new(0, -200, 0)
                            bv.Parent = hrp
                            Debris:AddItem(bv, 0.2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_050_spin_aura.lua ===
__FACTORIES["modules/auras/func_050_spin_aura.lua"] = function()
-- Func #050: Spin Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "SpinAura", type = "toggle", name = "Spin Aura",
    tooltip = "Spin everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.SpinAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local av = Instance.new("BodyAngularVelocity")
                            av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                            av.AngularVelocity = Vector3.new(0, (Settings.SpinRPM or 60) / 60 * math.pi * 2, 0)
                            av.Parent = hrp
                            Debris:AddItem(av, 2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_051_damage_aura.lua ===
__FACTORIES["modules/auras/func_051_damage_aura.lua"] = function()
-- Func #051: Damage Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }
local DAMAGE_PER_TICK = 5

return {
    id = "DamageAura", type = "toggle", name = "Damage Aura",
    tooltip = "Damage everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.DamageAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum:TakeDamage(DAMAGE_PER_TICK)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_052_slow_aura.lua ===
__FACTORIES["modules/auras/func_052_slow_aura.lua"] = function()
-- Func #052: Slow Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "SlowAura", type = "toggle", name = "Slow Aura",
    tooltip = "Slow down everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.SlowAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.WalkSpeed = 4
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_053_ragdoll_aura.lua ===
__FACTORIES["modules/auras/func_053_ragdoll_aura.lua"] = function()
-- Func #053: Ragdoll Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "RagdollAura", type = "toggle", name = "Ragdoll Aura",
    tooltip = "Ragdoll players within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.RagdollAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_054_teleport_aura.lua ===
__FACTORIES["modules/auras/func_054_teleport_aura.lua"] = function()
-- Func #054: Teleport Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "TeleportAura", type = "toggle", name = "Teleport Aura",
    tooltip = "Teleport players within range directly to you",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.TeleportAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = myHRP.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_055_blind_aura.lua ===
__FACTORIES["modules/auras/func_055_blind_aura.lua"] = function()
-- Func #055: Blind Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "BlindAura", type = "toggle", name = "Blind Aura",
    tooltip = "Blind everyone within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(1)
                if not Settings.BlindAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            pcall(function()
                                local sg = Instance.new("ScreenGui")
                                sg.Name = "ResonanceBlind"
                                sg.ResetOnSpawn = false
                                local f = Instance.new("Frame", sg)
                                f.Size = UDim2.fromScale(1, 1)
                                f.BackgroundColor3 = Color3.new(0, 0, 0)
                                sg.Parent = p.PlayerGui
                                Debris:AddItem(sg, 2)
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_056_kick_aura.lua ===
__FACTORIES["modules/auras/func_056_kick_aura.lua"] = function()
-- Func #056: Kick Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "KickAura", type = "toggle", name = "Kick Aura (bump)",
    tooltip = "Knock everyone within range away",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.15)
                if not Settings.KickAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            local dir = (hrp.Position - myHRP.Position).Unit
                            local bv = Instance.new("BodyVelocity")
                            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bv.Velocity = dir * 150 + Vector3.new(0, 80, 0)
                            bv.Parent = hrp
                            Debris:AddItem(bv, 0.2)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_057_confuse_aura.lua ===
__FACTORIES["modules/auras/func_057_confuse_aura.lua"] = function()
-- Func #057: Confuse Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ConfuseAura", type = "toggle", name = "Confuse Aura",
    tooltip = "Randomly jerk players within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                if not Settings.ConfuseAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hrp.CFrame = hrp.CFrame * CFrame.new(math.random(-3,3), math.random(-2,2), math.random(-3,3))
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_058_mute_aura.lua ===
__FACTORIES["modules/auras/func_058_mute_aura.lua"] = function()
-- Func #058: Mute Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "MuteAura", type = "toggle", name = "Mute Aura",
    tooltip = "Mute players within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.MuteAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            for _, snd in pairs(p.Character:GetDescendants()) do
                                if snd:IsA("Sound") then snd.Volume = 0 end
                            end
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_059_shrink_aura.lua ===
__FACTORIES["modules/auras/func_059_shrink_aura.lua"] = function()
-- Func #059: Shrink Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ShrinkAura", type = "toggle", name = "Shrink Aura",
    tooltip = "Shrink players within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.ShrinkAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.BodyDepthScale.Value = 0.3
                            hum.BodyWidthScale.Value = 0.3
                            hum.BodyHeightScale.Value = 0.3
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/auras/func_060_grow_aura.lua ===
__FACTORIES["modules/auras/func_060_grow_aura.lua"] = function()
-- Func #060: Grow Aura
-- Category: Auras | Type: toggle

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "GrowAura", type = "toggle", name = "Grow Aura",
    tooltip = "Enlarge players within range",
    tab = "Auras", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                if not Settings.GrowAura then break end
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and not Utils.isWhitelisted(p, Settings) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and (hrp.Position - myHRP.Position).Magnitude <= (Settings.AuraRadius or 15) then
                            hum.BodyDepthScale.Value = 3
                            hum.BodyWidthScale.Value = 3
                            hum.BodyHeightScale.Value = 3
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/protection/func_061_anti_grab.lua ===
__FACTORIES["modules/protection/func_061_anti_grab.lua"] = function()
-- Func #061: Anti-Grab | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local BODY_MOVERS = {
    BodyVelocity=true, BodyPosition=true, BodyGyro=true, BodyAngularVelocity=true,
    BodyForce=true, BodyThrust=true, BodyTorque=true, RocketPropulsion=true,
    VectorForce=true, LinearVelocity=true, AngularVelocity=true,
    AlignPosition=true, AlignOrientation=true, Torque=true
}
local CONSTRAINTS = { WeldConstraint=true, Weld=true, ManualWeld=true, Motor6D=true, Snap=true }
local GRAB_KEYWORDS = {"grab","hold","carry","lift","pickup","fling","throw"}

local State = {
    running = false,
    connections = {},
    grabAttempts = 0,
    weldsRemoved = 0,
    bodyMoversRemoved = 0
}

local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function isOwn(inst)
    if not inst then return false end
    local ok, v = pcall(function() return inst:GetAttribute("ResonanceOwn") end)
    return ok and v == true
end
local function isBodyMover(inst) return BODY_MOVERS[inst.ClassName] == true end
local function isConstraint(inst) return CONSTRAINTS[inst.ClassName] == true end

local function cleanBodyMovers(hrp)
    local n = 0
    for _, o in pairs(hrp:GetChildren()) do
        if isBodyMover(o) and not isOwn(o) then
            if pcall(function() o:Destroy() end) then
                n = n + 1
                State.bodyMoversRemoved = State.bodyMoversRemoved + 1
            end
        end
    end
    return n
end

local function cleanWelds(hrp)
    local n = 0
    local myChar = getChar()
    for _, o in pairs(hrp:GetChildren()) do
        if isConstraint(o) and not isOwn(o) then
            local p0, p1
            if o:IsA("WeldConstraint") then p0 = o.Part0; p1 = o.Part1 end
            local ext = false
            if p0 and not p0:IsDescendantOf(myChar) then ext = true end
            if p1 and not p1:IsDescendantOf(myChar) then ext = true end
            if ext then
                pcall(function() o:Destroy() end)
                n = n + 1
                State.weldsRemoved = State.weldsRemoved + 1
            end
        end
    end
    return n
end

local function detectVelocity(hrp)
    local v = hrp.AssemblyLinearVelocity
    if v.Magnitude > 100 then
        local vy = v.Y
        if math.abs(vy) < 200 then
            hrp.AssemblyLinearVelocity = Vector3.new(0, vy * 0.3, 0)
        else
            hrp.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
        end
        State.grabAttempts = State.grabAttempts + 1
    end
end

local function detectAngular(hrp)
    if hrp.AssemblyAngularVelocity.Magnitude > 30 then
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        State.grabAttempts = State.grabAttempts + 1
    end
end

local function loop()
    while State.running do
        task.wait(0.05)
        local hrp = getHRP()
        if not hrp then continue end
        cleanBodyMovers(hrp)
        cleanWelds(hrp)
        detectVelocity(hrp)
        detectAngular(hrp)
    end
end

return {
    id = "AntiGrab", type = "toggle", name = "Anti-Grab",
    tooltip = "Layered grab protection", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.grabAttempts = 0
        State.weldsRemoved = 0
        State.bodyMoversRemoved = 0
        State.connections = {}
        task.spawn(loop)
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
        end))
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function()
        return { grabAttempts = State.grabAttempts, weldsRemoved = State.weldsRemoved, bodyMoversRemoved = State.bodyMoversRemoved }
    end
}
end

-- === modules/protection/func_062_anti_fling.lua ===
__FACTORIES["modules/protection/func_062_anti_fling.lua"] = function()
-- Func #062: Anti-Fling | toggle
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, conn = nil, blocked = 0 }
local MAX_VEL = 120
local MAX_ANG = 40

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function stabilize(hrp, hard)
    if hard then
        hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y * 0.1, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = CFrame.new(hrp.Position)
    else
        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * 0.4
        hrp.AssemblyAngularVelocity = hrp.AssemblyAngularVelocity * 0.4
    end
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end

    local v = hrp.AssemblyLinearVelocity.Magnitude
    local a = hrp.AssemblyAngularVelocity.Magnitude

    if v > MAX_VEL or a > MAX_ANG then
        State.blocked = State.blocked + 1
        stabilize(hrp, v > MAX_VEL * 2)
        for _, o in pairs(hrp:GetChildren()) do
            if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity") or o:IsA("BodyGyro") then
                if not o:GetAttribute("ResonanceOwn") then
                    pcall(function() o:Destroy() end)
                end
            end
        end
    end
end

return {
    id = "AntiFling", type = "toggle", name = "Anti-Fling",
    tooltip = "Protection against flinging", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { blocked = State.blocked } end
}
end

-- === modules/protection/func_063_anti_freeze.lua ===
__FACTORIES["modules/protection/func_063_anti_freeze.lua"] = function()
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
end

-- === modules/protection/func_064_anti_ragdoll.lua ===
__FACTORIES["modules/protection/func_064_anti_ragdoll.lua"] = function()
-- Func #064: Anti-Ragdoll | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local RAGDOLL_STATES = {
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll] = true
}

local State = { running = false, blocks = 0, connections = {} }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum.StateChanged:Connect(function(_, newState)
        if not State.running then return end
        if RAGDOLL_STATES[newState] then
            task.defer(function()
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end)
            State.blocks = State.blocks + 1
        end
    end)
    table.insert(State.connections, conn)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
end

local function loop()
    while State.running do
        task.wait(0.1)
        local hum = getHum()
        if hum then
            local st = hum:GetState()
            if RAGDOLL_STATES[st] then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                State.blocks = State.blocks + 1
            end
        end
    end
end

return {
    id = "AntiRagdoll", type = "toggle", name = "Anti-Ragdoll",
    tooltip = "Prevent ragdoll", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocks = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        local hum = getHum()
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end)
        end
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { blocks = State.blocks } end
}
end

-- === modules/protection/func_065_anti_void.lua ===
__FACTORIES["modules/protection/func_065_anti_void.lua"] = function()
-- Func #065: Anti-Void | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local State = {
    running = false,
    conn = nil,
    lastSafeCFrame = nil,
    recoveries = 0,
    lastRecovery = 0
}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function saveSafe(hrp)
    if hrp.Position.Y > 10 then
        State.lastSafeCFrame = hrp.CFrame
    end
end

local function recover(hrp)
    if tick() - State.lastRecovery < 1 then return end
    hrp.CFrame = State.lastSafeCFrame or CFrame.new(0, 50, 0)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    State.recoveries = State.recoveries + 1
    State.lastRecovery = tick()
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end
    local y = hrp.Position.Y
    if y > 10 then saveSafe(hrp) end
    if y < -30 then
        if hrp.AssemblyLinearVelocity.Y < -100 then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -50, hrp.AssemblyLinearVelocity.Z)
        end
    end
    if y < -100 then recover(hrp) end
end

return {
    id = "AntiVoid", type = "toggle", name = "Anti-Void",
    tooltip = "Automatically return after falling", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.recoveries = 0
        State.lastSafeCFrame = nil
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { recoveries = State.recoveries } end
}
end

-- === modules/protection/func_066_anti_vote_kick.lua ===
__FACTORIES["modules/protection/func_066_anti_vote_kick.lua"] = function()
-- Func #066: Anti-Vote Kick | toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local VOTE_KEYWORDS = {"vote","kick","ban","votekick"}
local State = { running = false, connections = {}, blocked = 0, destroyed = 0, hookRef = nil, remotes = {} }

local function matchKeywords(name)
    local l = name:lower()
    for _, kw in ipairs(VOTE_KEYWORDS) do if l:find(kw) then return true end end
    return false
end

local function blockReset()
    pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
end

local function scanRemotes()
    State.remotes = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            if matchKeywords(obj.Name) then table.insert(State.remotes, obj) end
        end
    end
end

local function installHook()
    if not hookmetamethod or not getnamecallmethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        local m = getnamecallmethod()
        if m == "FireServer" or m == "InvokeServer" then
            for _, r in ipairs(State.remotes) do
                if self == r then
                    for _, a in ipairs({...}) do
                        if typeof(a) == "Instance" and (a == LocalPlayer or a == LocalPlayer.Character) then
                            State.blocked = State.blocked + 1
                            return nil
                        elseif type(a) == "string" and a:lower() == LocalPlayer.Name:lower() then
                            State.blocked = State.blocked + 1
                            return nil
                        end
                    end
                    break
                end
            end
        end
        return old(self, ...)
    end)
    State.hookRef = old
end

local function monitorUI()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    table.insert(State.connections, pg.ChildAdded:Connect(function(gui)
        if not State.running then return end
        if matchKeywords(gui.Name) then
            task.wait(0.05)
            pcall(function() gui:Destroy() end)
            State.destroyed = State.destroyed + 1
        end
    end))
end

local function loop()
    while State.running do
        task.wait(2)
        scanRemotes()
        blockReset()
    end
end

return {
    id = "AntiVoteKick", type = "toggle", name = "Anti-Vote Kick",
    tooltip = "Block votes against you", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.destroyed = 0
        State.connections = {}
        blockReset()
        scanRemotes()
        installHook()
        monitorUI()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
        State.hookRef = nil
        pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
    end,
    getStats = function() return { blocked = State.blocked, destroyed = State.destroyed } end
}
end

-- === modules/protection/func_067_anti_kick.lua ===
__FACTORIES["modules/protection/func_067_anti_kick.lua"] = function()
-- Func #067: Anti-Kick | toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local KICK_KEYWORDS = {"kick","ban","remove","votekick","modkick","kickplayer","banplayer","moderation","punish"}
local State = { running = false, hooks = {}, connections = {}, blocked = 0, remotes = {} }

local function matchKeywords(name)
    local l = name:lower()
    for _, kw in ipairs(KICK_KEYWORDS) do if l:find(kw) then return true end end
    return false
end

local function isKickRemote(obj)
    if not (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then return false end
    return matchKeywords(obj.Name)
end

local function installNamecallHook()
    if not hookmetamethod or not getnamecallmethod then return false end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        local m = getnamecallmethod()
        if m == "Kick" then
            State.blocked = State.blocked + 1
            return nil
        end
        if m == "FireServer" or m == "InvokeServer" then
            for _, a in ipairs({...}) do
                if type(a) == "string" then
                    local lower = a:lower()
                    if lower:find("kick") or lower:find("ban") or lower:find("remove") then
                        State.blocked = State.blocked + 1
                        return nil
                    end
                end
            end
        end
        return old(self, ...)
    end)
    table.insert(State.hooks, old)
    return true
end

local function installIndexHook()
    if not hookmetamethod then return end
    local old
    old = hookmetamethod(game, "__index", function(self, key)
        if not State.running then return old(self, key) end
        if key == "Kick" or key == "Ban" then return function() end end
        return old(self, key)
    end)
    table.insert(State.hooks, old)
end

local function scanRemotes()
    State.remotes = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if isKickRemote(obj) then table.insert(State.remotes, obj) end
    end
end

local function monitorNewRemotes()
    local conn = ReplicatedStorage.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if isKickRemote(obj) then table.insert(State.remotes, obj) end
    end)
    table.insert(State.connections, conn)
end

local function blockReset()
    pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
    task.spawn(function()
        while State.running do
            task.wait(1)
            pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
        end
    end)
end

return {
    id = "AntiKick", type = "toggle", name = "Anti-Kick",
    tooltip = "Layered kick protection", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.blocked = 0
        State.hooks = {}
        State.connections = {}
        installNamecallHook()
        installIndexHook()
        scanRemotes()
        monitorNewRemotes()
        blockReset()
    end,
    onDisable = function()
        State.running = false
        for _, h in ipairs(State.hooks) do
            if type(h) == "userdata" and h.Disconnect then pcall(function() h:Disconnect() end) end
        end
        State.hooks = {}
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { blocked = State.blocked } end
}
end

-- === modules/protection/func_068_anti_teleport.lua ===
__FACTORIES["modules/protection/func_068_anti_teleport.lua"] = function()
-- Func #068: Anti-Teleport | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local State = {
    running = false,
    conn = nil,
    lastPos = nil,
    lastCFrame = nil,
    allowedUntil = 0,
    graceUntil = 0,
    reversals = 0
}

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isMoving()
    return UserInputService:IsKeyDown(Enum.KeyCode.W)
        or UserInputService:IsKeyDown(Enum.KeyCode.A)
        or UserInputService:IsKeyDown(Enum.KeyCode.S)
        or UserInputService:IsKeyDown(Enum.KeyCode.D)
        or UserInputService:IsKeyDown(Enum.KeyCode.Space)
end

local function allowTeleport(duration)
    State.allowedUntil = tick() + (duration or 1)
end

local function onHeartbeat()
    if not State.running then return end
    local hrp = getHRP()
    if not hrp then return end

    local pos = hrp.Position
    local t = tick()

    if t < State.allowedUntil then
        State.lastPos = pos
        State.lastCFrame = hrp.CFrame
        return
    end

    if State.lastPos then
        local delta = (pos - State.lastPos).Magnitude
        if delta > 30 and t > State.graceUntil and not isMoving() then
            if State.lastCFrame then
                hrp.CFrame = State.lastCFrame
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                State.reversals = State.reversals + 1
                State.graceUntil = t + 0.3
            end
        else
            State.lastPos = pos
            State.lastCFrame = hrp.CFrame
        end
    else
        State.lastPos = pos
        State.lastCFrame = hrp.CFrame
    end
end

return {
    id = "AntiTeleport", type = "toggle", name = "Anti-Teleport",
    tooltip = "Detect and reverse external teleports", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lastPos = nil
        State.lastCFrame = nil
        State.reversals = 0
        State.allowedUntil = 0
        State.graceUntil = 0
        State.conn = RunService.Heartbeat:Connect(onHeartbeat)
        _G.ResonanceAllowTeleport = allowTeleport
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        _G.ResonanceAllowTeleport = nil
    end,
    getStats = function() return { reversals = State.reversals } end,
    allowTeleport = allowTeleport
}
end

-- === modules/protection/func_069_anti_sit.lua ===
__FACTORIES["modules/protection/func_069_anti_sit.lua"] = function()
-- Func #069: Anti-Sit | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, sitBlocked = 0, weldsRemoved = 0 }

local function getChar() return LocalPlayer.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function cleanSeatWelds(char)
    if not char then return end
    for _, obj in pairs(char:GetChildren()) do
        if obj:IsA("Weld") and obj.Name == "SeatWeld" then
            pcall(function() obj:Destroy() end)
            State.weldsRemoved = State.weldsRemoved + 1
        end
    end
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum:GetPropertyChangedSignal("Sit"):Connect(function()
        if not State.running then return end
        if hum.Sit then
            hum.Sit = false
            hum.Jump = true
            State.sitBlocked = State.sitBlocked + 1
        end
    end)
    table.insert(State.connections, conn)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Sitting, false) end)
end

local function loop()
    while State.running do
        task.wait(0.05)
        local char = getChar(); if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Sit then
            hum.Sit = false
            hum.Jump = true
            State.sitBlocked = State.sitBlocked + 1
        end
        cleanSeatWelds(char)
    end
end

return {
    id = "AntiSit", type = "toggle", name = "Anti-Sit",
    tooltip = "Prevent being seated", tab = "Protection", default = true,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.sitBlocked = 0
        State.weldsRemoved = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
        local hum = getHum()
        if hum then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Sitting, true) end)
        end
    end,
    getStats = function() return { sitBlocked = State.sitBlocked, weldsRemoved = State.weldsRemoved } end
}
end

-- === modules/protection/func_070_anti_burn.lua ===
__FACTORIES["modules/protection/func_070_anti_burn.lua"] = function()
-- Func #070: Anti-Burn | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PARTICLE_WHITELIST = {
    ["Fire"] = true, ["Smoke"] = true, ["Sparkles"] = true,
    ["ParticleEmitter"] = true, ["Trail"] = true, ["Beam"] = true,
    ["PointLight"] = true, ["SpotLight"] = true, ["SurfaceLight"] = true
}

local State = { running = false, connections = {}, cleared = 0 }

local function getChar() return LocalPlayer.Character end

local function shouldClear(obj)
    return PARTICLE_WHITELIST[obj.ClassName] == true
end

local function clearEffects(char)
    if not char then return end
    for _, obj in pairs(char:GetDescendants()) do
        if shouldClear(obj) then
            pcall(function() obj:Destroy() end)
            State.cleared = State.cleared + 1
        end
    end
end

local function bindChar(char)
    if not char then return end
    local conn = char.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if shouldClear(obj) then
            task.wait(0.05)
            if obj.Parent then
                pcall(function() obj:Destroy() end)
                State.cleared = State.cleared + 1
            end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(0.2)
        clearEffects(getChar())
    end
end

return {
    id = "AntiBurn", type = "toggle", name = "Anti-Burn",
    tooltip = "Remove fire and effects from your character", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.cleared = 0
        State.connections = {}
        bindChar(getChar())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindChar(c)
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { cleared = State.cleared } end
}
end

-- === modules/protection/func_071_anti_explosion.lua ===
__FACTORIES["modules/protection/func_071_anti_explosion.lua"] = function()
-- Func #071: Anti-Explosion | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, neutralized = 0 }
local DESTROY_RADIUS = 60

local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function neutralize(explosion)
    pcall(function()
        explosion.BlastPressure = 0
        explosion.BlastRadius = 0
        explosion:Destroy()
    end)
    State.neutralized = State.neutralized + 1
end

local function scan()
    local hrp = getHRP(); if not hrp then return end
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Explosion") then
            if (obj.Position - hrp.Position).Magnitude < DESTROY_RADIUS then neutralize(obj) end
        end
    end
end

local function monitor()
    local conn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if obj:IsA("Explosion") then
            task.wait(0.02)
            local hrp = getHRP(); if not hrp then return end
            if (obj.Position - hrp.Position).Magnitude < DESTROY_RADIUS then neutralize(obj) end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(0.1)
        scan()
    end
end

return {
    id = "AntiExplosion", type = "toggle", name = "Anti-Explosion",
    tooltip = "Neutralize nearby explosions", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.neutralized = 0
        State.connections = {}
        monitor()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { neutralized = State.neutralized } end
}
end

-- === modules/protection/func_072_anti_damage.lua ===
__FACTORIES["modules/protection/func_072_anti_damage.lua"] = function()
-- Func #072: Anti-Damage | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, connections = {}, heals = 0, damagesBlocked = 0, hookRef = nil }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function bindHumanoid(hum)
    if not hum then return end
    local conn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not State.running then return end
        if hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
            State.heals = State.heals + 1
        end
    end)
    table.insert(State.connections, conn)
end

local function installHook()
    if not hookmetamethod or not getnamecallmethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.running then return old(self, ...) end
        if getnamecallmethod() == "TakeDamage" and self == getHum() then
            State.damagesBlocked = State.damagesBlocked + 1
            return nil
        end
        return old(self, ...)
    end)
    State.hookRef = old
end

local function loop()
    while State.running do
        task.wait(0.1)
        local hum = getHum()
        if hum and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
            State.heals = State.heals + 1
        end
    end
end

return {
    id = "AntiDamage", type = "toggle", name = "Anti-Damage",
    tooltip = "Prevent damage", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.heals = 0
        State.damagesBlocked = 0
        State.connections = {}
        bindHumanoid(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            bindHumanoid(c:FindFirstChildOfClass("Humanoid"))
        end))
        installHook()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        State.hookRef = nil
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { heals = State.heals, damagesBlocked = State.damagesBlocked } end
}
end

-- === modules/protection/func_073_anti_slow.lua ===
__FACTORIES["modules/protection/func_073_anti_slow.lua"] = function()
-- Func #073: Anti-Slow | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, wsRestores = 0, jpRestores = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.05)
        local hum = getHum(); if not hum then continue end
        if hum.WalkSpeed < 16 then
            hum.WalkSpeed = 16
            State.wsRestores = State.wsRestores + 1
        end
        if hum.JumpPower < 50 then
            hum.JumpPower = 50
            State.jpRestores = State.jpRestores + 1
        end
    end
end

return {
    id = "AntiSlow", type = "toggle", name = "Anti-Slow",
    tooltip = "Protection against speed reduction", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.wsRestores = 0
        State.jpRestores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { wsRestores = State.wsRestores, jpRestores = State.jpRestores } end
}
end

-- === modules/protection/func_074_anti_fire_touch.lua ===
__FACTORIES["modules/protection/func_074_anti_fire_touch.lua"] = function()
-- Func #074: Anti-Fire Touch | toggle
local Workspace = game:GetService("Workspace")

local FIRE_KEYWORDS = {"fire","flame","lava","burn","torch"}
local State = { running = false, connections = {}, disabled = 0 }

local function isFirePart(part)
    if not part:IsA("BasePart") then return false end
    local lower = part.Name:lower()
    for _, kw in ipairs(FIRE_KEYWORDS) do if lower:find(kw) then return true end end
    return false
end

local function disableTouch(part)
    if part.CanTouch then
        part.CanTouch = false
        State.disabled = State.disabled + 1
    end
end

local function scan()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if isFirePart(obj) then disableTouch(obj) end
    end
end

local function monitor()
    local conn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.running then return end
        if isFirePart(obj) then
            task.wait(0.05)
            if obj.Parent then disableTouch(obj) end
        end
    end)
    table.insert(State.connections, conn)
end

local function loop()
    while State.running do
        task.wait(1)
        scan()
    end
end

return {
    id = "AntiFireTouch", type = "toggle", name = "Anti-Fire Touch",
    tooltip = "Prevent fire from touching you", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.disabled = 0
        State.connections = {}
        scan()
        monitor()
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { disabled = State.disabled } end
}
end

-- === modules/protection/func_075_anti_gravity.lua ===
__FACTORIES["modules/protection/func_075_anti_gravity.lua"] = function()
-- Func #075: Anti-Gravity | toggle
local Workspace = game:GetService("Workspace")

local State = { running = false, conn = nil, restores = 0 }
local BASE = 196.2

local function restore()
    if math.abs(Workspace.Gravity - BASE) > 5 then
        Workspace.Gravity = BASE
        State.restores = State.restores + 1
    end
end

local function loop()
    while State.running do
        task.wait(0.5)
        restore()
    end
end

return {
    id = "AntiGravity", type = "toggle", name = "Anti-Gravity",
    tooltip = "Protection against gravity changes", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.restores = 0
        State.conn = Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
            if State.running then restore() end
        end)
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end,
    getStats = function() return { restores = State.restores } end
}
end

-- === modules/protection/func_076_anti_shrink.lua ===
__FACTORIES["modules/protection/func_076_anti_shrink.lua"] = function()
-- Func #076: Anti-Shrink | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, restores = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.2)
        local hum = getHum(); if not hum then continue end
        local r = false
        if hum.BodyDepthScale.Value < 0.95 then hum.BodyDepthScale.Value = 1; r = true end
        if hum.BodyWidthScale.Value < 0.95 then hum.BodyWidthScale.Value = 1; r = true end
        if hum.BodyHeightScale.Value < 0.95 then hum.BodyHeightScale.Value = 1; r = true end
        if r then State.restores = State.restores + 1 end
    end
end

return {
    id = "AntiShrink", type = "toggle", name = "Anti-Shrink",
    tooltip = "Prevent character shrinking", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.restores = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { restores = State.restores } end
}
end

-- === modules/protection/func_077_noclip.lua ===
__FACTORIES["modules/protection/func_077_noclip.lua"] = function()
-- Func #077: Noclip | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, conn = nil, saved = {}, lastChar = nil }

local function saveCollide(char)
    State.saved = {}
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            State.saved[part] = part.CanCollide
        end
    end
end

local function restore()
    for part, state in pairs(State.saved) do
        if part and part.Parent then
            pcall(function() part.CanCollide = state end)
        end
    end
    State.saved = {}
end

local function onStep()
    if not State.running then return end
    local char = LocalPlayer.Character
    if not char then return end
    if char ~= State.lastChar then
        State.lastChar = char
        saveCollide(char)
    end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanCollide then
            part.CanCollide = false
        end
    end
end

return {
    id = "NoclipProt", type = "toggle", name = "Noclip",
    tooltip = "Walk through walls", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lastChar = nil
        State.conn = RunService.Stepped:Connect(onStep)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        restore()
    end
}
end

-- === modules/protection/func_078_infinite_yield.lua ===
__FACTORIES["modules/protection/func_078_infinite_yield.lua"] = function()
-- Func #078: Infinite Yield | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, respawns = 0, lastDeath = 0 }

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.5)
        local hum = getHum()
        if hum and hum.Health <= 0 then
            if tick() - State.lastDeath > 0.5 then
                State.lastDeath = tick()
                pcall(function() LocalPlayer:LoadCharacter() end)
                State.respawns = State.respawns + 1
            end
        end
    end
end

return {
    id = "InfiniteYield", type = "toggle", name = "Infinite Yield",
    tooltip = "Automatically respawn on death", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.respawns = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { respawns = State.respawns } end
}
end

-- === modules/protection/func_079_god_mode.lua ===
__FACTORIES["modules/protection/func_079_god_mode.lua"] = function()
-- Func #079: God Mode | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, heals = 0, connections = {} }
local MAX_HP = 1000000

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function applyGod(hum)
    if not hum then return end
    pcall(function()
        hum.MaxHealth = MAX_HP
        if hum.Health < MAX_HP then
            hum.Health = MAX_HP
            State.heals = State.heals + 1
        end
        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
    end)
end

local function loop()
    while State.running do
        task.wait(0.1)
        applyGod(getHum())
    end
end

return {
    id = "GodMode", type = "toggle", name = "God Mode",
    tooltip = "Invincibility", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.heals = 0
        State.connections = {}
        applyGod(getHum())
        table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            applyGod(c:FindFirstChildOfClass("Humanoid"))
        end))
        task.spawn(loop)
    end,
    onDisable = function()
        State.running = false
        local hum = getHum()
        if hum then
            pcall(function()
                hum.MaxHealth = 100
                hum.Health = 100
                hum.NameDisplayDistance = 100
                hum.HealthDisplayDistance = 100
            end)
        end
        for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
        State.connections = {}
    end,
    getStats = function() return { heals = State.heals } end
}
end

-- === modules/protection/func_080_rejoin_on_damage.lua ===
__FACTORIES["modules/protection/func_080_rejoin_on_damage.lua"] = function()
-- Func #080: Rejoin on Damage | toggle
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, triggered = false, lastHP = 100 }
local THRESHOLD = 50

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function loop()
    while State.running do
        task.wait(0.2)
        local hum = getHum(); if not hum then continue end
        local hp = hum.Health
        local maxHP = hum.MaxHealth

        if hp <= 0 and not State.triggered then
            State.triggered = true
            task.wait(1)
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            break
        end

        if maxHP > 0 then
            local percent = (hp / maxHP) * 100
            if percent < THRESHOLD and State.lastHP >= THRESHOLD and not State.triggered then
                State.triggered = true
                task.wait(1)
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
                break
            end
        end

        State.lastHP = hp
    end
end

return {
    id = "RejoinDamage", type = "toggle", name = "Rejoin on Damage",
    tooltip = "Rejoin when damaged", tab = "Protection", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.triggered = false
        State.lastHP = 100
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { triggered = State.triggered } end
}
end

-- === modules/targeting/func_081_loop_kill.lua ===
__FACTORIES["modules/targeting/func_081_loop_kill.lua"] = function()
-- Func #081: Loop Kill | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopKill", type = "toggle", name = "Loop Kill",
    tooltip = "Repeatedly kill the selected target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait((Settings.LoopDelay or 100) / 1000)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hum = target.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/targeting/func_082_loop_burn.lua ===
__FACTORIES["modules/targeting/func_082_loop_burn.lua"] = function()
-- Func #082: Loop Burn | toggle
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopBurn", type = "toggle", name = "Loop Burn",
    tooltip = "Repeatedly set the target on fire", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and not hrp:FindFirstChild("ResonanceFire") then
                        local f = Instance.new("Fire")
                        f.Name = "ResonanceFire"
                        f.Parent = hrp
                        Debris:AddItem(f, 1)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/targeting/func_083_loop_fling.lua ===
__FACTORIES["modules/targeting/func_083_loop_fling.lua"] = function()
-- Func #083: Loop Fling | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopFling", type = "toggle", name = "Loop Fling",
    tooltip = "Repeatedly fling the target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.2)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then Utils.fling(hrp, Settings.FlingPower or 400) end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/targeting/func_084_loop_freeze.lua ===
__FACTORIES["modules/targeting/func_084_loop_freeze.lua"] = function()
-- Func #084: Loop Freeze | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopFreeze", type = "toggle", name = "Loop Freeze",
    tooltip = "Repeatedly freeze the target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    local hum = target.Character:FindFirstChildOfClass("Humanoid")
                    if hrp then hrp.Anchored = true end
                    if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if target and target.Character then
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            local hum = target.Character:FindFirstChildOfClass("Humanoid")
            if hrp then hrp.Anchored = false end
            if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
        end
    end
}
end

-- === modules/targeting/func_085_loop_void.lua ===
__FACTORIES["modules/targeting/func_085_loop_void.lua"] = function()
-- Func #085: Loop Void | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "LoopVoid", type = "toggle", name = "Loop Void",
    tooltip = "Repeatedly send the target into the void", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local name = Settings.TargetName or Settings.TargetPlayerName
                if not name or name == "" then continue end
                local target = Players:FindFirstChild(name)
                if target and target.Character then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/targeting/func_086_follow_target.lua ===
__FACTORIES["modules/targeting/func_086_follow_target.lua"] = function()
-- Func #086: Follow Target | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "FollowTarget", type = "toggle", name = "Follow Target",
    tooltip = "Follow the target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function()
            if not State.running then return end
            local name = Settings.TargetName or Settings.TargetPlayerName
            if not name or name == "" then return end
            local target = Players:FindFirstChild(name)
            if not target or not target.Character then return end
            local thrp = target.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = Utils.getHRP()
            if thrp and myHRP then
                local dir = (thrp.Position - myHRP.Position).Unit
                myHRP.CFrame = CFrame.new(myHRP.Position, myHRP.Position + dir)
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}
end

-- === modules/targeting/func_087_view_target.lua ===
__FACTORIES["modules/targeting/func_087_view_target.lua"] = function()
-- Func #087: View Target | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "ViewTarget", type = "toggle", name = "View Target",
    tooltip = "Spectate the target", tab = "Targeting", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            local name = Settings.TargetName or Settings.TargetPlayerName
            if not name or name == "" then return end
            local target = Players:FindFirstChild(name)
            if not target or not target.Character then return end
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}
end

-- === modules/targeting/func_088_tp_to_target.lua ===
__FACTORIES["modules/targeting/func_088_tp_to_target.lua"] = function()
-- Func #088: TP to Target | button
local Players = game:GetService("Players")

return {
    id = "TpToTarget", type = "button", name = "TP to Target",
    tooltip = "Teleport to target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 3, 0)) end
    end
}
end

-- === modules/targeting/func_089_tp_target_to_me.lua ===
__FACTORIES["modules/targeting/func_089_tp_target_to_me.lua"] = function()
-- Func #089: TP Target to Me | button
local Players = game:GetService("Players")

return {
    id = "TpTargetToMe", type = "button", name = "TP Target to Me",
    tooltip = "Teleport the target to you", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local thrp = target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Utils.getHRP()
        if thrp and myHRP then
            thrp.CFrame = myHRP.CFrame + Vector3.new(0, 3, 0)
        end
    end
}
end

-- === modules/targeting/func_090_kill_target.lua ===
__FACTORIES["modules/targeting/func_090_kill_target.lua"] = function()
-- Func #090: Kill Target | button
local Players = game:GetService("Players")

return {
    id = "KillTarget", type = "button", name = "Kill Target",
    tooltip = "Kill the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
}
end

-- === modules/targeting/func_091_fling_target.lua ===
__FACTORIES["modules/targeting/func_091_fling_target.lua"] = function()
-- Func #091: Fling Target | button
local Players = game:GetService("Players")

return {
    id = "FlingTarget", type = "button", name = "Fling Target",
    tooltip = "Fling the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.fling(hrp, Settings.FlingPower or 400) end
    end
}
end

-- === modules/targeting/func_092_freeze_target.lua ===
__FACTORIES["modules/targeting/func_092_freeze_target.lua"] = function()
-- Func #092: Freeze Target | button
local Players = game:GetService("Players")

return {
    id = "FreezeTarget", type = "button", name = "Freeze Target",
    tooltip = "Freeze the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hrp then hrp.Anchored = true end
        if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
    end
}
end

-- === modules/targeting/func_093_void_target.lua ===
__FACTORIES["modules/targeting/func_093_void_target.lua"] = function()
-- Func #093: Void Target | button
local Players = game:GetService("Players")

return {
    id = "VoidTarget", type = "button", name = "Void Target",
    tooltip = "Send the target into the void", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
    end
}
end

-- === modules/targeting/func_094_sky_target.lua ===
__FACTORIES["modules/targeting/func_094_sky_target.lua"] = function()
-- Func #094: Sky Target | button
local Players = game:GetService("Players")

return {
    id = "SkyTarget", type = "button", name = "Sky Target",
    tooltip = "Send the target into the sky", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(0, 500, 0) end
    end
}
end

-- === modules/targeting/func_095_spin_target.lua ===
__FACTORIES["modules/targeting/func_095_spin_target.lua"] = function()
-- Func #095: Spin Target | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "SpinTarget", type = "button", name = "Spin Target",
    tooltip = "Spin the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local av = Instance.new("BodyAngularVelocity")
            av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            av.AngularVelocity = Vector3.new(0, 100, 0)
            av.Parent = hrp
            Debris:AddItem(av, 5)
        end
    end
}
end

-- === modules/targeting/func_096_orbit_target.lua ===
__FACTORIES["modules/targeting/func_096_orbit_target.lua"] = function()
-- Func #096: Orbit Target | button
local Players = game:GetService("Players")

return {
    id = "OrbitTarget", type = "button", name = "Orbit Target",
    tooltip = "Make the target orbit you", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local thrp = target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Utils.getHRP()
        if not thrp or not myHRP then return end
        task.spawn(function()
            for i = 1, 200 do
                if not thrp.Parent then break end
                local angle = i * 0.2
                local r = Settings.SpinRadius or 5
                thrp.CFrame = myHRP.CFrame * CFrame.new(math.cos(angle) * r, 3, math.sin(angle) * r)
                task.wait(0.05)
            end
        end)
    end
}
end

-- === modules/targeting/func_097_ragdoll_target.lua ===
__FACTORIES["modules/targeting/func_097_ragdoll_target.lua"] = function()
-- Func #097: Ragdoll Target | button
local Players = game:GetService("Players")

return {
    id = "RagdollTarget", type = "button", name = "Ragdoll Target",
    tooltip = "Ragdoll the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        end
    end
}
end

-- === modules/targeting/func_098_blind_target.lua ===
__FACTORIES["modules/targeting/func_098_blind_target.lua"] = function()
-- Func #098: Blind Target | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "BlindTarget", type = "button", name = "Blind Target",
    tooltip = "Blind the target", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target then return end
        pcall(function()
            local sg = Instance.new("ScreenGui")
            sg.Name = "ResonanceBlind"
            sg.ResetOnSpawn = false
            local f = Instance.new("Frame", sg)
            f.Size = UDim2.fromScale(1, 1)
            f.BackgroundColor3 = Color3.new(0, 0, 0)
            sg.Parent = target.PlayerGui
            Debris:AddItem(sg, 5)
        end)
    end
}
end

-- === modules/targeting/func_099_steal_target_tools.lua ===
__FACTORIES["modules/targeting/func_099_steal_target_tools.lua"] = function()
-- Func #099: Steal Target Tools | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "StealTargetTools", type = "button", name = "Steal Target Tools",
    tooltip = "Steal the target's tools", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        for _, t in pairs(target.Character:GetChildren()) do
            if t:IsA("Tool") then
                pcall(function() t.Parent = myChar end)
            end
        end
    end
}
end

-- === modules/targeting/func_100_copy_target_skin.lua ===
__FACTORIES["modules/targeting/func_100_copy_target_skin.lua"] = function()
-- Func #100: Copy Target Skin | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CopyTargetSkin", type = "button", name = "Copy Target Skin",
    tooltip = "Copy the target character's colors", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        for _, part in pairs(myChar:GetChildren()) do
            if part:IsA("BasePart") then
                local src = target.Character:FindFirstChild(part.Name)
                if src and src:IsA("BasePart") then
                    part.Color = src.Color
                    part.Material = src.Material
                end
            end
        end
    end
}
end

-- === modules/movement/func_101_infinite_jump.lua ===
__FACTORIES["modules/movement/func_101_infinite_jump.lua"] = function()
-- Func #101: Infinite Jump | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "InfiniteJump", type = "toggle", name = "Infinite Jump",
    tooltip = "Jump in midair", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceInfJumpConn = UserInputService.JumpRequest:Connect(function()
            if not Settings.InfiniteJump then return end
            local hum = Utils.getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end,
    onDisable = function()
        if _G.ResonanceInfJumpConn then
            _G.ResonanceInfJumpConn:Disconnect()
            _G.ResonanceInfJumpConn = nil
        end
    end
}
end

-- === modules/movement/func_102_noclip.lua ===
__FACTORIES["modules/movement/func_102_noclip.lua"] = function()
-- Func #102: Noclip | toggle
local RunService = game:GetService("RunService")

return {
    id = "NoclipMove", type = "toggle", name = "Noclip",
    tooltip = "Walk through walls", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceNoclipConn = RunService.Stepped:Connect(function()
            if not Settings.NoclipMove then return end
            local char = Utils.getChar()
            if not char then return end
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    end,
    onDisable = function()
        if _G.ResonanceNoclipConn then
            _G.ResonanceNoclipConn:Disconnect()
            _G.ResonanceNoclipConn = nil
        end
        local char = Utils.getChar()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end
}
end

-- === modules/movement/func_103_fly.lua ===
__FACTORIES["modules/movement/func_103_fly.lua"] = function()
-- Func #103: Fly | toggle
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera

local bv, bg

return {
    id = "Fly", type = "toggle", name = "Fly",
    tooltip = "Fly (WASD + Space/LCTRL)", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end

        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp

        bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 1000
        bg.D = 50
        bg.Parent = hrp

        _G.ResonanceFlyConn = RunService.RenderStepped:Connect(function()
            if not Settings.Fly then return end
            local char = Utils.getChar()
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root or not bv then return end
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            bv.Velocity = moveDir * (Settings.FlySpeed or 50)
            bg.CFrame = Camera.CFrame
        end)
    end,
    onDisable = function()
        if bv then bv:Destroy(); bv = nil end
        if bg then bg:Destroy(); bg = nil end
        if _G.ResonanceFlyConn then
            _G.ResonanceFlyConn:Disconnect()
            _G.ResonanceFlyConn = nil
        end
    end
}
end

-- === modules/movement/func_104_speed_boost.lua ===
__FACTORIES["modules/movement/func_104_speed_boost.lua"] = function()
-- Func #104: Speed Boost | toggle
return {
    id = "SpeedBoost", type = "toggle", name = "Speed Boost",
    tooltip = "Speed boost", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = Settings.WalkSpeed or 100 end
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}
end

-- === modules/movement/func_105_high_jump.lua ===
__FACTORIES["modules/movement/func_105_high_jump.lua"] = function()
-- Func #105: High Jump | toggle
return {
    id = "HighJump", type = "toggle", name = "High Jump",
    tooltip = "High jump", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.JumpPower = Settings.JumpPower or 200 end
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.JumpPower = 50 end
    end
}
end

-- === modules/movement/func_106_low_gravity.lua ===
__FACTORIES["modules/movement/func_106_low_gravity.lua"] = function()
-- Func #106: Low Gravity | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "LowGravity", type = "toggle", name = "Low Gravity",
    tooltip = "Low gravity", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceOrigGravity = Workspace.Gravity
        Workspace.Gravity = (Settings.Gravity or 196.2) / 4
    end,
    onDisable = function()
        Workspace.Gravity = _G.ResonanceOrigGravity or 196.2
    end
}
end

-- === modules/movement/func_107_zero_gravity.lua ===
__FACTORIES["modules/movement/func_107_zero_gravity.lua"] = function()
-- Func #107: Zero Gravity | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "ZeroGravity", type = "toggle", name = "Zero Gravity",
    tooltip = "Weightlessness", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceOrigGravity2 = Workspace.Gravity
        Workspace.Gravity = 0
    end,
    onDisable = function()
        Workspace.Gravity = _G.ResonanceOrigGravity2 or 196.2
    end
}
end

-- === modules/movement/func_108_auto_jump.lua ===
__FACTORIES["modules/movement/func_108_auto_jump.lua"] = function()
-- Func #108: Auto Jump | toggle
local State = { running = false }

return {
    id = "AutoJump", type = "toggle", name = "Auto Jump",
    tooltip = "Auto jump", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hum = Utils.getHum()
                if hum and hum.FloorMaterial ~= Enum.Material.Air then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/movement/func_109_bunny_hop.lua ===
__FACTORIES["modules/movement/func_109_bunny_hop.lua"] = function()
-- Func #109: Bunny Hop | toggle
local State = { running = false }

return {
    id = "BunnyHop", type = "toggle", name = "Bunny Hop",
    tooltip = "Jump while moving", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if hum and hum.MoveDirection.Magnitude > 0 then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/movement/func_110_slide.lua ===
__FACTORIES["modules/movement/func_110_slide.lua"] = function()
-- Func #110: Slide | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "Slide", type = "toggle", name = "Slide",
    tooltip = "Slide with Shift", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    hum.WalkSpeed = 150
                else
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}
end

-- === modules/movement/func_111_wall_run.lua ===
__FACTORIES["modules/movement/func_111_wall_run.lua"] = function()
-- Func #111: Wall Run | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "WallRun", type = "toggle", name = "Wall Run",
    tooltip = "Wall running", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial == Enum.Material.Air then
                    hum.WalkSpeed = 80
                elseif hum.FloorMaterial ~= Enum.Material.Air then
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}
end

-- === modules/movement/func_112_crouch.lua ===
__FACTORIES["modules/movement/func_112_crouch.lua"] = function()
-- Func #112: Crouch | toggle
return {
    id = "Crouch", type = "toggle", name = "Crouch",
    tooltip = "Crouch", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        local hum = Utils.getHum()
        if not hum then return end
        hum.BodyHeightScale.Value = 0.5
        hum.WalkSpeed = 8
    end,
    onDisable = function(Settings, Utils)
        local hum = Utils.getHum()
        if not hum then return end
        hum.BodyHeightScale.Value = 1
        hum.WalkSpeed = Settings.WalkSpeed or 16
    end
}
end

-- === modules/movement/func_113_sprint.lua ===
__FACTORIES["modules/movement/func_113_sprint.lua"] = function()
-- Func #113: Sprint | toggle
local UserInputService = game:GetService("UserInputService")
local State = { running = false }

return {
    id = "Sprint", type = "toggle", name = "Sprint",
    tooltip = "Sprint with Shift (×3)", tab = "Movement", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if not hum then continue end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and hum.MoveDirection.Magnitude > 0 then
                    hum.WalkSpeed = (Settings.WalkSpeed or 16) * 3
                else
                    hum.WalkSpeed = Settings.WalkSpeed or 16
                end
            end
        end)
    end,
    onDisable = function(Settings, Utils)
        State.running = false
        local hum = Utils.getHum()
        if hum then hum.WalkSpeed = 16 end
    end
}
end

-- === modules/movement/func_114_tp_spawn.lua ===
__FACTORIES["modules/movement/func_114_tp_spawn.lua"] = function()
-- Func #114: Teleport to Spawn | button
local Workspace = game:GetService("Workspace")

return {
    id = "TpSpawn", type = "button", name = "Teleport to Spawn",
    tooltip = "Teleport to spawn", tab = "Movement",
    onClick = function(Settings, Utils)
        local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
        if not sp then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("SpawnLocation") then sp = obj; break end
            end
        end
        if sp then Utils.teleportTo(sp.CFrame + Vector3.new(0, 5, 0)) end
    end
}
end

-- === modules/movement/func_115_tp_random_player.lua ===
__FACTORIES["modules/movement/func_115_tp_random_player.lua"] = function()
-- Func #115: Teleport to Random Player | button
return {
    id = "TpRandomPlayer", type = "button", name = "Teleport to Random Player",
    tooltip = "Teleport to a random player", tab = "Movement",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 3, 0)) end
    end
}
end

-- === modules/movement/func_116_tp_forward.lua ===
__FACTORIES["modules/movement/func_116_tp_forward.lua"] = function()
-- Func #116: Teleport Forward | button
local Workspace = game:GetService("Workspace")
local Camera    = Workspace.CurrentCamera

return {
    id = "TpForward", type = "button", name = "Teleport Forward",
    tooltip = "Teleport forward 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Camera.CFrame.LookVector * 50) end
    end
}
end

-- === modules/movement/func_117_tp_up.lua ===
__FACTORIES["modules/movement/func_117_tp_up.lua"] = function()
-- Func #117: Teleport Up | button
return {
    id = "TpUp", type = "button", name = "Teleport Up",
    tooltip = "Teleport up 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 50, 0)) end
    end
}
end

-- === modules/movement/func_118_tp_down.lua ===
__FACTORIES["modules/movement/func_118_tp_down.lua"] = function()
-- Func #118: Teleport Down | button
return {
    id = "TpDown", type = "button", name = "Teleport Down",
    tooltip = "Teleport down 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, -50, 0)) end
    end
}
end

-- === modules/movement/func_119_tp_cursor.lua ===
__FACTORIES["modules/movement/func_119_tp_cursor.lua"] = function()
-- Func #119: Teleport to Cursor | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "TpCursor", type = "button", name = "Teleport to Cursor",
    tooltip = "Teleport to cursor", tab = "Movement",
    onClick = function(Settings, Utils)
        local mouse = LocalPlayer:GetMouse()
        if mouse and mouse.Hit then
            Utils.teleportTo(mouse.Hit + Vector3.new(0, 3, 0))
        end
    end
}
end

-- === modules/movement/func_120_reset_speed.lua ===
__FACTORIES["modules/movement/func_120_reset_speed.lua"] = function()
-- Func #120: Reset Speed | button
return {
    id = "ResetSpeed", type = "button", name = "Reset Speed",
    tooltip = "Reset speed and jump", tab = "Movement",
    onClick = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        Settings.WalkSpeed = 16
        Settings.JumpPower = 50
        Utils.notify("Resonance", "Speed reset", Settings)
    end
}
end

-- === modules/visuals/func_121_esp_boxes.lua ===
__FACTORIES["modules/visuals/func_121_esp_boxes.lua"] = function()
-- Func #121: ESP Boxes | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, boxes = {} }

local function createBox(player)
    if player == LocalPlayer or State.boxes[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Size = Vector3.new(4, 6, 2)
    box.Adornee = hrp
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.5
    box.Color3 = Color3.fromRGB(255, 0, 0)
    box.Parent = hrp
    State.boxes[player] = box
end

local function removeBox(player)
    if State.boxes[player] then
        pcall(function() State.boxes[player]:Destroy() end)
        State.boxes[player] = nil
    end
end

return {
    id = "ESPBoxes", type = "toggle", name = "ESP Boxes",
    tooltip = "Boxes around players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.boxes = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeBox(p)
                elseif Settings.ESPBoxes then
                    createBox(p)
                else
                    removeBox(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.boxes) do removeBox(p) end
        State.boxes = {}
    end
}
end

-- === modules/visuals/func_122_esp_tracers.lua ===
__FACTORIES["modules/visuals/func_122_esp_tracers.lua"] = function()
-- Func #122: ESP Tracers | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, tracers = {} }

local function createTracer(player)
    if State.tracers[player] then return end
    local line = Instance.new("LineHandleAdornment")
    line.Thickness = 2
    line.Color3 = Color3.fromRGB(255, 0, 0)
    line.AlwaysOnTop = true
    line.ZIndex = 5
    line.Parent = Workspace
    State.tracers[player] = line
end

local function removeTracer(player)
    if State.tracers[player] then
        pcall(function() State.tracers[player]:Destroy() end)
        State.tracers[player] = nil
    end
end

return {
    id = "ESPTracers", type = "toggle", name = "ESP Tracers",
    tooltip = "Lines to players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tracers = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeTracer(p)
                elseif Settings.ESPTracers then
                    if not p.Character then removeTracer(p); continue end
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then removeTracer(p); continue end
                    if not State.tracers[p] then createTracer(p) end
                    local tracer = State.tracers[p]
                    if tracer then
                        tracer.Adornee = hrp
                        tracer.Length = 0
                        tracer.CFrame = CFrame.new(
                            Camera.CFrame.Position,
                            hrp.Position)
                    end
                else
                    removeTracer(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.tracers) do removeTracer(p) end
        State.tracers = {}
    end
}
end

-- === modules/visuals/func_123_player_info.lua ===
__FACTORIES["modules/visuals/func_123_player_info.lua"] = function()
-- Func #123: Player Info | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, tags = {} }

local function createTag(player)
    if State.tags[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceInfo"
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.Adornee = hrp
    bb.Parent = hrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Text = player.Name
    label.Parent = bb
    State.tags[player] = { gui = bb, label = label }
end

local function removeTag(player)
    if State.tags[player] then
        pcall(function() State.tags[player].gui:Destroy() end)
        State.tags[player] = nil
    end
end

return {
    id = "PlayerInfo", type = "toggle", name = "Player Info",
    tooltip = "Name, HP, and distance", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tags = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeTag(p)
                elseif Settings.ESPInfo then
                    if not p.Character then removeTag(p); continue end
                    if not State.tags[p] then createTag(p) end
                    local entry = State.tags[p]
                    if entry then
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local myHRP = Utils.getHRP()
                        local dist = (hrp and myHRP) and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
                        local hp = hum and math.floor(hum.Health) or 0
                        entry.label.Text = string.format("%s | %dHP | %dm", p.Name, hp, dist)
                    end
                else
                    removeTag(p)
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.tags) do removeTag(p) end
        State.tags = {}
    end
}
end

-- === modules/visuals/func_124_name_tags.lua ===
__FACTORIES["modules/visuals/func_124_name_tags.lua"] = function()
-- Func #124: Name Tags | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, tags = {} }

return {
    id = "NameTags", type = "toggle", name = "Name Tags",
    tooltip = "Large names above players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.tags = {}
        task.spawn(function()
            while State.running do
                task.wait(1)
                for _, p in pairs(Players:GetPlayers()) do
                    if p == LocalPlayer then continue end
                    if p.Character then
                        local head = p.Character:FindFirstChild("Head")
                        if head and not State.tags[p] then
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "ResonanceNameTag"
                            bb.Size = UDim2.new(0, 200, 0, 50)
                            bb.AlwaysOnTop = true
                            bb.StudsOffset = Vector3.new(0, 2, 0)
                            bb.Adornee = head
                            bb.Parent = head
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextColor3 = Color3.fromRGB(255, 200, 0)
                            label.TextStrokeTransparency = 0
                            label.TextScaled = true
                            label.Font = Enum.Font.GothamBold
                            label.Text = p.Name
                            label.Parent = bb
                            State.tags[p] = bb
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        for _, tag in pairs(State.tags) do pcall(function() tag:Destroy() end) end
        State.tags = {}
    end
}
end

-- === modules/visuals/func_125_health_bars.lua ===
__FACTORIES["modules/visuals/func_125_health_bars.lua"] = function()
-- Func #125: Health Bars | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, bars = {} }

local function createBar(player)
    if State.bars[player] then return end
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceHealthBar"
    bb.Size = UDim2.new(0, 100, 0, 10)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Adornee = head
    bb.Parent = head
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bg.BorderSizePixel = 0
    bg.Parent = bb
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bg
    State.bars[player] = { bg = bg, fill = fill }
end

local function removeBar(player)
    if State.bars[player] then
        pcall(function() State.bars[player].bg.Parent:Destroy() end)
        State.bars[player] = nil
    end
end

return {
    id = "HealthBars", type = "toggle", name = "Health Bars",
    tooltip = "HP bars above players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.bars = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeBar(p)
                else
                    if p.Character and p.Character:FindFirstChild("Head") then
                        if not State.bars[p] then createBar(p) end
                        local entry = State.bars[p]
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if entry and hum then
                            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            entry.fill.Size = UDim2.new(pct, 0, 1, 0)
                            entry.fill.BackgroundColor3 = Color3.fromRGB(
                                math.floor(255 * (1 - pct)),
                                math.floor(255 * pct),
                                0)
                        end
                    else
                        removeBar(p)
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.bars) do removeBar(p) end
        State.bars = {}
    end
}
end

-- === modules/visuals/func_126_distance_display.lua ===
__FACTORIES["modules/visuals/func_126_distance_display.lua"] = function()
-- Func #126: Distance Display | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, labels = {} }

local function createLabel(player)
    if State.labels[player] then return end
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ResonanceDistance"
    bb.Size = UDim2.new(0, 100, 0, 30)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, -3, 0)
    bb.Adornee = hrp
    bb.Parent = hrp
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(0, 255, 100)
    label.TextStrokeTransparency = 0
    label.TextSize = 16
    label.Font = Enum.Font.GothamBold
    label.Parent = bb
    State.labels[player] = { gui = bb, label = label }
end

local function removeLabel(player)
    if State.labels[player] then
        pcall(function() State.labels[player].gui:Destroy() end)
        State.labels[player] = nil
    end
end

return {
    id = "DistanceDisplay", type = "toggle", name = "Distance Display",
    tooltip = "Distance to players", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.labels = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeLabel(p)
                else
                    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if not State.labels[p] then createLabel(p) end
                        local entry = State.labels[p]
                        local myHRP = Utils.getHRP()
                        if entry and myHRP then
                            local dist = (p.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude
                            entry.label.Text = math.floor(dist) .. "m"
                        end
                    else
                        removeLabel(p)
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.labels) do removeLabel(p) end
        State.labels = {}
    end
}
end

-- === modules/visuals/func_127_skeleton_esp.lua ===
__FACTORIES["modules/visuals/func_127_skeleton_esp.lua"] = function()
-- Func #127: Skeleton ESP | toggle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil, lines = {} }

local BONES = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function createLine(player)
    local lines = {}
    for i = 1, #BONES do
        local line = Instance.new("LineHandleAdornment")
        line.Thickness = 2
        line.Color3 = Color3.fromRGB(0, 255, 255)
        line.AlwaysOnTop = true
        line.Parent = Workspace
        table.insert(lines, line)
    end
    State.lines[player] = lines
end

local function removeLine(player)
    if State.lines[player] then
        for _, l in ipairs(State.lines[player]) do
            pcall(function() l:Destroy() end)
        end
        State.lines[player] = nil
    end
end

return {
    id = "SkeletonESP", type = "toggle", name = "Skeleton ESP",
    tooltip = "Player skeletons", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.lines = {}
        State.conn = RunService.RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then
                    removeLine(p)
                else
                    if not p.Character then removeLine(p); continue end
                    if not State.lines[p] then createLine(p) end
                    local lines = State.lines[p]
                    for i, pair in ipairs(BONES) do
                        local a = p.Character:FindFirstChild(pair[1])
                        local b = p.Character:FindFirstChild(pair[2])
                        if a and b and lines[i] then
                            lines[i].Adornee = a
                            lines[i].CFrame = CFrame.new(a.Position, b.Position)
                            lines[i].Length = (a.Position - b.Position).Magnitude
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        for p in pairs(State.lines) do removeLine(p) end
        State.lines = {}
    end
}
end

-- === modules/visuals/func_128_chams.lua ===
__FACTORIES["modules/visuals/func_128_chams.lua"] = function()
-- Func #128: Chams | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, conn = nil }

return {
    id = "Chams", type = "toggle", name = "Chams",
    tooltip = "Highlight players with color", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        _G.ResonanceChamsConn = game:GetService("RunService").RenderStepped:Connect(function()
            if not State.running then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                if Settings.ESPTeamCheck and p.Team == LocalPlayer.Team then continue end
                if p.Character then
                    for _, part in pairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.Material = Enum.Material.ForceField
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if _G.ResonanceChamsConn then
            _G.ResonanceChamsConn:Disconnect()
            _G.ResonanceChamsConn = nil
        end
    end
}
end

-- === modules/visuals/func_129_xray.lua ===
__FACTORIES["modules/visuals/func_129_xray.lua"] = function()
-- Func #129: X-Ray | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "XRay", type = "toggle", name = "X-Ray",
    tooltip = "Transparent walls (using LocalTransparencyModifier)", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0.5
                    end
                end
            end
        end
    end,
    onDisable = function()
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end
}
end

-- === modules/visuals/func_130_fullbright.lua ===
__FACTORIES["modules/visuals/func_130_fullbright.lua"] = function()
-- Func #130: Fullbright | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = {} }

return {
    id = "Fullbright", type = "toggle", name = "Fullbright",
    tooltip = "Full brightness", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig.Ambient = Lighting.Ambient
        State.orig.OutdoorAmbient = Lighting.OutdoorAmbient
        State.orig.Brightness = Lighting.Brightness
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 3
    end,
    onDisable = function()
        if State.orig.Ambient then Lighting.Ambient = State.orig.Ambient end
        if State.orig.OutdoorAmbient then Lighting.OutdoorAmbient = State.orig.OutdoorAmbient end
        if State.orig.Brightness then Lighting.Brightness = State.orig.Brightness end
    end
}
end

-- === modules/visuals/func_131_no_fog.lua ===
__FACTORIES["modules/visuals/func_131_no_fog.lua"] = function()
-- Func #131: No Fog | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "NoFog", type = "toggle", name = "No Fog",
    tooltip = "Remove fog", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.FogEnd
        Lighting.FogEnd = 1e6
    end,
    onDisable = function()
        Lighting.FogEnd = State.orig or 1000
    end
}
end

-- === modules/visuals/func_132_remove_textures.lua ===
__FACTORIES["modules/visuals/func_132_remove_textures.lua"] = function()
-- Func #132: Remove Textures | toggle
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveTextures", type = "toggle", name = "Remove Textures",
    tooltip = "Hide Decal/Texture", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
    end,
    onDisable = function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 0
            end
        end
    end
}
end

-- === modules/visuals/func_133_blue_sky.lua ===
__FACTORIES["modules/visuals/func_133_blue_sky.lua"] = function()
-- Func #133: Blue Sky | toggle
local Lighting = game:GetService("Lighting")

return {
    id = "BlueSky", type = "toggle", name = "Blue Sky",
    tooltip = "Blue sky", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Name = "ResonanceSky"
            sky.SkyboxBk = "rbxassetid://159454299"
            sky.SkyboxDn = "rbxassetid://159454296"
            sky.SkyboxFt = "rbxassetid://159454293"
            sky.SkyboxLf = "rbxassetid://159454286"
            sky.SkyboxRt = "rbxassetid://159454300"
            sky.SkyboxUp = "rbxassetid://159454288"
            sky.Parent = Lighting
        end
    end,
    onDisable = function()
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if sky then sky:Destroy() end
    end
}
end

-- === modules/visuals/func_134_red_ambient.lua ===
__FACTORIES["modules/visuals/func_134_red_ambient.lua"] = function()
-- Func #134: Red Ambient | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "RedAmbient", type = "toggle", name = "Red Ambient",
    tooltip = "Red lighting", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.Ambient
        Lighting.Ambient = Color3.fromRGB(255, 0, 0)
    end,
    onDisable = function()
        Lighting.Ambient = State.orig or Color3.fromRGB(0, 0, 0)
    end
}
end

-- === modules/visuals/func_135_green_ambient.lua ===
__FACTORIES["modules/visuals/func_135_green_ambient.lua"] = function()
-- Func #135: Green Ambient | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "GreenAmbient", type = "toggle", name = "Green Ambient",
    tooltip = "Green lighting", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.Ambient
        Lighting.Ambient = Color3.fromRGB(0, 255, 0)
    end,
    onDisable = function()
        Lighting.Ambient = State.orig or Color3.fromRGB(0, 0, 0)
    end
}
end

-- === modules/visuals/func_136_rainbow_light.lua ===
__FACTORIES["modules/visuals/func_136_rainbow_light.lua"] = function()
-- Func #136: Rainbow Light | toggle
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local State = { running = false, conn = nil, hue = 0 }

return {
    id = "RainbowLight", type = "toggle", name = "Rainbow Light",
    tooltip = "Rainbow lighting", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function(dt)
            if not State.running then return end
            State.hue = (State.hue + dt * 0.3) % 1
            Lighting.Ambient = Color3.fromHSV(State.hue, 1, 1)
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
    end
}
end

-- === modules/visuals/func_137_remove_baseplate.lua ===
__FACTORIES["modules/visuals/func_137_remove_baseplate.lua"] = function()
-- Func #137: Remove Baseplate | button
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveBaseplate", type = "button", name = "Remove Baseplate",
    tooltip = "Remove Baseplate", tab = "Visuals",
    onClick = function(Settings, Utils)
        local bp = Workspace:FindFirstChild("Baseplate")
        if bp then
            bp:Destroy()
            Utils.notify("Resonance", "Baseplate removed", Settings)
        end
    end
}
end

-- === modules/visuals/func_138_remove_lights.lua ===
__FACTORIES["modules/visuals/func_138_remove_lights.lua"] = function()
-- Func #138: Remove Lights | button
local Workspace = game:GetService("Workspace")

return {
    id = "RemoveLights", type = "button", name = "Remove Lights",
    tooltip = "Remove all light sources", tab = "Visuals",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Light") then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        Utils.notify("Resonance", "Lights removed: " .. count, Settings)
    end
}
end

-- === modules/visuals/func_139_restore_lighting.lua ===
__FACTORIES["modules/visuals/func_139_restore_lighting.lua"] = function()
-- Func #139: Restore Lighting | button
local Lighting = game:GetService("Lighting")

return {
    id = "RestoreLighting", type = "button", name = "Restore Lighting",
    tooltip = "Reset lighting", tab = "Visuals",
    onClick = function(Settings, Utils)
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
        Lighting.FogEnd = 1000
        Lighting.Brightness = 1
        local sky = Lighting:FindFirstChild("ResonanceSky")
        if sky then sky:Destroy() end
        Utils.notify("Resonance", "Lighting reset", Settings)
    end
}
end

-- === modules/visuals/func_140_disable_shadows.lua ===
__FACTORIES["modules/visuals/func_140_disable_shadows.lua"] = function()
-- Func #140: Disable Shadows | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "DisableShadows", type = "toggle", name = "Disable Shadows",
    tooltip = "Disable shadows", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.GlobalShadows
        Lighting.GlobalShadows = false
    end,
    onDisable = function()
        Lighting.GlobalShadows = State.orig ~= false
    end
}
end

-- === modules/server/func_141_rejoin.lua ===
__FACTORIES["modules/server/func_141_rejoin.lua"] = function()
-- Func #141: Rejoin | button
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "Rejoin", type = "button", name = "Rejoin",
    tooltip = "Rejoin the current server", tab = "Server",
    onClick = function(Settings, Utils)
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end
}
end

-- === modules/server/func_142_server_hop.lua ===
__FACTORIES["modules/server/func_142_server_hop.lua"] = function()
-- Func #142: Server Hop | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ServerHop", type = "button", name = "Server Hop",
    tooltip = "Join a random server", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data and #res.data > 0 then
            local srv = res.data[math.random(1, #res.data)]
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
            end)
        end
    end
}
end

-- === modules/server/func_143_join_smallest.lua ===
__FACTORIES["modules/server/func_143_join_smallest.lua"] = function()
-- Func #143: Join Smallest Server | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JoinSmallest", type = "button", name = "Join Smallest Server",
    tooltip = "Join the server with the fewest players", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data then
            local best, count = nil, math.huge
            for _, s in pairs(res.data) do
                if s.playing and s.playing < count then
                    best, count = s, s.playing
                end
            end
            if best then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
            end
        end
    end
}
end

-- === modules/server/func_144_join_largest.lua ===
__FACTORIES["modules/server/func_144_join_largest.lua"] = function()
-- Func #144: Join Largest Server | button
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "JoinLargest", type = "button", name = "Join Largest Server",
    tooltip = "Join the fullest server", tab = "Server",
    onClick = function(Settings, Utils)
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
        end)
        if ok and res and res.data and #res.data > 0 then
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, res.data[1].id, LocalPlayer)
            end)
        end
    end
}
end

-- === modules/server/func_145_copy_jobid.lua ===
__FACTORIES["modules/server/func_145_copy_jobid.lua"] = function()
-- Func #145: Copy JobID | button
return {
    id = "CopyJobId", type = "button", name = "Copy JobID",
    tooltip = "Copy the server JobID", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(game.JobId)
            Utils.notify("Resonance", "JobID copied", Settings)
        end
    end
}
end

-- === modules/server/func_146_copy_placeid.lua ===
__FACTORIES["modules/server/func_146_copy_placeid.lua"] = function()
-- Func #146: Copy PlaceID | button
return {
    id = "CopyPlaceId", type = "button", name = "Copy PlaceID",
    tooltip = "Copy the game's PlaceID", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            Utils.notify("Resonance", "PlaceID copied", Settings)
        end
    end
}
end

-- === modules/server/func_147_copy_server_link.lua ===
__FACTORIES["modules/server/func_147_copy_server_link.lua"] = function()
-- Func #147: Copy Server Link | button
return {
    id = "CopyServerLink", type = "button", name = "Copy Server Link",
    tooltip = "Copy server link", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            local link = "roblox://placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId
            setclipboard(link)
            Utils.notify("Resonance", "Link copied", Settings)
        end
    end
}
end

-- === modules/server/func_148_show_server_info.lua ===
__FACTORIES["modules/server/func_148_show_server_info.lua"] = function()
-- Func #148: Show Server Info | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ShowServerInfo", type = "button", name = "Show Server Info",
    tooltip = "Show server information", tab = "Server",
    onClick = function(Settings, Utils)
        local count = #Players:GetPlayers()
        local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        Utils.notify("Server Info", "Players: " .. count .. " | Ping: " .. ping .. " ms", Settings)
    end
}
end

-- === modules/server/func_149_list_players.lua ===
__FACTORIES["modules/server/func_149_list_players.lua"] = function()
-- Func #149: List Players | button
local Players = game:GetService("Players")

return {
    id = "ListPlayers", type = "button", name = "List Players",
    tooltip = "Print the player list to the console", tab = "Server",
    onClick = function(Settings, Utils)
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(names, p.Name .. " (ID: " .. p.UserId .. ")")
        end
        print("[Resonance] Players:")
        for _, n in ipairs(names) do print("  " .. n) end
        Utils.notify("Resonance", "Player list printed to the console", Settings)
    end
}
end

-- === modules/server/func_150_hop_until_empty.lua ===
__FACTORIES["modules/server/func_150_hop_until_empty.lua"] = function()
-- Func #150: Hop Until Empty | toggle
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false, hops = 0 }

local function loop()
    while State.running do
        task.wait(5)
        if #Players:GetPlayers() <= 1 then
            Utils_notify("Resonance", "Server is empty — stopping", Settings)
            State.running = false
            break
        end
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data then
            local best, count = nil, math.huge
            for _, s in pairs(res.data) do
                if s.playing and s.playing < count then
                    best, count = s, s.playing
                end
            end
            if best and count < #Players:GetPlayers() then
                State.hops = State.hops + 1
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer)
                end)
                break
            end
        end
    end
end

return {
    id = "HopUntilEmpty", type = "toggle", name = "Hop Until Empty",
    tooltip = "Server hop until an empty server is found", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        State.hops = 0
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { hops = State.hops } end
}
end

-- === modules/server/func_151_anti_afk.lua ===
__FACTORIES["modules/server/func_151_anti_afk.lua"] = function()
-- Func #151: Anti-AFK | toggle
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AntiAfk", type = "toggle", name = "Anti-AFK",
    tooltip = "Prevent inactivity kicks", tab = "Server", default = true,
    onEnable = function(Settings, Utils)
        _G.ResonanceAntiAfkConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end,
    onDisable = function()
        if _G.ResonanceAntiAfkConn then
            _G.ResonanceAntiAfkConn:Disconnect()
            _G.ResonanceAntiAfkConn = nil
        end
    end
}
end

-- === modules/server/func_152_auto_rejoin_kick.lua ===
__FACTORIES["modules/server/func_152_auto_rejoin_kick.lua"] = function()
-- Func #152: Auto Rejoin on Kick | toggle
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AutoRejoinKick", type = "toggle", name = "Auto Rejoin on Kick",
    tooltip = "Automatically rejoin when kicked", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        _G.ResonanceAutoRejoin = true
    end,
    onDisable = function()
        _G.ResonanceAutoRejoin = false
    end
}
end

-- === modules/server/func_153_rejoin_delay.lua ===
__FACTORIES["modules/server/func_153_rejoin_delay.lua"] = function()
-- Func #153: Rejoin Delay | button
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "RejoinDelay", type = "button", name = "Rejoin in 3s",
    tooltip = "Rejoin after 3 seconds", tab = "Server",
    onClick = function(Settings, Utils)
        Utils.notify("Resonance", "Rejoining in 3 seconds...", Settings)
        task.wait(3)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
}
end

-- === modules/server/func_154_ping_display.lua ===
__FACTORIES["modules/server/func_154_ping_display.lua"] = function()
-- Func #154: Ping Display | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local State = { running = false }

local function loop()
    while State.running do
        task.wait(2)
        local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        print("[Resonance] Ping: " .. ping .. " ms")
    end
end

return {
    id = "PingDisplay", type = "toggle", name = "Ping Display",
    tooltip = "Print ping to the console", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/server/func_155_fps_display.lua ===
__FACTORIES["modules/server/func_155_fps_display.lua"] = function()
-- Func #155: FPS Display | toggle
local RunService = game:GetService("RunService")

local State = { running = false }

local function loop()
    while State.running do
        local dt = RunService.RenderStepped:Wait()
        task.wait(1)
        print("[Resonance] FPS: " .. math.floor(1 / dt))
    end
end

return {
    id = "FpsDisplay", type = "toggle", name = "FPS Display",
    tooltip = "Print FPS to the console", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(loop)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/server/func_156_leave_game.lua ===
__FACTORIES["modules/server/func_156_leave_game.lua"] = function()
-- Func #156: Leave Game | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "LeaveGame", type = "button", name = "Leave Game",
    tooltip = "Leave the game", tab = "Server",
    onClick = function(Settings, Utils)
        LocalPlayer:Kick("Resonance: leave")
    end
}
end

-- === modules/server/func_157_reset_character.lua ===
__FACTORIES["modules/server/func_157_reset_character.lua"] = function()
-- Func #157: Reset Character | button
return {
    id = "ResetCharacter", type = "button", name = "Reset Character",
    tooltip = "Reset your character", tab = "Server",
    onClick = function(Settings, Utils)
        local hum = Utils.getHum()
        if hum then hum.Health = 0 end
    end
}
end

-- === modules/server/func_158_character_respawn.lua ===
__FACTORIES["modules/server/func_158_character_respawn.lua"] = function()
-- Func #158: Character Respawn | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "CharacterRespawn", type = "button", name = "Character Respawn",
    tooltip = "Force character respawn", tab = "Server",
    onClick = function(Settings, Utils)
        pcall(function()
            LocalPlayer:LoadCharacter()
        end)
    end
}
end

-- === modules/server/func_159_unlock_fps.lua ===
__FACTORIES["modules/server/func_159_unlock_fps.lua"] = function()
-- Func #159: Unlock FPS | toggle
return {
    id = "UnlockFps", type = "toggle", name = "Unlock FPS",
    tooltip = "Remove the FPS cap (up to 240)", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        if setfpscap then
            setfpscap(240)
            Utils.notify("Resonance", "FPS cap: 240", Settings)
        end
    end,
    onDisable = function(Settings, Utils)
        if setfpscap then
            setfpscap(60)
            Utils.notify("Resonance", "FPS cap: 60", Settings)
        end
    end
}
end

-- === modules/server/func_160_show_fps.lua ===
__FACTORIES["modules/server/func_160_show_fps.lua"] = function()
-- Func #160: Show FPS | button
local RunService = game:GetService("RunService")

return {
    id = "ShowFps", type = "button", name = "Show FPS",
    tooltip = "Show current FPS", tab = "Server",
    onClick = function(Settings, Utils)
        local dt = RunService.RenderStepped:Wait()
        Utils.notify("FPS", math.floor(1 / dt) .. " fps", Settings)
    end
}
end

-- === modules/utility/func_161_anti_afk.lua ===
__FACTORIES["modules/utility/func_161_anti_afk.lua"] = function()
-- Func #161: Anti-AFK | toggle
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

return {
    id = "AntiAfkUtil", type = "toggle", name = "Anti-AFK",
    tooltip = "Prevent AFK kicks", tab = "Utility", default = true,
    onEnable = function(Settings, Utils)
        _G.ResonanceAntiAfkUtilConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end,
    onDisable = function()
        if _G.ResonanceAntiAfkUtilConn then
            _G.ResonanceAntiAfkUtilConn:Disconnect()
            _G.ResonanceAntiAfkUtilConn = nil
        end
    end
}
end

-- === modules/utility/func_162_auto_claim_cash.lua ===
__FACTORIES["modules/utility/func_162_auto_claim_cash.lua"] = function()
-- Func #162: Auto Claim Cash | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false, claimed = 0 }

return {
    id = "AutoClaimCash", type = "toggle", name = "Auto Claim Cash",
    tooltip = "Automatically collect cash", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        local name = obj.Name:lower()
                        if name:find("cash") or name:find("money") or name:find("coin") then
                            pcall(function()
                                if firetouchinterest then
                                    firetouchinterest(hrp, obj, 0)
                                    firetouchinterest(hrp, obj, 1)
                                end
                                State.claimed = State.claimed + 1
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end,
    getStats = function() return { claimed = State.claimed } end
}
end

-- === modules/utility/func_163_cash_magnet.lua ===
__FACTORIES["modules/utility/func_163_cash_magnet.lua"] = function()
-- Func #163: Cash Magnet | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "CashMagnet", type = "toggle", name = "Cash Magnet",
    tooltip = "Attract cash to you", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local name = obj.Name:lower()
                        if name:find("cash") or name:find("money") or name:find("coin") then
                            pcall(function() obj.CFrame = hrp.CFrame end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/utility/func_164_item_magnet.lua ===
__FACTORIES["modules/utility/func_164_item_magnet.lua"] = function()
-- Func #164: Item Magnet | toggle
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ItemMagnet", type = "toggle", name = "Item Magnet",
    tooltip = "Attract all items", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.1)
                local hrp = Utils.getHRP()
                if not hrp then continue end
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local owner = Players:GetPlayerFromCharacter(obj.Parent)
                        if not owner then
                            pcall(function()
                                obj.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), 3, math.random(-3,3))
                            end)
                        end
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/utility/func_165_bring_all_items.lua ===
__FACTORIES["modules/utility/func_165_bring_all_items.lua"] = function()
-- Func #165: Bring All Items | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BringAllItems", type = "button", name = "Bring All Items",
    tooltip = "Bring all items to yourself", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored then
                local owner = Players:GetPlayerFromCharacter(obj.Parent)
                if not owner then
                    pcall(function()
                        obj.CFrame = hrp.CFrame + Vector3.new(math.random(-3,3), 2, math.random(-3,3))
                        count = count + 1
                    end)
                end
            end
        end
        Utils.notify("Resonance", "Collected: " .. count, Settings)
    end
}
end

-- === modules/utility/func_166_bring_all_players.lua ===
__FACTORIES["modules/utility/func_166_bring_all_players.lua"] = function()
-- Func #166: Bring All Players | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "BringAllPlayers", type = "button", name = "Bring All Players",
    tooltip = "Teleport all players to you", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if not hrp then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                if thrp then
                    thrp.CFrame = hrp.CFrame + Vector3.new(math.random(-5,5), 3, math.random(-5,5))
                end
            end
        end
    end
}
end

-- === modules/utility/func_167_clear_workspace.lua ===
__FACTORIES["modules/utility/func_167_clear_workspace.lua"] = function()
-- Func #167: Clear Workspace | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return {
    id = "ClearWorkspace", type = "button", name = "Clear Workspace",
    tooltip = "Delete models (except characters)", tab = "Utility",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        Utils.notify("Resonance", "Removed: " .. count, Settings)
    end
}
end

-- === modules/utility/func_168_delete_grabbed.lua ===
__FACTORIES["modules/utility/func_168_delete_grabbed.lua"] = function()
-- Func #168: Delete Grabbed | button
local Workspace = game:GetService("Workspace")

return {
    id = "DeleteGrabbed", type = "button", name = "Delete Grabbed",
    tooltip = "Remove GrabParts", tab = "Utility",
    onClick = function(Settings, Utils)
        local gp = Workspace:FindFirstChild("GrabParts")
        if gp then
            gp:Destroy()
            Utils.notify("Resonance", "GrabParts removed", Settings)
        end
    end
}
end

-- === modules/utility/func_169_unlock_mouse.lua ===
__FACTORIES["modules/utility/func_169_unlock_mouse.lua"] = function()
-- Func #169: Unlock Mouse | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "UnlockMouse", type = "toggle", name = "Unlock Mouse",
    tooltip = "Show cursor", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        UserInputService.MouseIconEnabled = true
    end,
    onDisable = function(Settings, Utils)
        UserInputService.MouseIconEnabled = false
    end
}
end

-- === modules/utility/func_170_full_screen.lua ===
__FACTORIES["modules/utility/func_170_full_screen.lua"] = function()
-- Func #170: Full Screen | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "FullScreen", type = "toggle", name = "Full Screen",
    tooltip = "Unlock the cursor from the center", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end,
    onDisable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
}
end

-- === modules/utility/func_171_copy_position.lua ===
__FACTORIES["modules/utility/func_171_copy_position.lua"] = function()
-- Func #171: Copy Position | button
return {
    id = "CopyPosition", type = "button", name = "Copy Position",
    tooltip = "Copy position", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp and setclipboard then
            setclipboard(tostring(hrp.Position))
            Utils.notify("Resonance", "Position copied", Settings)
        end
    end
}
end

-- === modules/utility/func_172_copy_rotation.lua ===
__FACTORIES["modules/utility/func_172_copy_rotation.lua"] = function()
-- Func #172: Copy Rotation | button
return {
    id = "CopyRotation", type = "button", name = "Copy Rotation",
    tooltip = "Copy rotation", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp and setclipboard then
            setclipboard(tostring(hrp.Orientation))
            Utils.notify("Resonance", "Rotation copied", Settings)
        end
    end
}
end

-- === modules/utility/func_173_show_position.lua ===
__FACTORIES["modules/utility/func_173_show_position.lua"] = function()
-- Func #173: Show Position | button
return {
    id = "ShowPosition", type = "button", name = "Show Position",
    tooltip = "Show current position", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then
            Utils.notify("Position", tostring(hrp.Position), Settings)
        end
    end
}
end

-- === modules/utility/func_174_print_character.lua ===
__FACTORIES["modules/utility/func_174_print_character.lua"] = function()
-- Func #174: Print Character Tree | button
return {
    id = "PrintCharacter", type = "button", name = "Print Character Tree",
    tooltip = "Print the character hierarchy to the console", tab = "Utility",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        print("[Resonance] Character tree:")
        for _, v in pairs(char:GetDescendants()) do
            print("  " .. v:GetFullName())
        end
        Utils.notify("Resonance", "Hierarchy printed to the console", Settings)
    end
}
end

-- === modules/utility/func_175_clear_notifications.lua ===
__FACTORIES["modules/utility/func_175_clear_notifications.lua"] = function()
-- Func #175: Clear Notifications | button
local StarterGui = game:GetService("StarterGui")

return {
    id = "ClearNotifications", type = "button", name = "Clear Notifications",
    tooltip = "Clear notifications", tab = "Utility",
    onClick = function(Settings, Utils)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "",
                Text = "",
                Duration = 0
            })
        end)
    end
}
end

-- === modules/utility/func_176_toggle_ui.lua ===
__FACTORIES["modules/utility/func_176_toggle_ui.lua"] = function()
-- Func #176: Toggle UI | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "ToggleUi", type = "button", name = "Toggle UI",
    tooltip = "Show/hide UI", tab = "Utility",
    onClick = function(Settings, Utils)
        local gui = LocalPlayer.PlayerGui:FindFirstChild("ResonanceMenu")
            or LocalPlayer.PlayerGui:FindFirstChildOfClass("ScreenGui")
        if gui then
            gui.Enabled = not gui.Enabled
        end
    end
}
end

-- === modules/utility/func_177_re_execute.lua ===
__FACTORIES["modules/utility/func_177_re_execute.lua"] = function()
-- Func #177: Re-execute Script | button
return {
    id = "ReExecute", type = "button", name = "Re-execute Script",
    tooltip = "Restart the script", tab = "Utility",
    onClick = function(Settings, Utils)
        local url = "https://raw.githubusercontent.com/a32435629-collab/resonance/main/dist/resonance.lua"
        local ok, err = pcall(function()
            loadstring(game:HttpGet(url))()
        end)
        if not ok then
            Utils.notify("Resonance", "Error: " .. tostring(err), Settings)
        end
    end
}
end

-- === modules/utility/func_178_reload_config.lua ===
__FACTORIES["modules/utility/func_178_reload_config.lua"] = function()
-- Func #178: Reload Config | button
return {
    id = "ReloadConfig", type = "button", name = "Reload Config",
    tooltip = "Load config", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.load(Settings)
            if ok then
                Utils.notify("Resonance", "Config loaded", Settings)
            else
                Utils.notify("Resonance", "Error: " .. tostring(err), Settings)
            end
        end
    end
}
end

-- === modules/utility/func_179_save_config.lua ===
__FACTORIES["modules/utility/func_179_save_config.lua"] = function()
-- Func #179: Save Config | button
return {
    id = "SaveConfig", type = "button", name = "Save Config",
    tooltip = "Save config", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.save(Settings)
            if ok then
                Utils.notify("Resonance", "Config saved", Settings)
            else
                Utils.notify("Resonance", "Error: " .. tostring(err), Settings)
            end
        end
    end
}
end

-- === modules/utility/func_180_wipe_cache.lua ===
__FACTORIES["modules/utility/func_180_wipe_cache.lua"] = function()
-- Func #180: Wipe Cache | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return {
    id = "WipeCache", type = "button", name = "Wipe Cache",
    tooltip = "Clear ESP/UI cache", tab = "Utility",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name:find("ResonanceESP") or obj.Name:find("ResonanceBlind") then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        for _, p in pairs(Players:GetPlayers()) do
            local pg = p:FindFirstChild("PlayerGui")
            if pg then
                local blind = pg:FindFirstChild("ResonanceBlind")
                if blind then blind:Destroy(); count = count + 1 end
            end
        end
        Utils.notify("Resonance", "Cleared: " .. count, Settings)
    end
}
end

-- === modules/trolling/func_181_music_play.lua ===
__FACTORIES["modules/trolling/func_181_music_play.lua"] = function()
-- Func #181: Music Play | button
local Debris = game:GetService("Debris")

return {
    id = "MusicPlay", type = "button", name = "Music Play",
    tooltip = "Play music on the server", tab = "Trolling",
    onClick = function(Settings, Utils)
        local s = Instance.new("Sound", workspace)
        s.SoundId = "rbxassetid://1837879082"
        s.Volume = 3
        s:Play()
        Debris:AddItem(s, 30)
    end
}
end

-- === modules/trolling/func_182_reverse_controls.lua ===
__FACTORIES["modules/trolling/func_182_reverse_controls.lua"] = function()
-- Func #182: Reverse Controls | toggle
local State = { running = false }

return {
    id = "ReverseControls", type = "toggle", name = "Reverse Controls",
    tooltip = "Reverse your controls", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if hum then
                    -- Visual effect through the camera
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/trolling/func_183_fling_random_aura.lua ===
__FACTORIES["modules/trolling/func_183_fling_random_aura.lua"] = function()
-- Func #183: Fling Random Aura | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "FlingRandomAura", type = "toggle", name = "Fling Random Aura",
    tooltip = "Randomly fling nearby players", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(2)
                local myHRP = Utils.getHRP()
                if not myHRP then continue end
                local list = {}
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - myHRP.Position).Magnitude < (Settings.AuraRadius or 15) then
                            table.insert(list, hrp)
                        end
                    end
                end
                if #list > 0 then
                    Utils.fling(list[math.random(1, #list)], Settings.FlingPower or 400)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/trolling/func_184_rainbow_all.lua ===
__FACTORIES["modules/trolling/func_184_rainbow_all.lua"] = function()
-- Func #184: Rainbow All | button
local Players = game:GetService("Players")

return {
    id = "RainbowAll", type = "button", name = "Rainbow All",
    tooltip = "Color all players", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Color = Color3.fromHSV(math.random(), 1, 1)
                    end
                end
            end
        end
    end
}
end

-- === modules/trolling/func_185_neon_all.lua ===
__FACTORIES["modules/trolling/func_185_neon_all.lua"] = function()
-- Func #185: Neon All | button
local Players = game:GetService("Players")

return {
    id = "NeonAll", type = "button", name = "Neon All",
    tooltip = "Make everyone neon", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Material = Enum.Material.Neon
                    end
                end
            end
        end
    end
}
end

-- === modules/trolling/func_186_shrink_all.lua ===
__FACTORIES["modules/trolling/func_186_shrink_all.lua"] = function()
-- Func #186: Shrink All | button
local Players = game:GetService("Players")

return {
    id = "ShrinkAll", type = "button", name = "Shrink All",
    tooltip = "Shrink all players", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.BodyDepthScale.Value = 0.3
                    hum.BodyWidthScale.Value = 0.3
                    hum.BodyHeightScale.Value = 0.3
                end
            end
        end
    end
}
end

-- === modules/trolling/func_187_grow_all.lua ===
__FACTORIES["modules/trolling/func_187_grow_all.lua"] = function()
-- Func #187: Grow All | button
local Players = game:GetService("Players")

return {
    id = "GrowAll", type = "button", name = "Grow All",
    tooltip = "Enlarge all players", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.BodyDepthScale.Value = 3
                    hum.BodyWidthScale.Value = 3
                    hum.BodyHeightScale.Value = 3
                end
            end
        end
    end
}
end

-- === modules/trolling/func_188_head_spin_all.lua ===
__FACTORIES["modules/trolling/func_188_head_spin_all.lua"] = function()
-- Func #188: Head Spin All | button
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

return {
    id = "HeadSpinAll", type = "button", name = "Head Spin All",
    tooltip = "Spin every player's head", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local av = Instance.new("BodyAngularVelocity")
                    av.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    av.AngularVelocity = Vector3.new(0, 50, 0)
                    av.Parent = head
                    Debris:AddItem(av, 5)
                end
            end
        end
    end
}
end

-- === modules/trolling/func_189_random_color_self.lua ===
__FACTORIES["modules/trolling/func_189_random_color_self.lua"] = function()
-- Func #189: Random Color Self | button
return {
    id = "RandomColorSelf", type = "button", name = "Random Color Self",
    tooltip = "Give yourself random colors", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Color = Color3.fromHSV(math.random(), 1, 1)
            end
        end
    end
}
end

-- === modules/trolling/func_190_rainbow_self.lua ===
__FACTORIES["modules/trolling/func_190_rainbow_self.lua"] = function()
-- Func #190: Rainbow Self | toggle
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local State = { running = false, hue = 0, conn = nil }

return {
    id = "RainbowSelf", type = "toggle", name = "Rainbow Self",
    tooltip = "Rainbow colors on your character", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        if State.running then return end
        State.running = true
        State.conn = RunService.Heartbeat:Connect(function(dt)
            if not State.running then return end
            State.hue = (State.hue + dt * 0.3) % 1
            local color = Color3.fromHSV(State.hue, 1, 1)
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.Color = color end
                end
            end
        end)
    end,
    onDisable = function()
        State.running = false
        if State.conn then State.conn:Disconnect(); State.conn = nil end
    end
}
end

-- === modules/trolling/func_191_neon_self.lua ===
__FACTORIES["modules/trolling/func_191_neon_self.lua"] = function()
-- Func #191: Neon Self | button
return {
    id = "NeonSelf", type = "button", name = "Neon Self",
    tooltip = "Make yourself neon", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Material = Enum.Material.Neon end
        end
    end
}
end

-- === modules/trolling/func_192_ghost_self.lua ===
__FACTORIES["modules/trolling/func_192_ghost_self.lua"] = function()
-- Func #192: Ghost Self | button
return {
    id = "GhostSelf", type = "button", name = "Ghost Self",
    tooltip = "Make yourself translucent", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0.5 end
        end
    end
}
end

-- === modules/trolling/func_193_invisible_self.lua ===
__FACTORIES["modules/trolling/func_193_invisible_self.lua"] = function()
-- Func #193: Invisible Self | button
return {
    id = "InvisibleSelf", type = "button", name = "Invisible Self",
    tooltip = "Make yourself invisible", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 1
            end
        end
        for _, acc in pairs(char:GetChildren()) do
            if acc:IsA("Accessory") then
                for _, h in pairs(acc:GetDescendants()) do
                    if h:IsA("BasePart") then h.Transparency = 1 end
                end
            end
        end
    end
}
end

-- === modules/trolling/func_194_visible_self.lua ===
__FACTORIES["modules/trolling/func_194_visible_self.lua"] = function()
-- Func #194: Visible Self | button
return {
    id = "VisibleSelf", type = "button", name = "Visible Self",
    tooltip = "Restore visibility", tab = "Trolling",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0 end
        end
    end
}
end

-- === modules/trolling/func_195_shake_screen_all.lua ===
__FACTORIES["modules/trolling/func_195_shake_screen_all.lua"] = function()
-- Func #195: Shake Screen All | toggle
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local State = { running = false }

return {
    id = "ShakeScreenAll", type = "toggle", name = "Shake Screen All",
    tooltip = "Shake all players' screens", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(1)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        pcall(function()
                            local gui = p.PlayerGui
                            local oldPos = gui.AbsoluteSize
                            -- Can't directly shake other's UI; used as placeholder
                        end)
                    end
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/trolling/func_196_fake_death_all.lua ===
__FACTORIES["modules/trolling/func_196_fake_death_all.lua"] = function()
-- Func #196: Fake Death All | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "FakeDeathAll", type = "button", name = "Fake Death All",
    tooltip = "Simulate everyone's death", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local maxHP = hum.MaxHealth
                    hum.Health = 0
                    task.wait(0.1)
                    hum.Health = maxHP
                end
            end
        end
    end
}
end

-- === modules/trolling/func_197_fire_trail.lua ===
__FACTORIES["modules/trolling/func_197_fire_trail.lua"] = function()
-- Func #197: Fire Trail | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "FireTrail", type = "toggle", name = "Fire Trail",
    tooltip = "Leave a fire trail", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if hrp then
                    local f = Instance.new("Fire", hrp)
                    Debris:AddItem(f, 0.5)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/trolling/func_198_ice_trail.lua ===
__FACTORIES["modules/trolling/func_198_ice_trail.lua"] = function()
-- Func #198: Ice Trail | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "IceTrail", type = "toggle", name = "Ice Trail",
    tooltip = "Leave an ice trail", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.3)
                local hrp = Utils.getHRP()
                if hrp then
                    local s = Instance.new("Smoke", hrp)
                    s.Color = Color3.fromRGB(180, 220, 255)
                    s.Size = 2
                    Debris:AddItem(s, 0.5)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/trolling/func_199_lightning_self.lua ===
__FACTORIES["modules/trolling/func_199_lightning_self.lua"] = function()
-- Func #199: Lightning Self | toggle
local Debris = game:GetService("Debris")
local State = { running = false }

return {
    id = "LightningSelf", type = "toggle", name = "Lightning Self",
    tooltip = "Lightning on your character", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.5)
                local hrp = Utils.getHRP()
                if hrp then
                    local sp = Instance.new("Sparkles", hrp)
                    sp.SparkleColor = Color3.fromRGB(150, 200, 255)
                    Debris:AddItem(sp, 0.6)
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}
end

-- === modules/trolling/func_200_dance_all.lua ===
__FACTORIES["modules/trolling/func_200_dance_all.lua"] = function()
-- Func #200: Dance All | button
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "DanceAll", type = "button", name = "Dance All",
    tooltip = "Make everyone dance", tab = "Trolling",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local animator = p.Character:FindFirstChildOfClass("Animator")
                if not animator then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum then animator = hum:FindFirstChildOfClass("Animator") end
                end
                if animator then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://507771019"
                    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
                    if ok and track then
                        pcall(function() track:Play() end)
                    end
                end
            end
        end
    end
}
end

-- === modules/animations/func_201_play_dance.lua ===
__FACTORIES["modules/animations/func_201_play_dance.lua"] = function()
-- Func #201: Dance
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayDance",
    type    = "button",
    name    = "Dance",
    tooltip = "Play the dance animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_202_play_wave.lua ===
__FACTORIES["modules/animations/func_202_play_wave.lua"] = function()
-- Func #202: Wave
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507770239"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayWave",
    type    = "button",
    name    = "Greeting",
    tooltip = "Play the wave animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_203_play_point.lua ===
__FACTORIES["modules/animations/func_203_play_point.lua"] = function()
-- Func #203: Point
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507770453"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayPoint",
    type    = "button",
    name    = "Point",
    tooltip = "Play the point animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_204_play_laugh.lua ===
__FACTORIES["modules/animations/func_204_play_laugh.lua"] = function()
-- Func #204: Laugh
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507770818"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayLaugh",
    type    = "button",
    name    = "Laugh",
    tooltip = "Play the laugh animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_205_play_cheer.lua ===
__FACTORIES["modules/animations/func_205_play_cheer.lua"] = function()
-- Func #205: Cheer
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507770677"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayCheer",
    type    = "button",
    name    = "Cheer",
    tooltip = "Play the cheer animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_206_play_floss.lua ===
__FACTORIES["modules/animations/func_206_play_floss.lua"] = function()
-- Func #206: Floss
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://5263729371"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayFloss",
    type    = "button",
    name    = "Floss",
    tooltip = "Play the floss animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_207_play_dab.lua ===
__FACTORIES["modules/animations/func_207_play_dab.lua"] = function()
-- Func #207: Dab
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://5057432604"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayDab",
    type    = "button",
    name    = "Dab",
    tooltip = "Play the dab animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_208_play_russian.lua ===
__FACTORIES["modules/animations/func_208_play_russian.lua"] = function()
-- Func #208: Russian dance
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771919"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayRussian",
    type    = "button",
    name    = "Russian dance",
    tooltip = "Play the Russian dance animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_209_play_karate.lua ===
__FACTORIES["modules/animations/func_209_play_karate.lua"] = function()
-- Func #209: Karate
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayKarate",
    type    = "button",
    name    = "Karate",
    tooltip = "Play the karate animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_210_play_salsa.lua ===
__FACTORIES["modules/animations/func_210_play_salsa.lua"] = function()
-- Func #210: Salsa
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771919"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySalsa",
    type    = "button",
    name    = "Salsa",
    tooltip = "Play the salsa animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_211_play_hiphop.lua ===
__FACTORIES["modules/animations/func_211_play_hiphop.lua"] = function()
-- Func #211: Hip-hop
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507772104"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayHipHop",
    type    = "button",
    name    = "Hip-hop",
    tooltip = "Play the hip-hop animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_212_play_breakdance.lua ===
__FACTORIES["modules/animations/func_212_play_breakdance.lua"] = function()
-- Func #212: Breakdance
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayBreakdance",
    type    = "button",
    name    = "Breakdance",
    tooltip = "Play breakdance",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_213_play_robot.lua ===
__FACTORIES["modules/animations/func_213_play_robot.lua"] = function()
-- Func #213: Robot
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507772104"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayRobot",
    type    = "button",
    name    = "Robot",
    tooltip = "Play the robot animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_214_play_backflip.lua ===
__FACTORIES["modules/animations/func_214_play_backflip.lua"] = function()
-- Func #214: Backflip
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://5972881799"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayBackflip",
    type    = "button",
    name    = "Backflip",
    tooltip = "Play a backflip",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_215_play_frontflip.lua ===
__FACTORIES["modules/animations/func_215_play_frontflip.lua"] = function()
-- Func #215: Frontflip
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://5972866182"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayFrontflip",
    type    = "button",
    name    = "Frontflip",
    tooltip = "Play a frontflip",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_216_play_sit.lua ===
__FACTORIES["modules/animations/func_216_play_sit.lua"] = function()
-- Func #216: Sit
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://2506281703"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySit",
    type    = "button",
    name    = "Sit",
    tooltip = "Play the sitting animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_217_play_lay.lua ===
__FACTORIES["modules/animations/func_217_play_lay.lua"] = function()
-- Func #217: Lie down
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayLay",
    type    = "button",
    name    = "Lie down",
    tooltip = "Play the lying-down animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_218_play_crawl.lua ===
__FACTORIES["modules/animations/func_218_play_crawl.lua"] = function()
-- Func #218: Crawl
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507771019"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayCrawl",
    type    = "button",
    name    = "Crawl",
    tooltip = "Play the crawling animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_219_play_sprint_anim.lua ===
__FACTORIES["modules/animations/func_219_play_sprint_anim.lua"] = function()
-- Func #219: Run (animation)
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507767714"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySprintAnim",
    type    = "button",
    name    = "Run (animation)",
    tooltip = "Play the running animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_220_play_swim.lua ===
__FACTORIES["modules/animations/func_220_play_swim.lua"] = function()
-- Func #220: Swim
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507784897"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlaySwim",
    type    = "button",
    name    = "Swim",
    tooltip = "Play the swimming animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_221_play_climb.lua ===
__FACTORIES["modules/animations/func_221_play_climb.lua"] = function()
-- Func #221: Climb
-- Category: Animations | Type: button

local ANIM_ID = "rbxassetid://507765644"

local function playAnim(Settings, Utils)
    local char = Utils.getChar()
    if not char then return end

    local animator = char:FindFirstChildOfClass("Animator")
    if not animator then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then animator = hum:FindFirstChildOfClass("Animator") end
    end
    if not animator then return end

    if _G.ResonanceCurrentAnim then
        pcall(function() _G.ResonanceCurrentAnim:Stop() end)
        _G.ResonanceCurrentAnim = nil
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return end

    pcall(function()
        track.Priority = Enum.AnimationPriority[Settings.AnimPriority or "Action"]
    end)
    track.Looped = Settings.AnimLoop ~= false
    track:Play(0.1, 1, Settings.AnimSpeed or 1)

    _G.ResonanceCurrentAnim = track
end

return {
    id      = "PlayClimb",
    type    = "button",
    name    = "Climb",
    tooltip = "Play the climbing animation",
    tab     = "Animations",
    onClick = playAnim
}
end

-- === modules/animations/func_222_stop_all_anims.lua ===
__FACTORIES["modules/animations/func_222_stop_all_anims.lua"] = function()
-- Func #222: Stop All Anims
-- Category: Animations | Type: button

return {
    id = "StopAllAnims", type = "button", name = "Stop all animations",
    tooltip = "Stop all currently playing character animation tracks",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0.1) end)
        end
        _G.ResonanceCurrentAnim = nil
    end
}
end

-- === modules/animations/func_223_free_anims_off.lua ===
__FACTORIES["modules/animations/func_223_free_anims_off.lua"] = function()
-- Func #223: Free Animations Off
-- Category: Animations | Type: toggle
-- Disable default movement animations

return {
    id = "FreeAnimsOff", type = "toggle", name = "Free Animations Off",
    tooltip = "Disable movement animations (walk/idle/jump)",
    tab = "Animations", default = false,
    onEnable = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, t in pairs(hum:GetPlayingAnimationTracks()) do
                pcall(function() t:Stop(0.2) end)
            end
        end
    end,
    onDisable = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = false end
    end
}
end

-- === modules/animations/func_224_anim_speed_up.lua ===
__FACTORIES["modules/animations/func_224_anim_speed_up.lua"] = function()
-- Func #224: Anim Speed Up
-- Category: Animations | Type: button

return {
    id = "AnimSpeedUp", type = "button", name = "Speed up animations",
    tooltip = "Increase animation speed by +0.25x",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        Settings.AnimSpeed = math.min(5, (Settings.AnimSpeed or 1) + 0.25)
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:AdjustSpeed(Settings.AnimSpeed) end)
        end
        Utils.notify("Resonance", "Anim Speed: " .. Settings.AnimSpeed .. "x", Settings)
    end
}
end

-- === modules/animations/func_225_anim_slow_down.lua ===
__FACTORIES["modules/animations/func_225_anim_slow_down.lua"] = function()
-- Func #225: Anim Slow Down
-- Category: Animations | Type: button

return {
    id = "AnimSlowDown", type = "button", name = "Slow down animations",
    tooltip = "Decrease animation speed by -0.25x",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        Settings.AnimSpeed = math.max(0.1, (Settings.AnimSpeed or 1) - 0.25)
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:AdjustSpeed(Settings.AnimSpeed) end)
        end
        Utils.notify("Resonance", "Anim Speed: " .. Settings.AnimSpeed .. "x", Settings)
    end
}
end

-- === modules/kick/func_226_kick_all.lua ===
__FACTORIES["modules/kick/func_226_kick_all.lua"] = function()
-- Func #226: Kick All
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
    id = "KickAll", type = "button", name = "Kick All",
    tooltip = "Attempt to kick all players", tab = "Kick",
    onClick = function(Settings, Utils)
        task.wait((Settings.KickDelay or 0) / 1000)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if not fireKick(p, Settings.KickReason or "Kicked") then
                    pseudoKick(p)
                end
            end
        end
    end
}
end

-- === modules/kick/func_227_kick_closest.lua ===
__FACTORIES["modules/kick/func_227_kick_closest.lua"] = function()
-- Func #227: Kick Closest
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
    id = "KickClosest", type = "button", name = "Kick Closest",
    tooltip = "Kick the nearest player", tab = "Kick",
    onClick = function(Settings, Utils)
        local target = Utils.getClosestPlayer(Settings)
        if not target then return end
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}
end

-- === modules/kick/func_228_kick_random.lua ===
__FACTORIES["modules/kick/func_228_kick_random.lua"] = function()
-- Func #228: Kick Random
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
    id = "KickRandom", type = "button", name = "Kick Random",
    tooltip = "Kick a random player", tab = "Kick",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}
end

-- === modules/kick/func_229_kick_by_name.lua ===
__FACTORIES["modules/kick/func_229_kick_by_name.lua"] = function()
-- Func #229: Kick By Name
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
    id = "KickByName", type = "button", name = "Kick By Name",
    tooltip = "Kick by username from Targeting", tab = "Kick",
    onClick = function(Settings, Utils)
        local target = Players:FindFirstChild(Settings.TargetName or "")
        if not target then return end
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}
end

-- === modules/kick/func_230_kick_farthest.lua ===
__FACTORIES["modules/kick/func_230_kick_farthest.lua"] = function()
-- Func #230: Kick Farthest
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
    id = "KickFarthest", type = "button", name = "Kick Farthest",
    tooltip = "Kick the farthest player", tab = "Kick",
    onClick = function(Settings, Utils)
        local target = Utils.getFarthestPlayer(Settings)
        if not target then return end
        task.wait((Settings.KickDelay or 0) / 1000)
        if not fireKick(target, Settings.KickReason) then pseudoKick(target) end
    end
}
end

-- === modules/kick/func_231_kick_lowest_hp.lua ===
__FACTORIES["modules/kick/func_231_kick_lowest_hp.lua"] = function()
-- Func #231: Kick Lowest HP
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
    id = "KickLowestHP", type = "button", name = "Kick Lowest HP",
    tooltip = "Kick the player with the least HP", tab = "Kick",
    onClick = function(Settings, Utils)
        local best, hp = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health < hp then hp = h.Health; best = p end
            end
        end
        if best then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(best, Settings.KickReason) then pseudoKick(best) end
        end
    end
}
end

-- === modules/kick/func_232_kick_highest_hp.lua ===
__FACTORIES["modules/kick/func_232_kick_highest_hp.lua"] = function()
-- Func #232: Kick Highest HP
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
    id = "KickHighestHP", type = "button", name = "Kick Highest HP",
    tooltip = "Kick the player with the most HP", tab = "Kick",
    onClick = function(Settings, Utils)
        local best, hp = nil, -1
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health > hp then hp = h.Health; best = p end
            end
        end
        if best then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(best, Settings.KickReason) then pseudoKick(best) end
        end
    end
}
end

-- === modules/kick/func_233_kick_friend.lua ===
__FACTORIES["modules/kick/func_233_kick_friend.lua"] = function()
-- Func #233: Kick Friend
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
    id = "KickFriend", type = "button", name = "Kick Friend",
    tooltip = "Kick a friend", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
                if ok and isFriend then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                    return
                end
            end
        end
    end
}
end

-- === modules/kick/func_234_kick_non_friend.lua ===
__FACTORIES["modules/kick/func_234_kick_non_friend.lua"] = function()
-- Func #234: Kick Non-Friend
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
    id = "KickNonFriend", type = "button", name = "Kick Non-Friend",
    tooltip = "Kick a non-friend", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
                if not ok or not isFriend then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                    return
                end
            end
        end
    end
}
end

-- === modules/kick/func_235_kick_team.lua ===
__FACTORIES["modules/kick/func_235_kick_team.lua"] = function()
-- Func #235: Kick Team
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
    id = "KickTeam", type = "button", name = "Kick Team",
    tooltip = "Kick allies", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Team == LocalPlayer.Team then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_236_kick_enemy_team.lua ===
__FACTORIES["modules/kick/func_236_kick_enemy_team.lua"] = function()
-- Func #236: Kick Enemy Team
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
    id = "KickEnemyTeam", type = "button", name = "Kick Enemy Team",
    tooltip = "Kick enemies", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Team ~= LocalPlayer.Team then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_237_kick_afk.lua ===
__FACTORIES["modules/kick/func_237_kick_afk.lua"] = function()
-- Func #237: Kick AFK
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
    id = "KickAfk", type = "button", name = "Kick AFK",
    tooltip = "Kick AFK players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude == 0 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_238_kick_talking.lua ===
__FACTORIES["modules/kick/func_238_kick_talking.lua"] = function()
-- Func #238: Kick Talking
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
    id = "KickTalking", type = "button", name = "Kick Talking",
    tooltip = "Kick players who are typing", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                -- Heuristic: players with chat open
                if p:GetAttribute("IsTalking") or (p.Character and p.Character:GetAttribute("Talking")) then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_239_kick_silent.lua ===
__FACTORIES["modules/kick/func_239_kick_silent.lua"] = function()
-- Func #239: Kick Silent
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
    id = "KickSilent", type = "button", name = "Kick Silent",
    tooltip = "Kick everyone except players who are typing", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if not (p:GetAttribute("IsTalking") or (p.Character and p.Character:GetAttribute("Talking"))) then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_240_kick_walking.lua ===
__FACTORIES["modules/kick/func_240_kick_walking.lua"] = function()
-- Func #240: Kick Walking
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
    id = "KickWalking", type = "button", name = "Kick Walking",
    tooltip = "Kick walking players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude > 0 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_241_kick_standing.lua ===
__FACTORIES["modules/kick/func_241_kick_standing.lua"] = function()
-- Func #241: Kick Standing
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
    id = "KickStanding", type = "button", name = "Kick Standing",
    tooltip = "Kick stationary players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.MoveDirection.Magnitude == 0 and hum.FloorMaterial ~= Enum.Material.Air then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_242_kick_jumping.lua ===
__FACTORIES["modules/kick/func_242_kick_jumping.lua"] = function()
-- Func #242: Kick Jumping
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
    id = "KickJumping", type = "button", name = "Kick Jumping",
    tooltip = "Kick jumping players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.FloorMaterial == Enum.Material.Air then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_243_kick_flying.lua ===
__FACTORIES["modules/kick/func_243_kick_flying.lua"] = function()
-- Func #243: Kick Flying
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
    id = "KickFlying", type = "button", name = "Kick Flying",
    tooltip = "Kick flying players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Velocity.Magnitude > 100 and hrp.Position.Y > 30 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_244_kick_glitched.lua ===
__FACTORIES["modules/kick/func_244_kick_glitched.lua"] = function()
-- Func #244: Kick Glitched
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
    id = "KickGlitched", type = "button", name = "Kick Glitched",
    tooltip = "Kick stuck players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Position.Y < -50 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_245_kick_invisible.lua ===
__FACTORIES["modules/kick/func_245_kick_invisible.lua"] = function()
-- Func #245: Kick Invisible
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
    id = "KickInvisible", type = "button", name = "Kick Invisible",
    tooltip = "Kick invisible players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Transparency > 0.9 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_246_kick_visible.lua ===
__FACTORIES["modules/kick/func_246_kick_visible.lua"] = function()
-- Func #246: Kick Visible
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
    id = "KickVisible", type = "button", name = "Kick Visible",
    tooltip = "Kick visible players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Transparency < 0.5 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_247_kick_high_ping.lua ===
__FACTORIES["modules/kick/func_247_kick_high_ping.lua"] = function()
-- Func #247: Kick High Ping
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
    id = "KickHighPing", type = "button", name = "Kick High Ping",
    tooltip = "Kick players with high ping", tab = "Kick",
    onClick = function(Settings, Utils)
        local worst, ping = nil, -1
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local pp = p:GetNetworkPing() * 1000
                if pp > ping then ping = pp; worst = p end
            end
        end
        if worst then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(worst, Settings.KickReason) then pseudoKick(worst) end
        end
    end
}
end

-- === modules/kick/func_248_kick_low_ping.lua ===
__FACTORIES["modules/kick/func_248_kick_low_ping.lua"] = function()
-- Func #248: Kick Low Ping
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
    id = "KickLowPing", type = "button", name = "Kick Low Ping",
    tooltip = "Kick players with low ping", tab = "Kick",
    onClick = function(Settings, Utils)
        local best, ping = nil, math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local pp = p:GetNetworkPing() * 1000
                if pp < ping then ping = pp; best = p end
            end
        end
        if best then
            task.wait((Settings.KickDelay or 0) / 1000)
            if not fireKick(best, Settings.KickReason) then pseudoKick(best) end
        end
    end
}
end

-- === modules/kick/func_249_kick_mobile.lua ===
__FACTORIES["modules/kick/func_249_kick_mobile.lua"] = function()
-- Func #249: Kick Mobile
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
    id = "KickMobile", type = "button", name = "Kick Mobile",
    tooltip = "Kick mobile players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, result = pcall(function() return p:GetAttribute("IsMobile") end)
                if ok and result then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_250_kick_pc.lua ===
__FACTORIES["modules/kick/func_250_kick_pc.lua"] = function()
-- Func #250: Kick PC
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
    id = "KickPC", type = "button", name = "Kick PC",
    tooltip = "Kick PC players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if not p:GetAttribute("IsMobile") and not p:GetAttribute("IsConsole") and not p:GetAttribute("IsVR") then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_251_kick_console.lua ===
__FACTORIES["modules/kick/func_251_kick_console.lua"] = function()
-- Func #251: Kick Console
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
    id = "KickConsole", type = "button", name = "Kick Console",
    tooltip = "Kick console players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, result = pcall(function() return p:GetAttribute("IsConsole") end)
                if ok and result then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_252_kick_vr.lua ===
__FACTORIES["modules/kick/func_252_kick_vr.lua"] = function()
-- Func #252: Kick VR
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
    id = "KickVR", type = "button", name = "Kick VR",
    tooltip = "Kick VR players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, result = pcall(function() return p:GetAttribute("IsVR") end)
                if ok and result then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_253_kick_guest.lua ===
__FACTORIES["modules/kick/func_253_kick_guest.lua"] = function()
-- Func #253: Kick Guest
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
    id = "KickGuest", type = "button", name = "Kick Guest",
    tooltip = "Kick guests", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Name:lower():find("guest") then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_254_kick_premium.lua ===
__FACTORIES["modules/kick/func_254_kick_premium.lua"] = function()
-- Func #254: Kick Premium
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
    id = "KickPremium", type = "button", name = "Kick Premium",
    tooltip = "Kick Premium players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.MembershipType == Enum.MembershipType.Premium then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_255_kick_non_premium.lua ===
__FACTORIES["modules/kick/func_255_kick_non_premium.lua"] = function()
-- Func #255: Kick Non-Premium
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
    id = "KickNonPremium", type = "button", name = "Kick Non-Premium",
    tooltip = "Kick non-Premium players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.MembershipType == Enum.MembershipType.None then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_256_kick_verified.lua ===
__FACTORIES["modules/kick/func_256_kick_verified.lua"] = function()
-- Func #256: Kick Verified
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
    id = "KickVerified", type = "button", name = "Kick Verified",
    tooltip = "Kick verified players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.HasVerifiedBadge then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_257_kick_non_verified.lua ===
__FACTORIES["modules/kick/func_257_kick_non_verified.lua"] = function()
-- Func #257: Kick Non-Verified
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
    id = "KickNonVerified", type = "button", name = "Kick Non-Verified",
    tooltip = "Kick unverified players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and not p.HasVerifiedBadge then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_258_kick_with_hats.lua ===
__FACTORIES["modules/kick/func_258_kick_with_hats.lua"] = function()
-- Func #258: Kick With Hats
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
    id = "KickWithHats", type = "button", name = "Kick With Hats",
    tooltip = "Kick players with hats", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hasHat = false
                for _, a in pairs(p.Character:GetChildren()) do
                    if a:IsA("Accessory") then hasHat = true; break end
                end
                if hasHat then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_259_kick_without_hats.lua ===
__FACTORIES["modules/kick/func_259_kick_without_hats.lua"] = function()
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
end

-- === modules/kick/func_260_kick_with_tools.lua ===
__FACTORIES["modules/kick/func_260_kick_with_tools.lua"] = function()
-- Func #260: Kick With Tools
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
    id = "KickWithTools", type = "button", name = "Kick With Tools",
    tooltip = "Kick players with tools", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChildOfClass("Tool") then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_261_kick_without_tools.lua ===
__FACTORIES["modules/kick/func_261_kick_without_tools.lua"] = function()
-- Func #261: Kick Without Tools
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
    id = "KickWithoutTools", type = "button", name = "Kick Without Tools",
    tooltip = "Kick players without tools", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not p.Character:FindFirstChildOfClass("Tool") then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_262_kick_rich.lua ===
__FACTORIES["modules/kick/func_262_kick_rich.lua"] = function()
-- Func #262: Kick Rich
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
    id = "KickRich", type = "button", name = "Kick Rich",
    tooltip = "Kick Rich players (by attribute)", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Robux") end)
                if ok and type(val) == "number" and val > 1000 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_263_kick_poor.lua ===
__FACTORIES["modules/kick/func_263_kick_poor.lua"] = function()
-- Func #263: Kick Poor
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
    id = "KickPoor", type = "button", name = "Kick Poor",
    tooltip = "Kick Poor players (by attribute)", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Robux") end)
                if ok and type(val) == "number" and val <= 0 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_264_kick_high_level.lua ===
__FACTORIES["modules/kick/func_264_kick_high_level.lua"] = function()
-- Func #264: Kick High Level
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
    id = "KickHighLevel", type = "button", name = "Kick High Level",
    tooltip = "Kick high-level players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Level") end)
                if ok and type(val) == "number" and val > 100 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_265_kick_low_level.lua ===
__FACTORIES["modules/kick/func_265_kick_low_level.lua"] = function()
-- Func #265: Kick Low Level
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
    id = "KickLowLevel", type = "button", name = "Kick Low Level",
    tooltip = "Kick low-level players", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, val = pcall(function() return p:GetAttribute("Level") end)
                if ok and type(val) == "number" and val < 10 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_266_kick_owner.lua ===
__FACTORIES["modules/kick/func_266_kick_owner.lua"] = function()
-- Func #266: Kick Owner
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
    id = "KickOwner", type = "button", name = "Kick Owner",
    tooltip = "Kick the place owner", tab = "Kick",
    onClick = function(Settings, Utils)
        local placeOwnerId = game.CreatorId
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.UserId == placeOwnerId then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_267_kick_admin.lua ===
__FACTORIES["modules/kick/func_267_kick_admin.lua"] = function()
-- Func #267: Kick Admin
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
    id = "KickAdmin", type = "button", name = "Kick Admin",
    tooltip = "Kick group admins", tab = "Kick",
    onClick = function(Settings, Utils)
        local groupId = game.CreatorType == Enum.CreatorType.Group and game.CreatorId or 0
        if groupId == 0 then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local ok, rank = pcall(function() return p:GetRankInGroup(groupId) end)
                if ok and rank >= 200 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_268_kick_moderator.lua ===
__FACTORIES["modules/kick/func_268_kick_moderator.lua"] = function()
-- Func #268: Kick Moderator
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
    id = "KickModerator", type = "button", name = "Kick Moderator",
    tooltip = "Kick moderators", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local rank = 0
                for _, gid in pairs({game.CreatorId}) do
                    local ok, r = pcall(function() return p:GetRankInGroup(gid) end)
                    if ok and r > rank then rank = r end
                end
                if rank >= 100 and rank < 200 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_269_kick_staff.lua ===
__FACTORIES["modules/kick/func_269_kick_staff.lua"] = function()
-- Func #269: Kick Staff
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
    id = "KickStaff", type = "button", name = "Kick Staff",
    tooltip = "Kick any staff member", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local maxRank = 0
                for _, gid in pairs({game.CreatorId}) do
                    local ok, r = pcall(function() return p:GetRankInGroup(gid) end)
                    if ok and r > maxRank then maxRank = r end
                end
                if maxRank >= 100 then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_270_kick_bots.lua ===
__FACTORIES["modules/kick/func_270_kick_bots.lua"] = function()
-- Func #270: Kick Bots
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
    id = "KickBots", type = "button", name = "Kick Bots",
    tooltip = "Kick bots", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if p:GetAttribute("IsBot") or p.DisplayName:lower():find("bot") then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === modules/kick/func_271_kick_alts.lua ===
__FACTORIES["modules/kick/func_271_kick_alts.lua"] = function()
-- Func #271: Kick Alts
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
    id = "KickAlts", type = "button", name = "Kick Alts",
    tooltip = "Kick alt accounts (AccountAge < 30)", tab = "Kick",
    onClick = function(Settings, Utils)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.AccountAge < 30 then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_272_kick_by_userid.lua ===
__FACTORIES["modules/kick/func_272_kick_by_userid.lua"] = function()
-- Func #272: Kick By UserID
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
    id = "KickByUserId", type = "button", name = "Kick By UserID",
    tooltip = "Kick by UserID from Targeting", tab = "Kick",
    onClick = function(Settings, Utils)
        local targetId = tonumber(Settings.TargetUserId or 0)
        if targetId == 0 then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.UserId == targetId then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_273_kick_by_display_name.lua ===
__FACTORIES["modules/kick/func_273_kick_by_display_name.lua"] = function()
-- Func #273: Kick By DisplayName
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
    id = "KickByDisplayName", type = "button", name = "Kick By DisplayName",
    tooltip = "Kick by DisplayName", tab = "Kick",
    onClick = function(Settings, Utils)
        local targetName = Settings.TargetDisplayName or ""
        if targetName == "" then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.DisplayName:lower() == targetName:lower() then
                task.wait((Settings.KickDelay or 0) / 1000)
                if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
            end
        end
    end
}
end

-- === modules/kick/func_274_kick_multiple.lua ===
__FACTORIES["modules/kick/func_274_kick_multiple.lua"] = function()
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
end

-- === modules/kick/func_275_kick_blacklist.lua ===
__FACTORIES["modules/kick/func_275_kick_blacklist.lua"] = function()
-- Func #275: Kick Blacklist
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local BLACKLIST = {}  -- UserIds can be added here

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
    id = "KickBlacklist", type = "button", name = "Kick Blacklist",
    tooltip = "Kick blacklisted players", tab = "Kick",
    onClick = function(Settings, Utils)
        local bl = Settings.Blacklist or BLACKLIST
        if not bl then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                if bl[p.UserId] or bl[p.Name] then
                    task.wait((Settings.KickDelay or 0) / 1000)
                    if not fireKick(p, Settings.KickReason) then pseudoKick(p) end
                end
            end
        end
    end
}
end

-- === runtime.lua ===
__FACTORIES["runtime.lua"] = function()
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
end

-- === core/settings/option_01_reach_distance.lua ===
__FACTORIES["core/settings/option_01_reach_distance.lua"] = function()
return {
    id = "ReachDistance", type = "slider", name = "Reach Distance",
    section = "Distances", tab = "Main",
    default = 20, range = {1, 1000}, increment = 1, suffix = " studs",
    tooltip = "Object or player grab distance",
    onChanged = function(v, S) S.ReachDistance = v end
}
end

-- === core/settings/option_02_throw_power_multiplier.lua ===
__FACTORIES["core/settings/option_02_throw_power_multiplier.lua"] = function()
return {
    id = "ThrowPowerMult", type = "slider", name = "Throw Power Multiplier",
    section = "Distances", tab = "Main",
    default = 1.0, range = {0.1, 10}, increment = 0.1, suffix = "x",
    tooltip = "Throw power multiplier",
    onChanged = function(v, S) S.ThrowPowerMult = v end
}
end

-- === core/settings/option_03_fling_power.lua ===
__FACTORIES["core/settings/option_03_fling_power.lua"] = function()
return {
    id = "FlingPower", type = "slider", name = "Fling Power",
    section = "Distances", tab = "Combat",
    default = 300, range = {50, 1000}, increment = 10, suffix = " p",
    tooltip = "Fling power",
    onChanged = function(v, S) S.FlingPower = v end
}
end

-- === core/settings/option_04_spin_rpm.lua ===
__FACTORIES["core/settings/option_04_spin_rpm.lua"] = function()
return {
    id = "SpinRPM", type = "slider", name = "Spin RPM",
    section = "Tornado", tab = "Auras",
    default = 60, range = {10, 500}, increment = 10, suffix = " RPM",
    tooltip = "Spin speed",
    onChanged = function(v, S) S.SpinRPM = v end
}
end

-- === core/settings/option_05_spin_radius.lua ===
__FACTORIES["core/settings/option_05_spin_radius.lua"] = function()
return {
    id = "SpinRadius", type = "slider", name = "Spin Radius",
    section = "Tornado", tab = "Auras",
    default = 5, range = {1, 50}, increment = 1, suffix = " studs",
    tooltip = "Orbit radius around you",
    onChanged = function(v, S) S.SpinRadius = v end
}
end

-- === core/settings/option_06_aura_radius.lua ===
__FACTORIES["core/settings/option_06_aura_radius.lua"] = function()
return {
    id = "AuraRadius", type = "slider", name = "Aura Radius",
    section = "Aura", tab = "Auras",
    default = 15, range = {1, 100}, increment = 1, suffix = " studs",
    tooltip = "Aura range",
    onChanged = function(v, S) S.AuraRadius = v end
}
end

-- === core/settings/option_07_loop_delay.lua ===
__FACTORIES["core/settings/option_07_loop_delay.lua"] = function()
return {
    id = "LoopDelay", type = "slider", name = "Loop Delay",
    section = "Performance", tab = "Main",
    default = 100, range = {10, 1000}, increment = 10, suffix = " ms",
    tooltip = "Delay between loops",
    onChanged = function(v, S) S.LoopDelay = v end
}
end

-- === core/settings/option_08_walk_speed.lua ===
__FACTORIES["core/settings/option_08_walk_speed.lua"] = function()
return {
    id = "WalkSpeed", type = "slider", name = "WalkSpeed",
    section = "Movement", tab = "Movement",
    default = 16, range = {16, 500}, increment = 1, suffix = " studs",
    tooltip = "Movement speed",
    onChanged = function(v, S)
        S.WalkSpeed = v
        local p = game:GetService("Players").LocalPlayer
        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = v end
    end
}
end

-- === core/settings/option_09_jump_power.lua ===
__FACTORIES["core/settings/option_09_jump_power.lua"] = function()
return {
    id = "JumpPower", type = "slider", name = "JumpPower",
    section = "Movement", tab = "Movement",
    default = 50, range = {50, 500}, increment = 1, suffix = " studs",
    tooltip = "Jump power",
    onChanged = function(v, S)
        S.JumpPower = v
        local p = game:GetService("Players").LocalPlayer
        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if h then h.JumpPower = v end
    end
}
end

-- === core/settings/option_10_fly_speed.lua ===
__FACTORIES["core/settings/option_10_fly_speed.lua"] = function()
return {
    id = "FlySpeed", type = "slider", name = "Fly Speed",
    section = "Movement", tab = "Movement",
    default = 50, range = {10, 500}, increment = 5, suffix = " studs",
    tooltip = "Fly speed",
    onChanged = function(v, S) S.FlySpeed = v end
}
end

-- === core/settings/option_11_gravity.lua ===
__FACTORIES["core/settings/option_11_gravity.lua"] = function()
return {
    id = "Gravity", type = "slider", name = "Gravity",
    section = "Physics", tab = "Movement",
    default = 196.2, range = {0, 500}, increment = 10, suffix = "",
    tooltip = "World gravity",
    onChanged = function(v, S)
        S.Gravity = v
        game:GetService("Workspace").Gravity = v
    end
}
end

-- === core/settings/option_12_aura_type.lua ===
__FACTORIES["core/settings/option_12_aura_type.lua"] = function()
return {
    id = "AuraType", type = "dropdown", name = "Aura Type",
    section = "Aura", tab = "Auras",
    default = "Fling", options = {"Fling","Kill","Freeze","Fire","Void"},
    multiple = false,
    tooltip = "Aura mode",
    onChanged = function(opt, S) S.AuraType = opt[1] end
}
end

-- === core/settings/option_13_punishment_type.lua ===
__FACTORIES["core/settings/option_13_punishment_type.lua"] = function()
return {
    id = "PunishmentType", type = "dropdown", name = "Punishment Type",
    section = "Grab", tab = "Combat",
    default = "Insta-Kill",
    options = {"Insta-Kill","Void Teleport","Ragdoll","Orbit","Burn"},
    multiple = false,
    tooltip = "Punishment when grabbed",
    onChanged = function(opt, S) S.PunishmentType = opt[1] end
}
end

-- === core/settings/option_14_line_material.lua ===
__FACTORIES["core/settings/option_14_line_material.lua"] = function()
return {
    id = "LineMaterial", type = "dropdown", name = "Line Material",
    section = "Grab", tab = "Combat",
    default = "Neon",
    options = {"Neon","Forcefield","Glass","Invisible"},
    multiple = false,
    tooltip = "Grab beam material",
    onChanged = function(opt, S) S.LineMaterial = opt[1] end
}
end

-- === core/settings/option_15_target_lock_method.lua ===
__FACTORIES["core/settings/option_15_target_lock_method.lua"] = function()
return {
    id = "TargetLockMethod", type = "dropdown", name = "Target Lock Method",
    section = "Aiming", tab = "Combat",
    default = "Nearest player",
    options = {"By cursor","Nearest player","By username from the list"},
    multiple = false,
    tooltip = "Aim assist algorithm",
    onChanged = function(opt, S) S.TargetLockMethod = opt[1] end
}
end

-- === core/settings/option_16_whitelist_friends.lua ===
__FACTORIES["core/settings/option_16_whitelist_friends.lua"] = function()
return {
    id = "WhitelistFriends", type = "toggle", name = "Whitelist Friends",
    section = "Exclusions", tab = "Filters",
    default = true,
    tooltip = "Ignore your friends",
    onChanged = function(v, S) S.WhitelistFriends = v end
}
end

-- === core/settings/option_17_whitelist_plots.lua ===
__FACTORIES["core/settings/option_17_whitelist_plots.lua"] = function()
return {
    id = "WhitelistPlots", type = "toggle", name = "Whitelist Plots",
    section = "Exclusions", tab = "Filters",
    default = false,
    tooltip = "Leave players on their plots alone",
    onChanged = function(v, S) S.WhitelistPlots = v end
}
end

-- === core/settings/option_18_auto_leave_staff.lua ===
__FACTORIES["core/settings/option_18_auto_leave_staff.lua"] = function()
return {
    id = "AutoLeaveStaff", type = "toggle", name = "Auto-Leave on Staff",
    section = "Exclusions", tab = "Filters",
    default = false,
    tooltip = "Leave immediately when a moderator is detected",
    onChanged = function(v, S) S.AutoLeaveStaff = v end
}
end

-- === core/settings/option_19_rgb_mode.lua ===
__FACTORIES["core/settings/option_19_rgb_mode.lua"] = function()
return {
    id = "RGBMode", type = "toggle", name = "RGB / Rainbow Mode",
    section = "Visuals", tab = "Visuals",
    default = false,
    tooltip = "Cycle elements through all colors",
    onChanged = function(v, S) S.RGBMode = v end
}
end

-- === core/settings/option_20_esp_boxes.lua ===
__FACTORIES["core/settings/option_20_esp_boxes.lua"] = function()
return {
    id = "ESPBoxes", type = "toggle", name = "ESP Boxes",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Boxes around players",
    onChanged = function(v, S) S.ESPBoxes = v end
}
end

-- === core/settings/option_21_esp_tracers.lua ===
__FACTORIES["core/settings/option_21_esp_tracers.lua"] = function()
return {
    id = "ESPTracers", type = "toggle", name = "ESP Tracers",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Lines from the bottom of the screen to players",
    onChanged = function(v, S) S.ESPTracers = v end
}
end

-- === core/settings/option_22_esp_info.lua ===
__FACTORIES["core/settings/option_22_esp_info.lua"] = function()
return {
    id = "ESPInfo", type = "toggle", name = "Player Info",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Name, HP, and distance",
    onChanged = function(v, S) S.ESPInfo = v end
}
end

-- === core/settings/option_23_esp_team_check.lua ===
__FACTORIES["core/settings/option_23_esp_team_check.lua"] = function()
return {
    id = "ESPTeamCheck", type = "toggle", name = "Team Check",
    section = "ESP", tab = "Visuals",
    default = true,
    tooltip = "Hide allies",
    onChanged = function(v, S) S.ESPTeamCheck = v end
}
end

-- === core/settings/option_24_fullbright.lua ===
__FACTORIES["core/settings/option_24_fullbright.lua"] = function()
return {
    id = "Fullbright", type = "toggle", name = "Fullbright",
    section = "Lighting", tab = "Visuals",
    default = false,
    tooltip = "Full brightness",
    onChanged = function(v, S)
        S.Fullbright = v
        local L = game:GetService("Lighting")
        L.Ambient = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
        L.OutdoorAmbient = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
    end
}
end

-- === core/settings/option_25_anti_grab.lua ===
__FACTORIES["core/settings/option_25_anti_grab.lua"] = function()
return {
    id = "AntiGrab", type = "toggle", name = "Anti-Grab",
    section = "Protection", tab = "Protection",
    default = true,
    tooltip = "Immunity to other players' grabs",
    onChanged = function(v, S) S.AntiGrab = v end
}
end

-- === core/settings/option_26_anti_fling.lua ===
__FACTORIES["core/settings/option_26_anti_fling.lua"] = function()
return {
    id = "AntiFling", type = "toggle", name = "Anti-Fling",
    section = "Protection", tab = "Protection",
    default = true,
    tooltip = "Fling immunity",
    onChanged = function(v, S) S.AntiFling = v end
}
end

-- === core/settings/option_27_anti_void.lua ===
__FACTORIES["core/settings/option_27_anti_void.lua"] = function()
return {
    id = "AntiVoid", type = "toggle", name = "Anti-Void",
    section = "Protection", tab = "Protection",
    default = true,
    tooltip = "Automatically return after falling below the map",
    onChanged = function(v, S) S.AntiVoid = v end
}
end

-- === core/settings/option_28_auto_rejoin.lua ===
__FACTORIES["core/settings/option_28_auto_rejoin.lua"] = function()
return {
    id = "AutoRejoin", type = "toggle", name = "Auto Rejoin",
    section = "Server", tab = "Server",
    default = false,
    tooltip = "Automatically rejoin after being kicked",
    onChanged = function(v, S) S.AutoRejoin = v end
}
end

-- === core/settings/option_29_notifications.lua ===
__FACTORIES["core/settings/option_29_notifications.lua"] = function()
return {
    id = "Notifications", type = "toggle", name = "Notifications",
    section = "Interface", tab = "Settings",
    default = true,
    tooltip = "Show popup notifications",
    onChanged = function(v, S) S.Notifications = v end
}
end

-- === core/settings/option_30_keybind.lua ===
__FACTORIES["core/settings/option_30_keybind.lua"] = function()
return {
    id = "Keybind", type = "keybind", name = "Menu Keybind",
    section = "Interface", tab = "Settings",
    default = "RightShift",
    tooltip = "Menu toggle key",
    onChanged = function(v, S) S.Keybind = v end
}
end

-- === core/settings/option_31_animation_pack.lua ===
__FACTORIES["core/settings/option_31_animation_pack.lua"] = function()
return {
    id = "AnimPack", type = "dropdown", name = "Animation Pack",
    section = "Animations", tab = "Animations",
    default = "Default",
    options = {"Default","Cartoony","Ninja","Mage","Toy","Superhero","Pirate","Zombie","Robot","Rthro"},
    multiple = false,
    tooltip = "Character animation pack",
    onChanged = function(opt, S) S.AnimPack = opt[1] end
}
end

-- === core/settings/option_32_animation_speed.lua ===
__FACTORIES["core/settings/option_32_animation_speed.lua"] = function()
return {
    id = "AnimSpeed", type = "slider", name = "Animation Speed",
    section = "Animations", tab = "Animations",
    default = 1, range = {0.1, 5}, increment = 0.1, suffix = "x",
    tooltip = "Animation playback speed",
    onChanged = function(v, S) S.AnimSpeed = v end
}
end

-- === core/settings/option_33_animation_loop.lua ===
__FACTORIES["core/settings/option_33_animation_loop.lua"] = function()
return {
    id = "AnimLoop", type = "toggle", name = "Loop Animations",
    section = "Animations", tab = "Animations",
    default = true,
    tooltip = "Loop the animation",
    onChanged = function(v, S) S.AnimLoop = v end
}
end

-- === core/settings/option_34_animation_priority.lua ===
__FACTORIES["core/settings/option_34_animation_priority.lua"] = function()
return {
    id = "AnimPriority", type = "dropdown", name = "Animation Priority",
    section = "Animations", tab = "Animations",
    default = "Action",
    options = {"Idle","Movement","Action","Action2","Action3","Action4","Core"},
    multiple = false,
    tooltip = "Animation priority",
    onChanged = function(opt, S) S.AnimPriority = opt[1] end
}
end

-- === core/settings/option_35_animation_blend.lua ===
__FACTORIES["core/settings/option_35_animation_blend.lua"] = function()
return {
    id = "AnimBlend", type = "slider", name = "Blend Weight",
    section = "Animations", tab = "Animations",
    default = 1, range = {0, 1}, increment = 0.05, suffix = " w",
    tooltip = "Animation blend weight",
    onChanged = function(v, S) S.AnimBlend = v end
}
end

-- === core/settings/option_36_kick_message.lua ===
__FACTORIES["core/settings/option_36_kick_message.lua"] = function()
return {
    id = "KickMessage", type = "input", name = "Kick Message",
    section = "Kick", tab = "Kick",
    default = "Resonance kicked you",
    tooltip = "Message for the target",
    onChanged = function(txt, S) S.KickMessage = txt end
}
end

-- === core/settings/option_37_kick_reason.lua ===
__FACTORIES["core/settings/option_37_kick_reason.lua"] = function()
return {
    id = "KickReason", type = "input", name = "Kick Reason",
    section = "Kick", tab = "Kick",
    default = "You have been removed",
    tooltip = "Kick reason",
    onChanged = function(txt, S) S.KickReason = txt end
}
end

-- === core/settings/option_38_kick_delay.lua ===
__FACTORIES["core/settings/option_38_kick_delay.lua"] = function()
return {
    id = "KickDelay", type = "slider", name = "Kick Delay",
    section = "Kick", tab = "Kick",
    default = 0, range = {0, 5000}, increment = 100, suffix = " ms",
    tooltip = "Delay before kicking",
    onChanged = function(v, S) S.KickDelay = v end
}
end

-- === core/settings/option_39_kick_repeat.lua ===
__FACTORIES["core/settings/option_39_kick_repeat.lua"] = function()
return {
    id = "KickRepeat", type = "toggle", name = "Repeat Kick",
    section = "Kick", tab = "Kick",
    default = false,
    tooltip = "Repeat kicks in a loop",
    onChanged = function(v, S) S.KickRepeat = v end
}
end

-- === core/settings/option_40_kick_target_only.lua ===
__FACTORIES["core/settings/option_40_kick_target_only.lua"] = function()
return {
    id = "KickTargetOnly", type = "toggle", name = "Kick Selected Target Only",
    section = "Kick", tab = "Kick",
    default = false,
    tooltip = "Apply kicks only to the selected target",
    onChanged = function(v, S) S.KickTargetOnly = v end
}
end

local function getMod(path)
    if __RESONANCE[path] ~= nil then return __RESONANCE[path] end
    local factory = assert(__FACTORIES[path], "Missing bundled module: " .. path)
    local result = factory()
    __RESONANCE[path] = result
    return result
end
_G.ResonanceBundledModules = __RESONANCE
_G.ResonanceUtils = getMod("core/utils.lua")
_G.ResonanceLoop = getMod("core/loop.lua")
_G.ResonanceKeybind = getMod("core/keybind.lua")
_G.ResonanceConfig = getMod("core/config.lua")
_G.ResonanceRGB = getMod("core/rgb.lua")
_G.ResonanceManifest = getMod("core/manifest.lua")
_G.ResonanceResolver = getMod("core/remote_resolver.lua")
getMod("core/settings/option_01_reach_distance.lua")
getMod("core/settings/option_02_throw_power_multiplier.lua")
getMod("core/settings/option_03_fling_power.lua")
getMod("core/settings/option_04_spin_rpm.lua")
getMod("core/settings/option_05_spin_radius.lua")
getMod("core/settings/option_06_aura_radius.lua")
getMod("core/settings/option_07_loop_delay.lua")
getMod("core/settings/option_08_walk_speed.lua")
getMod("core/settings/option_09_jump_power.lua")
getMod("core/settings/option_10_fly_speed.lua")
getMod("core/settings/option_11_gravity.lua")
getMod("core/settings/option_12_aura_type.lua")
getMod("core/settings/option_13_punishment_type.lua")
getMod("core/settings/option_14_line_material.lua")
getMod("core/settings/option_15_target_lock_method.lua")
getMod("core/settings/option_16_whitelist_friends.lua")
getMod("core/settings/option_17_whitelist_plots.lua")
getMod("core/settings/option_18_auto_leave_staff.lua")
getMod("core/settings/option_19_rgb_mode.lua")
getMod("core/settings/option_20_esp_boxes.lua")
getMod("core/settings/option_21_esp_tracers.lua")
getMod("core/settings/option_22_esp_info.lua")
getMod("core/settings/option_23_esp_team_check.lua")
getMod("core/settings/option_24_fullbright.lua")
getMod("core/settings/option_25_anti_grab.lua")
getMod("core/settings/option_26_anti_fling.lua")
getMod("core/settings/option_27_anti_void.lua")
getMod("core/settings/option_28_auto_rejoin.lua")
getMod("core/settings/option_29_notifications.lua")
getMod("core/settings/option_30_keybind.lua")
getMod("core/settings/option_31_animation_pack.lua")
getMod("core/settings/option_32_animation_speed.lua")
getMod("core/settings/option_33_animation_loop.lua")
getMod("core/settings/option_34_animation_priority.lua")
getMod("core/settings/option_35_animation_blend.lua")
getMod("core/settings/option_36_kick_message.lua")
getMod("core/settings/option_37_kick_reason.lua")
getMod("core/settings/option_38_kick_delay.lua")
getMod("core/settings/option_39_kick_repeat.lua")
getMod("core/settings/option_40_kick_target_only.lua")
_G.ResonanceSettings = getMod("core/settings/init.lua")
local Registry = {}
local failures = {}
Registry.Combat = {}
Registry.Auras = {}
Registry.Protection = {}
Registry.Targeting = {}
Registry.Movement = {}
Registry.Visuals = {}
Registry.Server = {}
Registry.Utility = {}
Registry.Trolling = {}
Registry.Animations = {}
Registry.Kick = {}
local modulePaths = {
    "modules/combat/func_001_super_throw.lua",
    "modules/combat/func_002_massless_grab.lua",
    "modules/combat/func_003_freeze_grab.lua",
    "modules/combat/func_004_silent_aim.lua",
    "modules/combat/func_005_aimbot.lua",
    "modules/combat/func_006_telekinesis.lua",
    "modules/combat/func_007_auto_throw.lua",
    "modules/combat/func_008_kill_aura.lua",
    "modules/combat/func_009_hitbox_expander.lua",
    "modules/combat/func_010_wall_bang.lua",
    "modules/combat/func_011_rapid_fire.lua",
    "modules/combat/func_012_no_recoil.lua",
    "modules/combat/func_013_fling_all.lua",
    "modules/combat/func_014_fling_random.lua",
    "modules/combat/func_015_fling_closest.lua",
    "modules/combat/func_016_kill_all.lua",
    "modules/combat/func_017_kill_closest.lua",
    "modules/combat/func_018_kill_random.lua",
    "modules/combat/func_019_burn_all.lua",
    "modules/combat/func_020_burn_closest.lua",
    "modules/combat/func_021_freeze_all.lua",
    "modules/combat/func_022_unfreeze_all.lua",
    "modules/combat/func_023_ragdoll_all.lua",
    "modules/combat/func_024_explode_all.lua",
    "modules/combat/func_025_void_all.lua",
    "modules/combat/func_026_sky_all.lua",
    "modules/combat/func_027_shake_all.lua",
    "modules/combat/func_028_spin_all.lua",
    "modules/combat/func_029_slow_all.lua",
    "modules/combat/func_030_speed_all.lua",
    "modules/combat/func_031_jump_all.lua",
    "modules/combat/func_032_reset_all.lua",
    "modules/combat/func_033_anchor_all.lua",
    "modules/combat/func_034_unanchor_all.lua",
    "modules/combat/func_035_shirt_off_all.lua",
    "modules/combat/func_036_pants_off_all.lua",
    "modules/combat/func_037_hats_off_all.lua",
    "modules/combat/func_038_drop_tools_all.lua",
    "modules/combat/func_039_forcefield_off_all.lua",
    "modules/combat/func_040_character_reset.lua",
    "modules/auras/func_041_fling_aura.lua",
    "modules/auras/func_042_kill_aura.lua",
    "modules/auras/func_043_freeze_aura.lua",
    "modules/auras/func_044_fire_aura.lua",
    "modules/auras/func_045_void_aura.lua",
    "modules/auras/func_046_attraction_aura.lua",
    "modules/auras/func_047_auto_counter.lua",
    "modules/auras/func_048_plot_kicker.lua",
    "modules/auras/func_049_gravity_aura.lua",
    "modules/auras/func_050_spin_aura.lua",
    "modules/auras/func_051_damage_aura.lua",
    "modules/auras/func_052_slow_aura.lua",
    "modules/auras/func_053_ragdoll_aura.lua",
    "modules/auras/func_054_teleport_aura.lua",
    "modules/auras/func_055_blind_aura.lua",
    "modules/auras/func_056_kick_aura.lua",
    "modules/auras/func_057_confuse_aura.lua",
    "modules/auras/func_058_mute_aura.lua",
    "modules/auras/func_059_shrink_aura.lua",
    "modules/auras/func_060_grow_aura.lua",
    "modules/protection/func_061_anti_grab.lua",
    "modules/protection/func_062_anti_fling.lua",
    "modules/protection/func_063_anti_freeze.lua",
    "modules/protection/func_064_anti_ragdoll.lua",
    "modules/protection/func_065_anti_void.lua",
    "modules/protection/func_066_anti_vote_kick.lua",
    "modules/protection/func_067_anti_kick.lua",
    "modules/protection/func_068_anti_teleport.lua",
    "modules/protection/func_069_anti_sit.lua",
    "modules/protection/func_070_anti_burn.lua",
    "modules/protection/func_071_anti_explosion.lua",
    "modules/protection/func_072_anti_damage.lua",
    "modules/protection/func_073_anti_slow.lua",
    "modules/protection/func_074_anti_fire_touch.lua",
    "modules/protection/func_075_anti_gravity.lua",
    "modules/protection/func_076_anti_shrink.lua",
    "modules/protection/func_077_noclip.lua",
    "modules/protection/func_078_infinite_yield.lua",
    "modules/protection/func_079_god_mode.lua",
    "modules/protection/func_080_rejoin_on_damage.lua",
    "modules/targeting/func_081_loop_kill.lua",
    "modules/targeting/func_082_loop_burn.lua",
    "modules/targeting/func_083_loop_fling.lua",
    "modules/targeting/func_084_loop_freeze.lua",
    "modules/targeting/func_085_loop_void.lua",
    "modules/targeting/func_086_follow_target.lua",
    "modules/targeting/func_087_view_target.lua",
    "modules/targeting/func_088_tp_to_target.lua",
    "modules/targeting/func_089_tp_target_to_me.lua",
    "modules/targeting/func_090_kill_target.lua",
    "modules/targeting/func_091_fling_target.lua",
    "modules/targeting/func_092_freeze_target.lua",
    "modules/targeting/func_093_void_target.lua",
    "modules/targeting/func_094_sky_target.lua",
    "modules/targeting/func_095_spin_target.lua",
    "modules/targeting/func_096_orbit_target.lua",
    "modules/targeting/func_097_ragdoll_target.lua",
    "modules/targeting/func_098_blind_target.lua",
    "modules/targeting/func_099_steal_target_tools.lua",
    "modules/targeting/func_100_copy_target_skin.lua",
    "modules/movement/func_101_infinite_jump.lua",
    "modules/movement/func_102_noclip.lua",
    "modules/movement/func_103_fly.lua",
    "modules/movement/func_104_speed_boost.lua",
    "modules/movement/func_105_high_jump.lua",
    "modules/movement/func_106_low_gravity.lua",
    "modules/movement/func_107_zero_gravity.lua",
    "modules/movement/func_108_auto_jump.lua",
    "modules/movement/func_109_bunny_hop.lua",
    "modules/movement/func_110_slide.lua",
    "modules/movement/func_111_wall_run.lua",
    "modules/movement/func_112_crouch.lua",
    "modules/movement/func_113_sprint.lua",
    "modules/movement/func_114_tp_spawn.lua",
    "modules/movement/func_115_tp_random_player.lua",
    "modules/movement/func_116_tp_forward.lua",
    "modules/movement/func_117_tp_up.lua",
    "modules/movement/func_118_tp_down.lua",
    "modules/movement/func_119_tp_cursor.lua",
    "modules/movement/func_120_reset_speed.lua",
    "modules/visuals/func_121_esp_boxes.lua",
    "modules/visuals/func_122_esp_tracers.lua",
    "modules/visuals/func_123_player_info.lua",
    "modules/visuals/func_124_name_tags.lua",
    "modules/visuals/func_125_health_bars.lua",
    "modules/visuals/func_126_distance_display.lua",
    "modules/visuals/func_127_skeleton_esp.lua",
    "modules/visuals/func_128_chams.lua",
    "modules/visuals/func_129_xray.lua",
    "modules/visuals/func_130_fullbright.lua",
    "modules/visuals/func_131_no_fog.lua",
    "modules/visuals/func_132_remove_textures.lua",
    "modules/visuals/func_133_blue_sky.lua",
    "modules/visuals/func_134_red_ambient.lua",
    "modules/visuals/func_135_green_ambient.lua",
    "modules/visuals/func_136_rainbow_light.lua",
    "modules/visuals/func_137_remove_baseplate.lua",
    "modules/visuals/func_138_remove_lights.lua",
    "modules/visuals/func_139_restore_lighting.lua",
    "modules/visuals/func_140_disable_shadows.lua",
    "modules/server/func_141_rejoin.lua",
    "modules/server/func_142_server_hop.lua",
    "modules/server/func_143_join_smallest.lua",
    "modules/server/func_144_join_largest.lua",
    "modules/server/func_145_copy_jobid.lua",
    "modules/server/func_146_copy_placeid.lua",
    "modules/server/func_147_copy_server_link.lua",
    "modules/server/func_148_show_server_info.lua",
    "modules/server/func_149_list_players.lua",
    "modules/server/func_150_hop_until_empty.lua",
    "modules/server/func_151_anti_afk.lua",
    "modules/server/func_152_auto_rejoin_kick.lua",
    "modules/server/func_153_rejoin_delay.lua",
    "modules/server/func_154_ping_display.lua",
    "modules/server/func_155_fps_display.lua",
    "modules/server/func_156_leave_game.lua",
    "modules/server/func_157_reset_character.lua",
    "modules/server/func_158_character_respawn.lua",
    "modules/server/func_159_unlock_fps.lua",
    "modules/server/func_160_show_fps.lua",
    "modules/utility/func_161_anti_afk.lua",
    "modules/utility/func_162_auto_claim_cash.lua",
    "modules/utility/func_163_cash_magnet.lua",
    "modules/utility/func_164_item_magnet.lua",
    "modules/utility/func_165_bring_all_items.lua",
    "modules/utility/func_166_bring_all_players.lua",
    "modules/utility/func_167_clear_workspace.lua",
    "modules/utility/func_168_delete_grabbed.lua",
    "modules/utility/func_169_unlock_mouse.lua",
    "modules/utility/func_170_full_screen.lua",
    "modules/utility/func_171_copy_position.lua",
    "modules/utility/func_172_copy_rotation.lua",
    "modules/utility/func_173_show_position.lua",
    "modules/utility/func_174_print_character.lua",
    "modules/utility/func_175_clear_notifications.lua",
    "modules/utility/func_176_toggle_ui.lua",
    "modules/utility/func_177_re_execute.lua",
    "modules/utility/func_178_reload_config.lua",
    "modules/utility/func_179_save_config.lua",
    "modules/utility/func_180_wipe_cache.lua",
    "modules/trolling/func_181_music_play.lua",
    "modules/trolling/func_182_reverse_controls.lua",
    "modules/trolling/func_183_fling_random_aura.lua",
    "modules/trolling/func_184_rainbow_all.lua",
    "modules/trolling/func_185_neon_all.lua",
    "modules/trolling/func_186_shrink_all.lua",
    "modules/trolling/func_187_grow_all.lua",
    "modules/trolling/func_188_head_spin_all.lua",
    "modules/trolling/func_189_random_color_self.lua",
    "modules/trolling/func_190_rainbow_self.lua",
    "modules/trolling/func_191_neon_self.lua",
    "modules/trolling/func_192_ghost_self.lua",
    "modules/trolling/func_193_invisible_self.lua",
    "modules/trolling/func_194_visible_self.lua",
    "modules/trolling/func_195_shake_screen_all.lua",
    "modules/trolling/func_196_fake_death_all.lua",
    "modules/trolling/func_197_fire_trail.lua",
    "modules/trolling/func_198_ice_trail.lua",
    "modules/trolling/func_199_lightning_self.lua",
    "modules/trolling/func_200_dance_all.lua",
    "modules/animations/func_201_play_dance.lua",
    "modules/animations/func_202_play_wave.lua",
    "modules/animations/func_203_play_point.lua",
    "modules/animations/func_204_play_laugh.lua",
    "modules/animations/func_205_play_cheer.lua",
    "modules/animations/func_206_play_floss.lua",
    "modules/animations/func_207_play_dab.lua",
    "modules/animations/func_208_play_russian.lua",
    "modules/animations/func_209_play_karate.lua",
    "modules/animations/func_210_play_salsa.lua",
    "modules/animations/func_211_play_hiphop.lua",
    "modules/animations/func_212_play_breakdance.lua",
    "modules/animations/func_213_play_robot.lua",
    "modules/animations/func_214_play_backflip.lua",
    "modules/animations/func_215_play_frontflip.lua",
    "modules/animations/func_216_play_sit.lua",
    "modules/animations/func_217_play_lay.lua",
    "modules/animations/func_218_play_crawl.lua",
    "modules/animations/func_219_play_sprint_anim.lua",
    "modules/animations/func_220_play_swim.lua",
    "modules/animations/func_221_play_climb.lua",
    "modules/animations/func_222_stop_all_anims.lua",
    "modules/animations/func_223_free_anims_off.lua",
    "modules/animations/func_224_anim_speed_up.lua",
    "modules/animations/func_225_anim_slow_down.lua",
    "modules/kick/func_226_kick_all.lua",
    "modules/kick/func_227_kick_closest.lua",
    "modules/kick/func_228_kick_random.lua",
    "modules/kick/func_229_kick_by_name.lua",
    "modules/kick/func_230_kick_farthest.lua",
    "modules/kick/func_231_kick_lowest_hp.lua",
    "modules/kick/func_232_kick_highest_hp.lua",
    "modules/kick/func_233_kick_friend.lua",
    "modules/kick/func_234_kick_non_friend.lua",
    "modules/kick/func_235_kick_team.lua",
    "modules/kick/func_236_kick_enemy_team.lua",
    "modules/kick/func_237_kick_afk.lua",
    "modules/kick/func_238_kick_talking.lua",
    "modules/kick/func_239_kick_silent.lua",
    "modules/kick/func_240_kick_walking.lua",
    "modules/kick/func_241_kick_standing.lua",
    "modules/kick/func_242_kick_jumping.lua",
    "modules/kick/func_243_kick_flying.lua",
    "modules/kick/func_244_kick_glitched.lua",
    "modules/kick/func_245_kick_invisible.lua",
    "modules/kick/func_246_kick_visible.lua",
    "modules/kick/func_247_kick_high_ping.lua",
    "modules/kick/func_248_kick_low_ping.lua",
    "modules/kick/func_249_kick_mobile.lua",
    "modules/kick/func_250_kick_pc.lua",
    "modules/kick/func_251_kick_console.lua",
    "modules/kick/func_252_kick_vr.lua",
    "modules/kick/func_253_kick_guest.lua",
    "modules/kick/func_254_kick_premium.lua",
    "modules/kick/func_255_kick_non_premium.lua",
    "modules/kick/func_256_kick_verified.lua",
    "modules/kick/func_257_kick_non_verified.lua",
    "modules/kick/func_258_kick_with_hats.lua",
    "modules/kick/func_259_kick_without_hats.lua",
    "modules/kick/func_260_kick_with_tools.lua",
    "modules/kick/func_261_kick_without_tools.lua",
    "modules/kick/func_262_kick_rich.lua",
    "modules/kick/func_263_kick_poor.lua",
    "modules/kick/func_264_kick_high_level.lua",
    "modules/kick/func_265_kick_low_level.lua",
    "modules/kick/func_266_kick_owner.lua",
    "modules/kick/func_267_kick_admin.lua",
    "modules/kick/func_268_kick_moderator.lua",
    "modules/kick/func_269_kick_staff.lua",
    "modules/kick/func_270_kick_bots.lua",
    "modules/kick/func_271_kick_alts.lua",
    "modules/kick/func_272_kick_by_userid.lua",
    "modules/kick/func_273_kick_by_display_name.lua",
    "modules/kick/func_274_kick_multiple.lua",
    "modules/kick/func_275_kick_blacklist.lua",
}

for _, path in ipairs(modulePaths) do
    local ok, mod = pcall(getMod, path)
    if ok and type(mod) == "table" then
        local cat = path:match("^modules/([^/]+)/")
        local key = cat:sub(1,1):upper() .. cat:sub(2)
        table.insert(Registry[key], mod)
    else
        table.insert(failures, path)
        warn("[Resonance] Module failed to load: " .. path .. " | " .. tostring(mod))
    end
end
_G.ResonanceRegistry = Registry
getMod("ui/theme.lua")
getMod("ui/notifications.lua")
local uiOk, uiError = pcall(getMod, "ui/build.lua")
if not uiOk then warn("[Resonance] UI initialization failed: " .. tostring(uiError)) end
local runtimeOk, runtimeError = pcall(getMod, "runtime.lua")
if not runtimeOk then warn("[Resonance] Runtime initialization failed: " .. tostring(runtimeError)) end
print("[Resonance] English bundle loaded | Module failures: " .. #failures)
