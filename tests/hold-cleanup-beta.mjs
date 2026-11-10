import fs from 'node:fs';import {LuauState} from 'luau-web';
const source=fs.readFileSync(new URL('../dist/Arriva Core Hub 2.5Beta.lua',import.meta.url),'utf8');
const start=source.indexOf('TargetGroup:AddToggle("LoopKickToggle2",');
const helpers=source.slice(source.indexOf('\t\tlocal boundCharacter=',start),source.indexOf('\n\t\tautoblob(running)',start));
const state=await LuauState.createAsync();state.loadstring(source,'full beta',true);
await state.loadstring(`
local char={};local Player={Character=char}
local callbacks={};local function onCleanup(fn) table.insert(callbacks,fn) end
local seat={};local toy={Parent=true,CFrame='moved',AssemblyLinearVelocity='moving'}
local Vector3={zero='zero'}
local releases=0
local Hub={getLoopBlobSeat=function() return seat end,fire=function() releases+=1 end}
local ReplicatedStorage={FindFirstChild=function() return {FindFirstChild=function() return {} end} end}
${helpers}
local a={Parent=char,PlatformStand=true,Sit=true}
local b={Parent=char,PlatformStand=true,Sit=false}
changed[a]={char=char,platform=false,sit=false}
changed[b]={char=char,platform=false,sit=true}
heldRoot,heldDrop,heldWeld={Parent=true},{Parent=true},{Parent=true}
releaseTarget(b)
assert(not a.PlatformStand and not a.Sit and b.PlatformStand and not b.Sit,'switch releases old humanoid while preserving current one')
releaseTarget()
assert(not b.PlatformStand and b.Sit and releases==2,'full release restores state and releases both handles')
releaseTarget();assert(releases==2,'idempotent release')
blobReturn={root=toy,frame='saved',seat=seat};restoreBlobPosition()
assert(toy.CFrame=='saved' and toy.AssemblyLinearVelocity=='zero','restore active toy')
toy.CFrame='new session';blobReturn={root=toy,frame='stale',seat=seat};Player.Character={};restoreBlobPosition()
assert(toy.CFrame=='new session','old character cannot restore current toy')
Player.Character=char;blobReturn={root=toy,frame='stale',seat={}};restoreBlobPosition()
assert(toy.CFrame=='new session','different seat cannot restore old toy')
for _,fn in ipairs(callbacks) do fn() end
return true
`,'hold cleanup',true)();console.log('PASS full compilation, target switch/release, idempotency, character and seat replacement cleanup');state.destroy();
