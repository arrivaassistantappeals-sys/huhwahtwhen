
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

remotes.SetNetworkOwner="Owner";remotes.CreateGrabLine="Grab";remotes.DestroyGrabLine="Drop"
Hub.requestSave=function() end
local workspace=Workspace
local Toggles=controls
local GrabOptions,TargetGroup,PlayerView=group,group,group
Tabs.Grab={AddRightGroupbox=function() return group end}
Color3.fromHSV=function(...) return {...} end
Tabs.Misc={AddLeftGroupbox=function() return group end,AddRightGroupbox=function() return group end}
Tabs.Visual=Tabs.Misc
Tabs.Sound=Tabs.Misc
Tabs.Player=Tabs.Misc
Color3.new=function(...) return {...} end
Enum.CameraMode={LockFirstPerson="FirstPerson"}
Enum.Material={Neon="Neon"}
Workspace.Gravity=196.2
local lighting={Brightness=1,Ambient="ambient",OutdoorAmbient="outdoor",ClockTime=12}
local game={GetService=function(_,name) assert(name=="Lighting");return lighting end}
os.date=function() return {hour=6,min=30,sec=0} end
Player.CameraMode="Classic"
local ownFolder={Name=Player.Name.."SpawnedInToys",Parent=Workspace}
local named={ [ownFolder.Name]=ownFolder }
Workspace.FindFirstChild=function(_,name) return named[name] end
local scan={}
Hub.scanDescendants=function(_,callback,valid)
    for _,object in ipairs(scan) do if valid() then callback(object) end end
end
Hub.canAffect=function() return true end
Hub.targetLoopRuns={}
function group:AddInput(id,info)
    local control={Value=info.Default}
    function control:SetValue(value) self.Value=value;info.Callback(value) end
    controls[id]=control;control:SetValue(control.Value);return control
end
function group:AddDropdown(id,info)
    local control={Value=info.Values[info.Default]}
    function control:SetValue(value) self.Value=value;info.Callback(value) end
    controls[id]=control;control:SetValue(control.Value);return control
end
local function node(name,children,class)
    local object={Name=name,children=children or {},Parent=Workspace}
    object.IsA=function(_,kind) return kind==(class or "Folder") end
    object.FindFirstChild=function(self,key) for _,child in ipairs(self.children) do if child.Name==key then return child end end end
    object.GetChildren=function(self) return self.children end
    for _,child in ipairs(object.children) do child.Parent=object end
    return object
end
local function sound(name,parent,volume)
    local object=node(name,nil,"Sound");object.Parent=parent;object.Volume=volume;object.signal={}
    object.GetPropertyChangedSignal=function(self) return self.signal end
    return object
end

local PlayerView,PlayerESP=group,group
Tabs.Player=Tabs.Misc;Tabs.Fun=Tabs.Misc;Tabs.Target=Tabs.Misc;Tabs.Defense=Tabs.Misc;Tabs.AntiLag=Tabs.Misc
Hub.keybindDefinitions={};Hub.keybindGroups={actions=group}
RunService.RenderStepped={}
Enum.Font={Gotham="Gotham",GothamBold="GothamBold"}
Enum.FontWeight={Bold="Bold",Regular="Regular"};Enum.FontStyle={Normal="Normal"}
Enum.HighlightDepthMode={AlwaysOnTop="Top",Occluded="Occluded"}
Enum.EasingStyle={Linear="Linear"}
Enum.HumanoidStateType.Swimming="Swimming"
Enum.KeyCode={W="W",S="S",A="A",D="D",E="E",Q="Q"}
Enum.UserInputType={MouseButton1="MouseButton1",MouseButton2="MouseButton2"}
local UDim2={fromOffset=function(x,y) return {X=x,Y=y} end,fromScale=function(x,y) return {X=x,Y=y} end,new=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local Font={new=function(family,weight,style) return {family=family,weight=weight,style=style} end}
local TweenInfo={new=function(seconds) return {seconds=seconds} end}
local NumberRange={new=function(...) return {...} end}
local ColorSequenceKeypoint={new=function(time,color) return {Time=time,Value=color} end}
local vector2meta={}
local Vector2={new=function(x,y) return setmetatable({X=x,Y=y},vector2meta) end}
vector2meta.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
vector2meta.__index=function(v,key) if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y) end end
vecMeta.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
local oldIndex=vecMeta.__index
vecMeta.__index=function(v,key)
    if key=="Unit" then local m=v.Magnitude;return Vector3.new(v.X/m,v.Y/m,v.Z/m) end
    return oldIndex(v,key)
end
local originalNode=node
node=function(name,children,class)
    local object=originalNode(name,children,class)
    object.kind=class or "Folder"
    object.FindFirstChildOfClass=function(self,kind) for _,child in ipairs(self.children) do if child.kind==kind then return child end end end
    object.GetDescendants=function(self)
        local result={}
        local function visit(parent) for _,child in ipairs(parent.children or {}) do table.insert(result,child);visit(child) end end
        visit(self);return result
    end
    object.IsDescendantOf=function(self,ancestor)
        local parent=self.Parent;while parent do if parent==ancestor then return true end;parent=parent.Parent end;return false
    end
    object.GetFullName=function(self) return "Workspace."..self.Name end
    object.GetConnectedParts=function() return {} end
    if class=="BasePart" then
        object.Position=Vector3.zero;object.CFrame={Position=object.Position}
        object.CanCollide=true;object.CanTouch=true;object.CanQuery=true;object.LocalTransparencyModifier=0
        object.Anchored=false;object.AssemblyMass=10
    end
    return object
end
local playerGui=node("PlayerGui")
Player.FindFirstChildOfClass=function(_,name) if name=="PlayerGui" then return playerGui end end
Players.MaxPlayers=30
for _,person in ipairs(Players.roster) do person.DisplayName="Display "..person.Name end
local keyValues,typing,mouseHeld={},false,false
local mousePosition=Vector2.new(0,0)
local mouseTarget
Player.GetMouse=function() return {Target=mouseTarget} end
local UserInputService={InputBegan={},GetFocusedTextBox=function() return typing and {} or nil end,
 IsKeyDown=function(_,key) return keyValues[key]==true end,GetMouseLocation=function() return mousePosition end,
 IsMouseButtonPressed=function() return mouseHeld end}
local oldLabel=group.AddLabel
function group:AddLabel(text)
    local label=oldLabel(self,text)
    function label:AddKeyPicker(id,info)
        local control={Value=info.Default,Trigger=info.Callback};controls[id]=control;return control
    end
    return label
end
hum.AutoRotate=true
local humanoidStates={Swimming=true}
hum.GetStateEnabled=function(_,state) return humanoidStates[state]~=false end
hum.SetStateEnabled=function(_,state,value) humanoidStates[state]=value end
hum.GetState=function(self) return self.state or "Running" end
local oldChangeState=hum.ChangeState
hum.ChangeState=function(self,state) self.state=state;oldChangeState(self,state) end
root.IsDescendantOf=function(self,parent) return self.Parent==parent end
root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
local cameraCF={Position=Vector3.zero,LookVector=Vector3.new(0,0,-1),RightVector=Vector3.new(1,0,0),UpVector=Vector3.new(0,1,0)}
cameraCF.Lerp=function(_,destination,alpha) destination.alpha=alpha;return destination end
Workspace.CurrentCamera={CFrame=cameraCF,WorldToViewportPoint=function(_,position) return Vector3.new(position.X,position.Y,1),true end}
Hub.safeLookAt=function(position,target) return {Position=position,LookVector=(target-position).Unit} end
Hub.loopTargetReady=function(player,char)
    if not player or player==Player or player.protected or player.Parent~=Players or not char or player.Character~=char then return false end
    local h=char:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0 and not (player.inPlot and player.inPlot.Value)
end
local chosenPlayers={}
Hub.isSelectedTarget=function(player) return chosenPlayers[player.UserId]==true end
Hub.canAffect=function() return true end
local stoppedBlob=0
Hub.stopBlobFlight=function() stoppedBlob+=1;Hub.blobFlightActive=false end
local cameraService={ErrorMessageChanged={},GetGuiInset=function() return Vector2.new(0,0) end}
local teleports={}
local teleportService={TeleportInitFailed={},Teleport=function(_,place,player) table.insert(teleports,{place=place,player=player}) end,
 TeleportToPlaceInstance=function(_,place,job,player) table.insert(teleports,{place=place,job=job,player=player}) end}
local tweenCalls={}
local tweenService={Create=function(_,target,info,goal)
    local tween={Completed={},target=target,info=info,goal=goal,Play=function(self) self.played=true end,Cancel=function(self) self.cancelled=true end}
    table.insert(tweenCalls,tween);return tween
end}
local pages,httpCalls={},{}
local pauseHTTP=false
local httpService={UrlEncode=function(_,text) return text end,JSONDecode=function(_,body) return pages[tonumber(body)] end}
local lighting=node("Lighting")
local game={PlaceId=6961824067,JobId="current-job",DescendantAdded={},GetService=function(_,name)
    if name=="Lighting" then return lighting elseif name=="GuiService" then return cameraService
    elseif name=="TeleportService" then return teleportService elseif name=="HttpService" then return httpService
    elseif name=="TweenService" then return tweenService end
    error("Unknown service: "..name)
end,HttpGet=function(_,url) table.insert(httpCalls,url);if pauseHTTP then coroutine.yield() end;return tostring(#httpCalls) end}
local copied
local setclipboard=function(value) copied=value end
remotes.UpdateLineColorsEvent="LineColor"
local function resume(index) local ok,err=coroutine.resume(workers[index]);assert(ok,err) end
local function lastCreated(class,parent)
    for index=#created,1,-1 do local object=created[index];if object.ClassName==class and (not parent or object.Parent==parent) then return object end end
end

