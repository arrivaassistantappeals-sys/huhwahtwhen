"""Check ownership gating, confirmed whitelist membership, and owned-toy cleanup."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
Players.LocalPlayer=Player
Tabs.Whitelist=Tabs.Misc
Hub.manualWhitelist={[tostring(a.UserId)]="A"}
Hub.friendCache={};Hub.whitelistFriends=false
local oldNode=node
node=function(...)
    local result=oldNode(...)
    local find=result.FindFirstChild
    function result:FindFirstChild(name,recursive)
        local direct=find(self,name);if direct then return direct end
        if recursive then for _,child in ipairs(self:GetDescendants()) do if child.Name==name then return child end end end
    end
    return result
end
local cfmeta={__mul=function(a,b) return setmetatable({Position=b.Position and a.Position+b.Position or a.Position,Rotation={}},getmetatable(a)) end}
CFrame.new=function(x,y,z)
    local v=type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)
    return setmetatable({Position=v,Rotation={}},cfmeta)
end
CFrame.Angles=function() return CFrame.new() end
root.CFrame=CFrame.new(root.Position)
local function characterFor(person)
    local r=node("HumanoidRootPart",{},"BasePart");r.Position=Vector3.new(10,0,0);r.CFrame=CFrame.new(r.Position)
    local owner=node("PartOwner",{},"StringValue");owner.Value=""
    local head=node("Head",{owner},"BasePart")
    local hum=node("Humanoid",{},"Humanoid");hum.Health=100
    local hitbox=node("RagdollTouchedHitbox",{},"BasePart");hitbox.Parent=r;r.children={hitbox}
    local char=node(person.Name,{r,head,hum},"Model");person.Character=char
    return char,r,owner,hitbox
end
local ac,ar,ao,ah=characterFor(a)
local bc,br,bo,bh=characterFor(b)
local cc,cr,co,ch=characterFor(c)
local folder=node(Player.Name.."SpawnedInToys");named[folder.Name]=folder
local requests={}
local grant=true
local confirmWeld=true
local spawned=0
local deleted={}
local function makeToy()
    local marker=node("PartOwner",{},"StringValue");marker.Value=Player.Name
    local weld=node("StickyWeld",{},"WeldConstraint")
    local sticky=node("StickyPart",{weld,marker},"BasePart");sticky.Position=Vector3.new(0,4,0)
    local toy=node("NinjaShuriken",{sticky},"Model");toy.Parent=folder
    table.insert(folder.children,toy)
    return toy
end
local originals=makeToy()
local ownerRemote={FireServer=function(_,part,frame)
    table.insert(requests,{kind="owner",part=part})
    if grant and part==ar then ao.Value=Player.Name end
end}
local dropRemote={FireServer=function(_,part)
    table.insert(requests,{kind="drop",part=part})
    if part==ar then ao.Value="" end
end}
local stickyRemote={FireServer=function(_,part,hitbox,offset)
    table.insert(requests,{kind="sticky",part=part,target=hitbox})
    if confirmWeld then part:FindFirstChild("StickyWeld").Part1=hitbox end
end}
local spawnRemote={InvokeServer=function(_,name,frame,velocity) assert(name=="NinjaShuriken");spawned+=1;return makeToy() end}
local destroyRemote={FireServer=function(_,toy) table.insert(deleted,toy);toy.Parent=nil end}
local grab={FindFirstChild=function(_,name) if name=="SetNetworkOwner" then return ownerRemote elseif name=="DestroyGrabLine" then return dropRemote end end}
local events={FindFirstChild=function(_,name) if name=="StickyPartEvent" then return stickyRemote end end}
local menu={FindFirstChild=function(_,name) if name=="SpawnToyRemoteFunction" then return spawnRemote elseif name=="DestroyToy" then return destroyRemote end end}
local storage={FindFirstChild=function(_,name) if name=="GrabEvents" then return grab elseif name=="PlayerEvents" then return events elseif name=="MenuToys" then return menu end end}
game.GetService=function(_,name) if name=="Players" then return Players elseif name=="Workspace" then return Workspace elseif name=="ReplicatedStorage" then return storage elseif name=="RunService" then return RunService end;error(name) end
local typeof=function(value) return type(value)=="table" and value.IsA and "Instance" or type(value) end
Workspace.ChildAdded={}
local function runWorker()
    local worker=workers[#workers];local steps=0
    while coroutine.status(worker)~="dead" do steps+=1;assert(steps<30);now+=0.15;local ok,err=coroutine.resume(worker);assert(ok,err) end
end
'''
CASES={
'distant_assistance_requires_opt_in_and_returns_local_character':r'''
    controls.WhitelistAssistGrab:SetValue(true);Hub.sampleWhitelistAssistance()
    local saved=ar.CFrame
    ar.Position=Vector3.new(200,0,0);ao.Value="Attacker";ar.CFrame=CFrame.new(300,0,0)
    Hub.sampleWhitelistAssistance();runWorker();assert(#requests==0)
    local state={position=root.Position,frame=root.CFrame}
    rawset(root,"Position",nil);rawset(root,"CFrame",nil)
    setmetatable(root,{__index=function(_,key) if key=="Position" then return state.position elseif key=="CFrame" then return state.frame end end,
        __newindex=function(_,key,value) if key=="CFrame" then state.frame=value;state.position=value.Position else rawset(root,key,value) end end})
    controls.WhitelistAssistVisits:SetValue(true);now=3
    Hub.sampleWhitelistAssistance();runWorker()
    assert(ar.CFrame==saved and root.Position.Magnitude==0 and #requests>0)
''',
'respawn_cancels_old_restore_and_keeps_new_character_untouched':r'''
    controls.WhitelistAssistGrab:SetValue(true);Hub.sampleWhitelistAssistance()
    ao.Value="Attacker";local moved=CFrame.new(100,0,0);ar.CFrame=moved
    Hub.sampleWhitelistAssistance()
    local ok,err=coroutine.resume(workers[#workers]);assert(ok,err)
    local _,newRoot=characterFor(a)
    Hub.sampleWhitelistAssistance();runWorker()
    assert(ar.CFrame==moved and newRoot.CFrame.Position.X==10)
''',
'anti_grab_waits_for_verified_owner_before_restoring':r'''
    controls.WhitelistAssistGrab:SetValue(true);Hub.sampleWhitelistAssistance()
    local saved=ar.CFrame
    ao.Value="Attacker";ar.CFrame=CFrame.new(100,0,0)
    Hub.sampleWhitelistAssistance();assert(ar.CFrame~=saved)
    runWorker();assert(ar.CFrame==saved and ao.Value=="" and requests[#requests].kind=="drop")
    for _,request in ipairs(requests) do assert(request.part~=br and request.part~=cr) end
''',
'failed_ownership_never_moves_protected_character':r'''
    controls.WhitelistAssistGrab:SetValue(true);Hub.sampleWhitelistAssistance()
    grant=false;ao.Value="Attacker";local moved=CFrame.new(100,0,0);ar.CFrame=moved
    Hub.sampleWhitelistAssistance();runWorker()
    assert(ar.CFrame==moved and #requests==4)
''',
'pending_friend_checks_are_not_assistance_targets':r'''
    Hub.manualWhitelist={};Hub.whitelistFriends=true
    Hub.friendCache[b.UserId]={friend=false,failed=true,expires=100}
    controls.WhitelistAssistGrab:SetValue(true);Hub.sampleWhitelistAssistance()
    ao.Value="Attacker";bo.Value="Attacker";Hub.sampleWhitelistAssistance()
    assert(#workers==0 and #requests==0)
''',
'cancel_after_owner_request_releases_only_our_grab_without_restoring':r'''
    controls.WhitelistAssistGrab:SetValue(true);Hub.sampleWhitelistAssistance()
    ao.Value="Attacker";local moved=CFrame.new(100,0,0);ar.CFrame=moved
    Hub.sampleWhitelistAssistance()
    local ok,err=coroutine.resume(workers[#workers]);assert(ok,err);assert(ao.Value==Player.Name)
    controls.WhitelistAssistGrab:SetValue(false);runWorker()
    assert(ar.CFrame==moved and ao.Value=="" and requests[#requests].kind=="drop")
''',
'explosion_signal_only_restores_nearby_trusted_player':r'''
    controls.WhitelistAssistExplosion:SetValue(true);Hub.sampleWhitelistAssistance()
    local original=ar.CFrame;ar.CFrame=CFrame.new(100,0,0)
    local blast=node("Part",{},"BasePart");blast.Position=ar.Position
    emit(Workspace.ChildAdded,blast);runWorker()
    assert(ar.CFrame==original and #requests>0)
''',
'anti_kick_requires_actual_weld_and_removes_only_its_toy':r'''
    controls.WhitelistAssistKick:SetValue(true);Hub.sampleWhitelistAssistance();runWorker()
    assert(spawned==1)
    Hub.sampleWhitelistAssistance();runWorker();Hub.sampleWhitelistAssistance()
    assert(requests[#requests].kind=="sticky" and requests[#requests].target==ah)
    controls.WhitelistAssistKick:SetValue(false)
    assert(#deleted==1 and deleted[1]~=originals and originals.Parent==folder)
''',
'no_confirmed_anti_kick_status_for_failed_attachment':r'''
    confirmWeld=false
    controls.WhitelistAssistKick:SetValue(true);Hub.sampleWhitelistAssistance();runWorker()
    Hub.sampleWhitelistAssistance();runWorker();Hub.sampleWhitelistAssistance()
    buttons["Whitelist assistance status"]()
    assert(notices[#notices].Description:find("0 confirmed shuriken",1,true))
''',
'removing_whitelist_membership_cleans_only_owned_helper':r'''
    controls.WhitelistAssistKick:SetValue(true);Hub.sampleWhitelistAssistance();runWorker()
    Hub.manualWhitelist={};Hub.sampleWhitelistAssistance()
    assert(#deleted==1 and deleted[1]~=originals and originals.Parent==folder)
''',
}
class WhitelistAssistance(unittest.TestCase):pass
def case(body):
    def test(self):
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        source=(ROOT/'docs/review/whitelist-assistance.lua').read_text()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'assist.luau';p.write_text(fixture+'\n'+SETUP+'\n'+source+'\n'+body)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    return test
for name,body in CASES.items():setattr(WhitelistAssistance,'test_'+name,case(body))
