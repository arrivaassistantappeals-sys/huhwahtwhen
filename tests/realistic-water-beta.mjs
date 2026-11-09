import fs from 'node:fs';import {LuauState} from 'luau-web';
const s=fs.readFileSync(new URL('../dist/Arriva Core Hub 2.5Beta.lua',import.meta.url),'utf8');const module=s.slice(s.indexOf('-- BEGIN TERRAIN REALISTIC WATER'),s.indexOf('-- END TERRAIN REALISTIC WATER'));
const code=`
local mt={};local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end;mt.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end;mt.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
local Vector3={new=vec,zero=vec(0,0,0)};local Vector3int16={new=vec};local Region3int16={new=function(a,b) return {a=a,b=b} end};local Region3={}
Region3.new=function(a,b) return {low=a,high=b,CFrame={Position=(a+b)/2},Size=b-a,ExpandToGrid=function(self,grid)
 local a=vec(math.floor(self.low.X/grid)*grid,math.floor(self.low.Y/grid)*grid,math.floor(self.low.Z/grid)*grid)
 local b=vec(math.ceil(self.high.X/grid)*grid,math.ceil(self.high.Y/grid)*grid,math.ceil(self.high.Z/grid)*grid)
 return {CFrame={Position=(a+b)/2},Size=b-a} end} end
local function signal() local listeners={};return {Fire=function(_,...) for _,fn in ipairs(listeners) do fn(...) end end,Connect=function(_,fn) table.insert(listeners,fn);return {Disconnect=function() end} end} end
local now=0;local os={clock=function() return now end}
local queue={};local task={defer=function(fn) local t=coroutine.create(fn);table.insert(queue,t);return t end,wait=function(dt) now+=dt or 0.01;coroutine.yield() end}
task.spawn=task.defer
local function step() local t=table.remove(queue,1);if not t then return end;local ok,err=coroutine.resume(t);assert(ok,tostring(err));if coroutine.status(t)~='dead' then table.insert(queue,t) end end
local function flush() for i=1,50000 do if #queue==0 then return end;step() end;error('worker stuck') end
local failWater=false
local copies,pastes,destroyed,fills=0,0,0,0;local data='stone';local lastRegion
local part
local terrain={ReadVoxels=function(_,region,res) assert(res==4);copies+=1;return {{{data}}},{{{data=='air' and 0 or 1}}} end,
 FillRegion=function(_,region,res,material) if material=='Water' then assert(part==nil or part.Transparency~=1,'surface remains visible until fill succeeds');if failWater then error('mock terrain failure') end end;fills+=1;now+=0.005;lastRegion=region;data=material=='Water' and 'water' or 'air' end,
 WriteVoxels=function(_,region,res,materials,occupancy) assert(res==4);pastes+=1;destroyed+=1;data=materials[1][1][1] end}
part={Parent={},Transparency=0.25,Position=vec(0,4,0),Size=vec(8,4,4),IsA=function(_,kind) return kind=='BasePart' end,GetPropertyChangedSignal=function() return signal() end}
local parts={part};local model={GetDescendants=function() return parts end};local available=true;local node;node={FindFirstChild=function(_,name) if name=='ObjectModel' then return available and model or nil end;return node end}
local Workspace={FindFirstChild=function() return node end,DescendantAdded=signal()};local Enum={Material={Water='Water',Air='Air'}}
local waterObjects={};local savedWater;local waterOn=false;local water={WaterTransparency=0.3};terrain.WaterTransparency=1
Workspace.Map={AlwaysHereTweenedObjects={Ocean={Object={ObjectModel=model}}}}
model.QueryDescendants=function() return parts end
local RunService={Heartbeat={Wait=function() task.wait() end}}
local Hub={alive=true,connections={},nativeTask={cancel=coroutine.close},connect=function(event,fn) return event:Connect(fn) end,cleanup=function() end,requestSave=function() end}
local toggles,sliders={},{};local text
local waterGroup={AddLabel=function() return {SetText=function(_,v) text=v end} end,AddToggle=function(_,id,info) toggles[id]=info.Callback end,AddSlider=function(_,id,info) sliders[id]=info.Callback end}
local warn=function() end
${module}
toggles.SourceRealisticWater(true);flush()
assert(copies==0 and pastes==0 and fills>0,'reference fills directly without voxel backups')
assert(part.Transparency==1 and data=='water','surface hidden and Terrain filled')
assert(lastRegion.low.Y==-4,'reference vertical offset')
toggles.SourceRealisticWater(false);flush()
assert(data=='air' and part.Transparency==0.25,'reference clears generated regions to Air and restores surface')
part.Size=vec(1100,4,4);toggles.SourceRealisticWater(true);step();assert(#queue>0,'4ms budget yields')
toggles.SourceRealisticWater(false);flush();assert(part.Transparency==0.25 and data=='air','cancelled conversion clears completed regions')
available=false;toggles.SourceRealisticWater(true);step();assert(#queue>0 and part.Transparency==0.25,'missing ocean waits without hiding surface')
available=true;model.QueryDescendants=nil;flush();assert(data=='water' and part.Transparency==1,'late ocean and query fallback generate')
toggles.SourceRealisticWater(false);flush()
available=false;toggles.SourceRealisticWater(true);step();toggles.SourceRealisticWater(false);flush();assert(part.Transparency==0.25,'waiting generation cancels')
available=true;failWater=true;toggles.SourceRealisticWater(true);flush()
assert(part.Transparency==0.25 and tostring(Hub.lastWorkerError):find('mock terrain failure'),'failed fill keeps original visible and records error')
failWater=false;toggles.SourceRealisticWater(false);flush();toggles.SourceRealisticWater(true);flush();assert(part.Transparency==1,'retry succeeds')
toggles.SourceRealisticWater(false);flush()
return 'PASS: delayed loading, descendant fallback, fill failure restoration, retry, 4ms yielding and cancellation'

`;
const state=await LuauState.createAsync();console.log(await state.loadstring(code,'reference water',true)());state.destroy();
