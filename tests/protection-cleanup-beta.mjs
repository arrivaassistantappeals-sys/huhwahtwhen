import fs from 'node:fs';import {LuauState} from 'luau-web';
const source=fs.readFileSync(new URL('../dist/Arriva Core Hub 2.5Beta.lua',import.meta.url),'utf8');
const blob=source.slice(source.indexOf('\t\t-- RootAttachment replacement'),source.indexOf('\t\t-- Resonance hold/drop flow'));
const snow=source.slice(source.indexOf('\t\t-- Snowball owns its snapshots'),source.indexOf('\t\t-- BEGIN BREAK PCLD'));
const state=await LuauState.createAsync();
await state.loadstring(`
local controls={}
local function bind(id,_,_,fn,stop) controls[id]={run=fn,stop=stop} end
local function add(id,_,key,interval,fn,stop) bind(id,key,interval,fn,stop) end
local Hub={new=function(_,parent) return {Parent=parent,Destroy=function(self) self.Parent=nil end} end}
local ReplicatedStorage={}
local limb={Parent=true,CanCollide=true,CustomPhysicalProperties=nil}
local root={Parent=true,Massless=true,CanCollide=true,CustomPhysicalProperties=nil,attachment={Parent=true,IsA=function() return true end}}
function root:FindFirstChild(name) if name=='RootAttachment' then return self.attachment elseif name=='WeldHRP' then return {Enabled=true} elseif name=='RagdollLimbPart' then return limb end end
function root:IsA() return true end
local jumping=false
local hum={Parent=true,AutoRotate=false,Sit=false,SetStateEnabled=function(_,_,on) jumping=on end,GetStateEnabled=function() return jumping end}
local char={FindFirstChild=function() return nil end,GetChildren=function() return {root} end}
local function charAlive() return char,root,hum,true end
local tbl8={}
local tbl11={RagdollRemote={FireServer=function() end}}
local tbl12={RepositionLimbs=function() end,ToggleCollisions=function() root.CanCollide=false;root.CustomPhysicalProperties='light';limb.CanCollide=false end}
local Enum={HumanoidStateType={Jumping='Jumping'}}
local game={GetService=function() return {UnbindAction=function() end} end}
${blob}
${snow}
local b=controls.AntiBlobmanToggle
b.run();assert(not root.Massless and root.attachment.Parent==ReplicatedStorage)
b.stop();assert(root.Massless and root.attachment.Parent==root,'blob disable restores mass and attachment')
b.stop();assert(root.Massless,'blob cleanup idempotent')
root.Massless=false;b.run();b.stop();assert(not root.Massless,'preserve original false massless')
local s=controls.SourceAntiSnowball
s.run();assert(hum.AutoRotate and jumping and not root.CanCollide and not limb.CanCollide)
s.run();s.stop();assert(not hum.AutoRotate and not jumping and root.CanCollide and limb.CanCollide and root.CustomPhysicalProperties==nil,'snowball restores original state: '..tostring(hum.AutoRotate)..' '..tostring(jumping)..' '..tostring(root.CanCollide)..' '..tostring(limb.CanCollide)..' '..tostring(root.CustomPhysicalProperties))
s.stop();assert(not hum.AutoRotate and root.CanCollide,'snowball cleanup idempotent')
return true
`,'protection cleanup',true)();console.log('PASS Blobman attachment/mass restoration and Snowball rotation/jump/collision/physics restoration');state.destroy();
