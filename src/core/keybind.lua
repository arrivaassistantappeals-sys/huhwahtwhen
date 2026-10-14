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