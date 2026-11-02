-- Minimal character, signal, clock and remote mocks for self-protection.

local now = 0
local os = {clock = function() return now end}
local Workspace = {}
local Hub = {alive = true, canHarm = function(player) return not player.protected end}
local Players = {roster = {}}
function Players:GetPlayers() return self.roster end
function Players:FindFirstChild(name)
    for _, player in ipairs(self.roster) do
        if player.Name == name then return player end
    end
end
local function makePlayer(id, name)
    local hum = {Health = 100}
    local root = {}
    return {UserId = id, Name = name, Parent = Players,
        FindFirstChild = function(self, key) return key == "InPlot" and self.inPlot or nil end,
        Character = {
        IsDescendantOf = function(self, root) return root == Workspace and not self.removed end,
        FindFirstChildOfClass = function() return hum end,
        FindFirstChild = function(_, name) return name == "Humanoid" and hum or root end,
    }}
end
local Player = makePlayer(1, "Self")
local a, b, c = makePlayer(10, "A"), makePlayer(20, "B"), makePlayer(30, "C")
Players.roster = {Player, a, b, c}

local Vector3 = {}
local vecMeta = {}
function Vector3.new(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vecMeta) end
Vector3.zero = Vector3.new(0, 0, 0)
vecMeta.__sub = function(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
vecMeta.__mul = function(a, b) return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
vecMeta.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
end
local CFrame = {new = function(v) return {Position=v} end}
local Color3 = {fromRGB = function(...) return {...} end}
local ColorSequence = {new = function(v) return v end}
local NumberSequence = {new = function(v) return v end}
local Enum = {HumanoidStateType={Dead="Dead"}}
local function position(player, x, y, z)
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    root.Position = Vector3.new(x, y or 0, z or 0)
    root.Size = Vector3.new(2, 2, 1)
    root.Parent = player.Character
    player.Character.HumanoidRootPart = root
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    hum.HipHeight = 2
    hum.ChangeState = function() end
end
for _, player in ipairs(Players.roster) do position(player, player.UserId) end
position(Player, 0)
Player.protected = true
Player.CharacterRemoving = {}
Players.PlayerRemoving = {}
local created, notices, workers, connections, cleanups = {}, {}, {}, {}, {}
Hub.instances, Hub.assetTargets, Hub.connections = {}, {}, {}
Hub.new = function(class, parent)
    local object = {ClassName=class, Parent=parent, Destroy=function(self) self.destroyed=true;self.Parent=nil end}
    table.insert(created, object)
    Hub.instances[object] = true
    if parent then Hub.assetTargets[object] = parent end
    return object
end
Hub.connect = function(signal, callback)
    local connection = {signal=signal, callback=callback, Disconnect=function(self) self.disconnected=true end}
    table.insert(connections, connection)
    Hub.connections[connection]=true
    return connection
end
Hub.cleanup = function(callback) table.insert(cleanups, callback) end
local function emit(signal, ...)
    local snapshot = table.clone(connections)
    for _, c in ipairs(snapshot) do if c.signal==signal and not c.disconnected then c.callback(...) end end
end
local task = {wait=function() coroutine.yield() end,
    spawn=function(callback) table.insert(workers, coroutine.create(callback)) end}
local controls, buttons, labels = {}, {}, {}
local group = {}
function group:AddToggle(id, info)
    local control = {Value=info.Default}
    function control:SetValue(value) self.Value=value;info.Callback(value) end
    controls[id] = control
    control:SetValue(info.Default)
    return control
end
function group:AddSlider(id, info)
    local control = {Value=info.Default}
    function control:SetValue(value) self.Value=value;info.Callback(value) end
    controls[id] = control
    control:SetValue(info.Default)
    return control
end
function group:AddButton(info) buttons[info.Text]=info.Func end
function group:AddLabel(text)
    local label = {text=text, SetText=function(self, value) self.text=value end}
    table.insert(labels, label)
    return label
end
local Toggles = controls
local Tabs = {Aura={AddLeftGroupbox=function() return group end, AddRightGroupbox=function() return group end}}
local Library = {Notify=function(_, info) table.insert(notices, info) end}
local RunService = {Heartbeat={}}
local fireCount, skyCount = 0, 0
Hub.fire = function() fireCount+=1 end
Hub.canAffect = function() return true end
local destroyGrabLineEvent = {}
local CreateSkyVelocity = function() skyCount+=1 end
local SNOWshipPlayer = function(_, effect) effect();return true end
local lookAt = function() return {LookVector=Vector3.new(1,0,0)} end
local Debris = {AddItem=function() end}

local DefenseGroup = group
local notify = function(title, message) table.insert(notices, {Title=title, Description=message}) end
function group:AddButton(info, callback)
    if type(info)=="string" then buttons[info]=callback else buttons[info.Text]=info.Func end
end
Player.CharacterAdded, Player.ChildAdded, Player.ChildRemoved = {}, {}, {}
local char=Player.Character
char.Parent=Workspace
char.DescendantAdded={}
local root=char.HumanoidRootPart
root.Name="HumanoidRootPart"
root.Anchored=false
root.AssemblyLinearVelocity=Vector3.zero
root.AssemblyAngularVelocity=Vector3.zero
root.CFrame=CFrame.new(root.Position)
root.IsA=function(_, class) return class=="BasePart" end
local head={Name="Head", Parent=char, Anchored=false, IsA=root.IsA}
local torso={Name="Torso", Parent=char, Anchored=true, IsA=root.IsA}
local hum=char:FindFirstChildOfClass("Humanoid")
hum.Name="Humanoid"
hum.Parent=char
hum.PlatformStand=false
hum.IsA=function(_, class) return class=="Humanoid" end
hum.FindFirstChild=function(self, name) return name=="Ragdolled" and self.ragdolled or nil end
hum.ChangeState=function(self, state) self.lastState=state end
Enum.HumanoidStateType.GettingUp="GettingUp"
char.FindFirstChild=function(_, name)
    if name=="HumanoidRootPart" then return root end
    if name=="Humanoid" then return hum end
    if name=="Head" then return head end
end
char.GetChildren=function() return {root,head,torso,hum} end
char.GetDescendants=function() return head.owner and {root,head,torso,hum,head.owner} or {root,head,torso,hum} end
local function heldFlag(value)
    return {Name="IsHeld", Value=value, valueSignal={},
        IsA=function(_, kind) return kind=="BoolValue" end,
        GetPropertyChangedSignal=function(self) return self.valueSignal end}
end
Player.held=heldFlag(false)
Player.FindFirstChild=function(self,name) if name=="IsHeld" then return self.held end end
local requests={}
Hub.fire=function(...) table.insert(requests,{...}) end
local remotes={Struggle="Struggle", RagdollRemote="RagdollRemote", StopAllVelocity="StopAllVelocity"}
local folder={FindFirstChild=function(_, name) return remotes[name] end}
local ReplicatedStorage={FindFirstChild=function() return folder end}
local delayed={}
task.delay=function(delay, callback) table.insert(delayed,{at=now+delay,callback=callback}) end
local function advance(to)
    now=to
    local pending=delayed;delayed={}
    for _, item in ipairs(pending) do
        if now>=item.at then item.callback() else table.insert(delayed,item) end
    end
end
local function setHeld(value)
    Player.held.Value=value
    emit(Player.held.valueSignal)
end
local ground={Parent=Workspace, Anchored=true, CanCollide=true, Position=Vector3.zero,
    IsA=function(_, kind) return kind=="BasePart" end,
    IsDescendantOf=function(_, parent) return parent==Workspace end}
ground.CFrame=CFrame.new(ground.Position)
local hit={Instance=ground, Normal=Vector3.new(0,1,0)}
Workspace.FallenPartsDestroyHeight=-500
Workspace.Raycast=function() return hit end
local RaycastParams={new=function() return {} end}
Enum.RaycastFilterType={Exclude="Exclude"}
Hub.playerOf=function(part) return part.owner end
