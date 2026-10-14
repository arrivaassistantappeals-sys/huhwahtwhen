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