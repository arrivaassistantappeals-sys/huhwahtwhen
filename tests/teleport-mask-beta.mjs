import fs from 'node:fs';import assert from 'node:assert/strict';import {LuauState} from 'luau-web';
const s=fs.readFileSync(process.env.TELEPORT_TEST_SOURCE || new URL('../dist/Arriva Core Hub 2.5Beta.lua', import.meta.url),'utf8');const module=s.slice(s.indexOf('-- BEGIN SHARED TELEPORT MASK'),s.indexOf('-- END SHARED TELEPORT MASK'));
const code=`
local function signal() local list={};return {Connect=function(_,fn) local c={active=true};c.Disconnect=function() c.active=false end;table.insert(list,{fn=fn,c=c});return c end,Fire=function(_,...) for _,v in ipairs(list) do if v.c.active then v.fn(...) end end end} end
local vm={};local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)},vm) end
vm.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end;vm.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
local cm={};local cf;cf=function(x,y,z) return setmetatable({Position=vec(x,y or 0,z or 0),ToObjectSpace=function(self,other) local d=other.Position-self.Position;return cf(d.X,d.Y,d.Z) end},cm) end
cm.__mul=function(a,b) local d=a.Position+b.Position;return cf(d.X,d.Y,d.Z) end
local writes=0
local function part(name,frame,parent,real)
 local p={Name=name,Parent=parent,Archivable=false,LocalTransparencyModifier=0,IsDescendantOf=function(self,model) return self.Parent==model end,IsA=function(_,kind) return kind=='BasePart' end}
 return setmetatable(p,{__index=function(_,key) if key=='CFrame' then return frame elseif key=='Position' then return frame.Position end end,__newindex=function(self,key,value) if key=='CFrame' then frame=value;if real then writes+=1 end else rawset(self,key,value) end end})
end
local char={Archivable=false,DescendantAdded=signal()};local root=part('HumanoidRootPart',cf(0),char,true);local head=part('Head',cf(0,2),char,true)
local hum={Parent=char,Health=100};char.FindFirstChild=function(_,name) if name=='HumanoidRootPart' then return root elseif name=='Head' then return head end end
char.FindFirstChildOfClass=function() return hum end;char.GetPivot=function() return root.CFrame end;char.GetDescendants=function() return {root,head} end
char.PivotTo=function(_,f) root.CFrame=f end
local clones={}
function char:Clone()
 local clone={Name='Copy',Parent=nil};local dr=part('HumanoidRootPart',root.CFrame,clone);local dh=part('Head',head.CFrame,clone)
 local displayHum={Parent=clone,IsA=function() return false end};clone.root=dr;clone.head=dh
 clone.FindFirstChild=function(_,name) return name=='HumanoidRootPart' and dr or dh end;clone.FindFirstChildOfClass=function() return displayHum end
 clone.GetPivot=function() return dr.CFrame end
 clone.GetDescendants=function() return {dr,dh,displayHum} end
 clone.PivotTo=function(_,frame) dr.CFrame=frame end;clone.Destroy=function() clone.Parent=nil;clone.destroyed=true end
 table.insert(clones,clone);return clone
end
local LocalPlayer={Character=char,CharacterRemoving=signal()};local Workspace={CurrentCamera={CameraSubject=hum}}
local bindings={};local RunService={Heartbeat=signal(),BindToRenderStep=function(_,name,priority,fn) bindings[name]=fn end,UnbindFromRenderStep=function(_,name) bindings[name]=nil end}
local Enum={RenderPriority={Camera={Value=200}},HumanoidDisplayDistanceType={None='None'}}
local Hub={instances={},connections={},connect=function(event,fn) return event:Connect(fn) end,cleanup=function() end}
local function render() for _,fn in pairs(bindings) do fn() end end
${module}
Hub.teleportPart(root,cf(100));assert(#clones==0,'no character clone')
assert(root.Position.X==0 and Hub.teleportFrame(root).Position.X==100,'destination does not overwrite visible frame')
RunService.Heartbeat:Fire();assert(root.Position.X==100,'Heartbeat applies action destination')
RunService.Heartbeat:Fire();RunService.Heartbeat:Fire();assert(root.Position.X==100,'multiple physics ticks hold destination')
render();assert(root.Position.X==0,'render restores original visible frame before camera')
assert(head.Position.Y==2 and head.LocalTransparencyModifier==0 and root.LocalTransparencyModifier==0,'head and visibility untouched')
assert(Workspace.CurrentCamera.CameraSubject==hum,'camera subject unchanged')
Hub.teleportPart(root,cf(200));assert(root.Position.X==0,'subsequent teleport cannot flash destination')
RunService.Heartbeat:Fire();assert(root.Position.X==200);RunService.Heartbeat:Fire();render();render();assert(root.Position.X==0,'repeated destinations stay hidden')
root.CFrame=cf(1);RunService.Heartbeat:Fire();render();assert(root.Position.X==1,'normal visible movement is sampled independently')
Hub.teleportPart(root,cf(0));assert(not Hub.teleportMaskState and next(bindings)==nil and root.Position.X==0,'return disconnects swap')
Hub.teleportPart(root,cf(300));RunService.Heartbeat:Fire();render();Hub.setTeleportMaskEnabled(false);assert(root.Position.X==300 and next(bindings)==nil,'disable reveals actual destination')
Hub.setTeleportMaskEnabled(true);Hub.teleportPart(root,cf(400));LocalPlayer.CharacterRemoving:Fire();assert(not Hub.teleportMaskState and next(bindings)==nil,'respawn cleanup')
return 'PASS: multi-Heartbeat/repeated-render local presentation, root-only independent visible/destination frames and Heartbeat/render swap, no clone/head/visibility/camera-subject changes, return/off/respawn cleanup'
`;
const state=await LuauState.createAsync();console.log(await state.loadstring(code,'reference camera',true)());state.destroy();
