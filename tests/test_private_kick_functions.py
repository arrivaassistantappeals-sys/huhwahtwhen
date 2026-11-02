"""Regular apply/loop controls and callable private-server kick functions."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'dist/resonance-private.lua'
SETUP=r'''
    Hub.env={}
    targetHum.FindFirstChild=function() return {Value=true} end
    Hub.selectedTargets={[a.UserId]=a}
    Hub.isSelectedTarget=function(person) return person and Hub.selectedTargets[person.UserId]==person end
    local friendChecks=0
    local oldFriendCheck=Player.IsFriendsWithAsync
    Player.IsFriendsWithAsync=function(...) friendChecks+=1;return oldFriendCheck(...) end
    task.delay=function(seconds,callback)
        local thread=coroutine.create(callback)
        table.insert(delayed,{at=now+seconds,callback=function()
            if coroutine.status(thread)~="dead" then local ok,err=coroutine.resume(thread);assert(ok,err) end
        end})
        return thread
    end
    local function choose(method)
        controls.PrivateKickMethod:SetValue(method or "Grab-Drop")
        Hub.selectedTargets={[a.UserId]=a}
    end
'''
CASES={
'ownership_height_uses_the_original_ring_and_updates_live':r'''
    choose("Ownership");assert(Hub.privateKick.Ownership(a));step()
    local force=lastCreated("BodyPosition")
    assert(force.Position.X==10 and force.Position.Y==15 and force.Position.Z==0)
    controls.PrivateKickHeight:SetValue(28);runFor(0.3)
    assert(force.Position.Y==28)
    Hub.privateKick.Stop();restored()
''',
'blobman_offsets_are_separate_from_ownership_height':r'''
    choose("Grab-Drop");assert(Hub.privateKick.GrabDrop(a));runFor(0.3)
    local force=lastCreated("BodyPosition")
    assert(force.Position.X==0 and force.Position.Y==25 and force.Position.Z==0)
    controls.PrivateKickHeight:SetValue(0)
    controls.PrivateBlobKickX:SetValue(2);controls.PrivateBlobKickY:SetValue(40);controls.PrivateBlobKickZ:SetValue(-3)
    runFor(0.4)
    assert(force.Position.X==2 and force.Position.Y==40 and force.Position.Z==-3)
    Hub.privateKick.Stop();restored()
''',
'faster_delay_defers_drop_and_stop_cancels_it':r'''
    choose("Ownership");controls.PrivateKickDelayMode:SetValue("Faster but worse")
    assert(Hub.privateKick.Ownership(a));step(0.05)
    for _,request in ipairs(sent) do assert(request.remote~=dropLine) end
    step(0.05)
    for _,request in ipairs(sent) do assert(request.remote~=dropLine) end
    Hub.privateKick.Stop();local count=#sent;runFor(0.4)
    assert(#sent==count);restored()
''',
'faster_delay_releases_after_two_tenths_and_normal_releases_next_frame':r'''
    choose("Ownership");assert(Hub.privateKick.Ownership(a));step(0.05);step(0.05)
    assert(sent[#sent].remote==dropLine)
    Hub.privateKick.Stop();table.clear(sent)
    controls.PrivateKickDelayMode:SetValue("Faster but worse")
    assert(Hub.privateKick.Ownership(a));step(0.05)
    local started=now
    step(0.1)
    for _,request in ipairs(sent) do assert(request.remote~=dropLine) end
    step(0.11)
    local found=false;for _,request in ipairs(sent) do if request.remote==dropLine then found=true end end
    assert(found and now-started>=0.2)
    Hub.privateKick.Stop();restored()
''',
'loop_ragdoll_uses_the_original_pallet_helper_and_cleans_up':r'''
    local old=ReplicatedStorage.FindFirstChild
    local flag={Value=false}
    targetHum.FindFirstChild=function(_,name) return name=="Ragdolled" and flag or nil end
    local head=node("Head",{node("PartOwner")},"BasePart")
    local torso=node("Torso",nil,"BasePart")
    head.Parent=targetCharacter;torso.Parent=targetCharacter
    local oldCharacterFind=targetCharacter.FindFirstChild
    targetCharacter.FindFirstChild=function(self,name)
        if name=="Head" then return head elseif name=="Torso" then return torso end
        return oldCharacterFind(self,name)
    end
    local spawnRemote,destroyRemote={},{}
    ReplicatedStorage.FindFirstChild=function(self,name)
        if name=="MenuToys" then return {FindFirstChild=function(_,key)
            if key=="SpawnToyRemoteFunction" then return spawnRemote elseif key=="DestroyToy" then return destroyRemote end
        end} end
        return old(self,name)
    end
    local spawnCount=0
    local pallet,sound
    Hub.invoke=function(remote,name)
        assert(remote==spawnRemote and name=="PalletLightBrown")
        spawnCount+=1;sound=node("SoundPart",nil,"BasePart")
        pallet=node("PalletLightBrown",{sound,node("Main",nil,"BasePart")},"Model");pallet.Parent=ownFolder
        return pallet
    end
    Hub.sourceGucci={helpers={SpawnToy=function(name) return Hub.invoke(spawnRemote,name) end}}
    local oldType=typeof
    typeof=function(value) if value==pallet then return "Instance" end;return oldType(value) end
    choose("Ownership");controls.PrivateKickRagdoll:SetValue(false)
    assert(Hub.privateKick.Ownership(a));runFor(0.3);assert(spawnCount==0)
    controls.PrivateKickRagdoll:SetValue(true);runFor(0.5)
    assert(spawnCount==1 and sound.Position==torso.Position)
    assert(lastCreated("BodyPosition").Name=="RagdollBP")
    Hub.privateKick.Stop()
    local destroyed=false;for _,request in ipairs(sent) do if request.remote==destroyRemote then destroyed=true end end
    assert(destroyed);restored()
''',
'grab_drop_extra_ownership_is_optional':r'''
    choose("Grab-Drop");assert(Hub.privateKick.GrabDrop(a));runFor(0.4)
    for _,request in ipairs(sent) do assert(request.remote~=ownerRemote) end
    controls.PrivateBlobKickNetworkOwner:SetValue(true);runFor(0.4)
    local found=false;for _,request in ipairs(sent) do if request.remote==ownerRemote then found=true end end
    assert(found);Hub.privateKick.Stop();restored()
''',
'height_and_blob_offsets_do_not_change_void':r'''
    controls.PrivateKickHeight:SetValue(0);controls.PrivateBlobKickY:SetValue(10)
    assert(Hub.privateKick.Void(a));step()
    assert(targetRoot.CFrame.Position.Y==9e9 and targetRoot.AssemblyLinearVelocity.Y==9e9)
    runFor(0.4);assert(not Hub.privateKick.IsBusy())
''',
'functions_expose_all_four_methods_and_restore_looped_attempts':r'''
    assert(Hub.env.ArrivaPrivateKick==Hub.privateKick)
    for _,method in ipairs({"GrabDrop","GrabRelease","Ownership"}) do
        local count=#sent
        assert(Hub.privateKick[method](a));runFor(4)
        assert(#sent>count and not Hub.privateKick.IsBusy());restored()
    end
    assert(Hub.privateKick.Void(a));step();assert(targetRoot.CFrame.Position.Y==9e9)
    runFor(0.4);assert(not Hub.privateKick.IsBusy())
''',
'apply_selected_runs_once_and_never_starts_from_defaults':r'''
    assert(#sent==0 and #workers==0 and not Hub.privateKick.IsBusy())
    choose("Ownership")
    assert(buttons["Apply kick to selected"]());runFor(4)
    assert(friendChecks==1 and not Hub.privateKick.IsBusy())
    local count=#sent;runFor(4);assert(#sent==count);restored()
''',
'loop_selected_repeats_and_stop_cleans_both_workers':r'''
    choose("Ownership");assert(Hub.privateKick.LoopSelected())
    assert(controls.PrivateKickLoop.Value)
    runFor(7);assert(friendChecks>=2 and Hub.privateKick.IsBusy())
    buttons["Stop private kicks"]();assert(not controls.PrivateKickLoop.Value)
    local count=#sent;runFor(2);assert(#sent==count and not Hub.privateKick.IsBusy());restored()
''',
'private_checks_cover_functions_buttons_and_loop_toggle':r'''
    game.PrivateServerId=""
    for _,method in ipairs({"GrabDrop","GrabRelease","Ownership","Void"}) do assert(not Hub.privateKick[method](a)) end
    assert(not Hub.privateKick.ApplySelected())
    controls.PrivateKickLoop:SetValue(true)
    assert(not controls.PrivateKickLoop.Value and #sent==0 and not Hub.privateKick.IsBusy())
''',
'unknown_method_and_nonfriend_are_rejected':r'''
    assert(not Hub.privateKick.Kick(a,"bad method"))
    isFriend=false;assert(Hub.privateKick.Void(a));runFor(0.2)
    assert(#sent==0 and not Hub.privateKick.IsBusy());restored()
''',
'loop_skips_deselected_targets_and_stops_on_private_metadata_loss':r'''
    choose("Ownership");assert(Hub.privateKick.LoopSelected());runFor(0.3)
    Hub.selectedTargets={};runFor(0.3)
    local count=#sent;runFor(1);assert(#sent==count);restored()
    game.PrivateServerId="";runFor(1)
    assert(not Hub.privateKick.IsBusy() and not controls.PrivateKickLoop.Value)
''',
'respawn_stops_loop_and_pending_friend_check':r'''
    choose("Ownership");blockFriend=true
    assert(Hub.privateKick.LoopSelected());runFor(0.2)
    emit(Player.CharacterRemoving);blockFriend=false;runFor(1)
    assert(#sent==0 and not Hub.privateKick.IsBusy() and not controls.PrivateKickLoop.Value)
''',
'direct_call_cannot_compete_with_selected_loop':r'''
    choose("Ownership");assert(Hub.privateKick.LoopSelected());runFor(0.2)
    assert(not Hub.privateKick.Void(a));Hub.privateKick.Stop();restored()
''',
}
class PrivateKickFunctions(unittest.TestCase):
    def test_normal_build_keeps_storage_and_actions_separate(self):
        source=PATH.read_text()
        self.assertIn('PrivateKickConfigs',source)
        self.assertIn('PrivateKickWhitelist.json',source)
        self.assertNotIn('PrivateKickTestTarget',source)
        self.assertNotIn('PrivateKickTestDuration',source)
        self.assertIn('SetIgnoreIndexes({"MultiWhitelist","PrivateKickLoop"})',source)
        self.assertNotIn('-- BEGIN PRIVATE KICK METHODS',(ROOT/'dist/resonance.lua').read_text())
        self.assertLess(source.index('Private server could not be verified'),source.index('local Hub ='))

def case(body):
    def test(self):
        source=PATH.read_text();a=source.index('-- BEGIN PRIVATE KICK METHODS');b=source.index('-- END PRIVATE KICK METHODS',a)
        fixture='\n'.join((ROOT/p).read_text() for p in ['tests/fixtures/feature_pack_runtime.luau','tests/fixtures/private_kick_runtime.luau'])
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'functions.luau';path.write_text(fixture+'\n'+SETUP+'\n'+source[a:b]+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,body in CASES.items():setattr(PrivateKickFunctions,'test_'+name,case(body))
if __name__=='__main__':unittest.main()
