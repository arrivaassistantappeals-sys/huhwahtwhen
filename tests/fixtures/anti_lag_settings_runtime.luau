local function signal()
    local listeners={}
    return {
        Connect=function(_,callback)
            local c={Connected=true,callback=callback}
            function c:Disconnect() self.Connected=false end
            table.insert(listeners,c);return c
        end,
        Emit=function(_,...)
            for _,c in ipairs(table.clone(listeners)) do if c.Connected then c.callback(...) end end
        end,
    }
end
local function lineScript(name,disabled)
    local changed=signal()
    local properties={Name=name,Disabled=disabled}
    local object={Destroying=signal(),IsA=function(_,kind) return kind=="LocalScript" end,
        GetPropertyChangedSignal=function() return changed end}
    return setmetatable(object,{
        __index=function(_,key) if key=="Enabled" then return not properties.Disabled end;return properties[key] end,
        __newindex=function(_,key,value)
            if key=="Enabled" then key="Disabled";value=not value end
            local old=properties[key];properties[key]=value
            if key=="Disabled" and old~=value then changed:Emit() end
        end,
    })
end
local line=lineScript("CharacterAndBeamMove",false)
local sticky=lineScript("StickyPartsTouchDetection",false)
local scripts={children={line,sticky}}
line.Parent=scripts;sticky.Parent=scripts
function scripts:GetDescendants() return self.children end
function scripts:FindFirstChild(name) for _,script in ipairs(self.children) do if script.Name==name then return script end end end
local Player={Name="Self",DescendantAdded=signal(),CharacterAdded=signal()}
function Player:FindFirstChild(name) if name=="PlayerScripts" then return scripts end end
function Player:FindFirstChildOfClass(kind) if kind=="PlayerScripts" then return scripts end end
local Workspace={DescendantAdded=signal(),GetDescendants=function() return {} end,FindFirstChild=function() end}
local RunService={Heartbeat=signal()}
Hub.connections={}
Hub.cleanup=function() end
Hub.connect=function(event,callback) local c=event:Connect(callback);Hub.connections[c]=true;return c end
local notify=function() end
local DefenseGroup=group
local Tabs={AntiLag={AddLeftGroupbox=function() return group end}}
local Toggles=Library.Toggles
