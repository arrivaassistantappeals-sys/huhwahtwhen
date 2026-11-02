"""Run actual production missile/cache controllers with deterministic client mocks."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
CASES={
'ownership_retries_same_toy_beyond_old_timeout_then_completes':r'''
    local ready
    assert(Hub.prepareExplosive("BombMissile",function(entry) ready=entry end))
    runFor(20)
    assert(spawned==1 and not ready and Hub.missileWorkBusy())
    assert(ownerRequests<=16,"ownership retry requests must back off")
    owned=true;step()
    assert(ready and ready.model==lastToy and not Hub.missileWorkBusy() and spawned==1)
''',
'one_pending_ownership_claim_preserves_existing_ready_cache':r'''
    local first,second
    owned=true;assert(Hub.prepareExplosive("BombMissile",function(entry) first=entry end));step()
    assert(first and Hub.isMissileReserved(first.model))
    owned=false;assert(Hub.prepareExplosive("BombMissile",function(entry) second=entry end));runFor(20)
    assert(first.force.Parent and Hub.isMissileReserved(first.model) and spawned==2 and not second)
    owned=true;step();assert(second)
''',
'spam_keeps_firing_ready_toys_during_long_ownership_retry':r'''
    owned=true;controls.BlitzExplosionAmount:SetValue(2);controls.BlitzExplodeEnabled:SetValue(true);step()
    owned=false;step();runFor(20)
    assert(controls.BlitzExplodeEnabled.Value and spawned==2 and exploded>1)
    owned=true;step();assert(not Hub.missileWorkBusy())
''',
'preparation_failures_auto_retry_with_backoff_without_disabling_toggle':r'''
    local prepare=Hub.prepareExplosive
    local attempts=0
    Hub.prepareExplosive=function(name,callback)
        attempts+=1
        if attempts<=2 then Hub.lastMissileError="temporary failure";return false end
        return prepare(name,callback)
    end
    owned=true;controls.BlitzExplodeEnabled:SetValue(true);step()
    assert(attempts==1)
    runFor(0.3);assert(attempts==1 and controls.BlitzExplodeEnabled.Value)
    runFor(4)
    assert(attempts==3 and spawned==1 and exploded>0 and controls.BlitzExplodeEnabled.Value)
''',
'manual_retry_does_not_orphan_pending_preparation':r'''
    controls.BlitzExplodeEnabled:SetValue(true);step();runFor(1)
    buttons["Retry cache"]();runFor(1)
    assert(spawned==1 and Hub.missileWorkBusy())
    owned=true;step();step()
    assert(exploded>0 and spawned==1)
''',
'stop_prevents_retries_and_releases_all_forces':r'''
    controls.BlitzExplodeEnabled:SetValue(true);runFor(1)
    controls.BlitzExplodeEnabled:SetValue(false)
    local count=ownerRequests;owned=true;runFor(15)
    assert(spawned==1 and ownerRequests==count and not Hub.missileWorkBusy() and forceCount()==0)
''',
'ownership_checker_can_become_available_late':r'''
    CheckNetworkOwnerShipOnPart=nil
    local ready
    assert(Hub.prepareExplosive("BombMissile",function(entry) ready=entry end));runFor(15)
    assert(spawned==1 and not ready and Hub.missileWorkBusy())
    CheckNetworkOwnerShipOnPart=function() return true end;step()
    assert(ready and not Hub.missileWorkBusy())
''',
'retry_existing_failed_toy_even_when_toy_points_are_full':r'''
    owned=true
    assert(Hub.prepareExplosive("BombMissile",function() error("callback failed") end));step()
    assert(Hub.missileHasRetry("BombMissile") and not Hub.missileWorkBusy() and spawned==1)
    local originalFind=Player.FindFirstChild
    Player.FindFirstChild=function(self,name)
        if name=="UsedToyPoints" or name=="ToysLimitCap" then return {Value=100} end
        return originalFind(self,name)
    end
    controls.BlitzExplosionType:SetValue("Missile")
    controls.BlitzExplodeEnabled:SetValue(true);step();step()
    assert(spawned==1 and exploded>0 and controls.BlitzExplodeEnabled.Value)
''',
'out_of_range_ownership_wait_does_not_send_repeated_requests':r'''
    distance=100
    local ready
    assert(Hub.prepareExplosive("BombMissile",function(entry) ready=entry end));runFor(20)
    assert(ownerRequests==1 and spawned==1 and not ready)
    distance=6;runFor(3);assert(ownerRequests>1)
    owned=true;step();assert(ready)
''',
'failed_preparation_preserves_unrelated_cached_toys':r'''
    owned=true
    local ready
    assert(Hub.prepareExplosive("BombMissile",function(entry) ready=entry end));step()
    assert(Hub.prepareExplosive("BombMissile",function() error("temporary callback fault") end));step()
    assert(ready.force.Parent and Hub.isMissileReserved(ready.model))
    assert(Hub.missileHasRetry("BombMissile"))
''',
'late_spawn_reply_does_not_replace_already_prepared_model':r'''
    slowReply=true
    local originalInvoke=Hub.invoke
    local originalModel,otherModel
    Hub.invoke=function(...)
        local model=originalInvoke(...)
        originalModel=model
        local part=node("Body",nil,"BasePart")
        otherModel=node("BombMissile",{part},"Model")
        otherModel.Parent=ownFolder;otherModel.DescendantAdded={}
        return otherModel
    end
    local ready
    assert(Hub.prepareExplosive("BombMissile",function(entry) ready=entry end));step();step()
    owned=true;step()
    assert(ready.model==originalModel and ready.model~=otherModel)
''',
'key_trigger_survives_temporary_typing_rejection':r'''
    owned=true;typing=true
    controls.BlitzTriggerMode:SetValue("Key")
    controls.BlitzExplodeEnabled:SetValue(true)
    emit(UserInputService.InputBegan,{KeyCode={Name="F"}},false)
    -- Typing filters the initial key event, so press first and then focus a text box.
    typing=false;emit(UserInputService.InputBegan,{KeyCode={Name="F"}},false);typing=true
    step();runFor(0.3);assert(spawned==0)
    typing=false;runFor(2)
    assert(spawned==1 and exploded>0)
''',
'mouse_can_fire_at_sky_without_a_raycast_hit':r'''
    Hub.isMissileReserved=function() return true end
    Hub.missileWorkBusy=function() return false end
    Hub.prepareExplosive=function(name,callback)
        local part=node("Body",nil,"BasePart")
        local model=node(name,{part},"Model");model.Parent=ownFolder
        callback({model=model,hit=part,position=part,force={},release=function() end})
        return true
    end
    Workspace.Raycast=function() return nil end
    local sentPosition
    Hub.fire=function(remote,data,position) if remote==explodeRemote then sentPosition=position end end
    controls.BlitzExplosionTarget:SetValue("Mouse")
    controls.BlitzExplodeEnabled:SetValue(true)
    emit(UserInputService.InputBegan,{KeyCode={Name="F"}},false)
    runFor(1)
    assert(sentPosition and sentPosition.Z==-5000)
''',
'cancel_button_stops_spam_instead_of_being_auto_retried':r'''
    controls.BlitzExplodeEnabled:SetValue(true);runFor(1)
    buttons["Cancel missile actions"]()
    local count=ownerRequests;runFor(15)
    assert(not controls.BlitzExplodeEnabled.Value and ownerRequests==count and not Hub.missileWorkBusy())
''',
'disabling_missile_actions_stops_spam_and_retries':r'''
    controls.BlitzExplodeEnabled:SetValue(true);runFor(1)
    controls.MissileThrowEnabled:SetValue(false)
    local count=ownerRequests;runFor(15)
    assert(not controls.BlitzExplodeEnabled.Value and ownerRequests==count and not Hub.missileWorkBusy())
''',
'failed_explosion_request_keeps_entry_queued_and_retries':r'''
    local fire=Hub.fire
    local attempts=0
    Hub.fire=function(remote,...)
        if remote==explodeRemote then
            attempts+=1
            if attempts==1 then error("temporary explosion send failure") end
        end
        return fire(remote,...)
    end
    owned=true;controls.BlitzExplodeEnabled:SetValue(true);step();step()
    assert(attempts==1 and exploded==0 and spawned==1)
    runFor(0.3);assert(attempts==1)
    runFor(0.5);assert(attempts==2 and exploded==1 and spawned==1 and controls.BlitzExplodeEnabled.Value)
''',
'missing_explosion_remote_does_not_disable_or_discard_ready_cache':r'''
    owned=true;controls.BlitzExplodeEnabled:SetValue(true);step()
    local find=bombRemotes.FindFirstChild;bombRemotes.FindFirstChild=function() return nil end
    runFor(2)
    assert(controls.BlitzExplodeEnabled.Value and exploded==0 and spawned==1 and forceCount()==1)
    bombRemotes.FindFirstChild=find;runFor(1.2)
    assert(exploded==1 and spawned==1)
''',
'respawn_stops_the_ownership_retry':r'''
    controls.BlitzExplodeEnabled:SetValue(true);runFor(1)
    emit(Player.CharacterRemoving)
    local count=ownerRequests;runFor(15)
    assert(not controls.BlitzExplodeEnabled.Value and not Hub.missileWorkBusy() and ownerRequests==count)
''',
}
class MissileRetry(unittest.TestCase):
    def test_shutdown_flood_is_not_shipped(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        self.assertNotIn('Text="Shutdown"',source)
        self.assertNotIn('("ARCO"):rep(1e6)',source)
        self.assertNotIn('for i = 1, 1e6 do',source)

def case(body):
    def test(self):
        source=(ROOT/'dist/resonance.lua').read_text();a=source.index('-- Bounded, cancellable toy actions.');b=source.index('-- End missile throw.',a)
        fixture='\n'.join((ROOT/path).read_text() for path in ['tests/fixtures/feature_pack_runtime.luau','tests/fixtures/missile_runtime.luau'])
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'retry.luau';path.write_text(fixture+'\n'+source[a:b]+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,body in CASES.items():setattr(MissileRetry,'test_'+name,case(body))
if __name__=='__main__':unittest.main()
