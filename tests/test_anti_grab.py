"""Run the production Anti Grab handler against mocked held-state events."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
CASES={
    'rapid_regrab_is_retried_after_cooldown': r'''
        controls.AntiGrabObsidian:SetValue(true)
        setHeld(true);setHeld(false)
        advance(0.1);setHeld(true)
        assert(#requests==3)
        advance(0.26);emit(RunService.Heartbeat,0.16)
        assert(#requests==6 and root.Anchored)
        advance(0.52);emit(RunService.Heartbeat,0.26)
        assert(#requests==9)
        setHeld(false)
        advance(1);emit(RunService.Heartbeat,0.48)
        assert(#requests==9 and not root.Anchored and torso.Anchored)
    ''',

    'persistent_hold_retries_are_bounded_and_do_not_refreeze': r'''
        controls.AntiGrabObsidian:SetValue(true);setHeld(true)
        for tick=1,300 do
            advance(tick/100);emit(RunService.Heartbeat,0.01)
        end
        assert(#requests>=30 and #requests<=39)
        assert(not root.Anchored and torso.Anchored)
        buttons["Release local grab freeze"]()
        advance(4);emit(RunService.Heartbeat,1)
        assert(not root.Anchored)
        controls.AntiGrabObsidian:SetValue(false)
        local count=#requests
        advance(5);emit(RunService.Heartbeat,1)
        assert(#requests==count and #workers==0)
    ''',

    'held_retries_resume_after_seating_and_safe_zone_end': r'''
        controls.AntiGrabObsidian:SetValue(true)
        hum.SeatPart={};setHeld(true)
        advance(1);emit(RunService.Heartbeat,1)
        assert(#requests==0)
        hum.SeatPart=nil;Hub.safeZoneLoopActive=true
        advance(2);emit(RunService.Heartbeat,1)
        assert(#requests==0)
        Hub.safeZoneLoopActive=false
        advance(3);emit(RunService.Heartbeat,1)
        assert(#requests==3 and root.Anchored)
        Hub.safeZoneLoopActive=true
        advance(3.1);emit(RunService.Heartbeat,0.1)
        assert(not root.Anchored and torso.Anchored and #requests==3)
        controls.AntiGrabObsidian:SetValue(false)
    ''',

    'held_events_restore_anchors_and_use_the_correct_remotes': r'''
        controls.AntiGrabObsidian:SetValue(true)
        setHeld(true)
        assert(root.Anchored and head.Anchored and torso.Anchored)
        assert(#requests==3 and requests[2][1]=="RagdollRemote" and requests[2][2]==root and requests[2][3]==0)
        setHeld(false)
        assert(not root.Anchored and not head.Anchored and torso.Anchored)
        assert(#workers==0) -- no accumulating polling workers
    ''',

    'freeze_is_bounded_and_survives_missing_remotes_and_characters': r'''
        Player.Character=nil
        controls.AntiGrabObsidian:SetValue(true)
        setHeld(true) -- should not access a missing Character
        Player.Character=char
        emit(Player.CharacterAdded,char)
        assert(root.Anchored)
        advance(2.1);emit(RunService.Heartbeat,0.1)
        assert(not root.Anchored and torso.Anchored)
        setHeld(false)
        remotes={}
        advance(3);setHeld(true)
        assert(root.Anchored and #requests==6)
        controls.AntiGrabObsidian:SetValue(false)
        assert(not root.Anchored)
    ''',

    'late_replaced_held_flag_and_foreign_owner_value_changes': r'''
        Player.held=nil
        controls.AntiGrabObsidian:SetValue(true)
        Player.held=heldFlag(false)
        emit(Player.ChildAdded,Player.held)
        setHeld(true)
        assert(root.Anchored)
        setHeld(false)
        advance(1)
        local owner={Name="PartOwner", Value=Player.Name, Parent=head, valueSignal={},
            IsA=function(_, kind) return kind=="StringValue" end,
            GetPropertyChangedSignal=function(self) return self.valueSignal end}
        head.owner=owner;emit(char.DescendantAdded,owner)
        assert(not root.Anchored)
        owner.Value="SomeoneElse";emit(owner.valueSignal)
        assert(root.Anchored)
        emit(Player.ChildRemoved,Player.held)
        assert(not root.Anchored)
    ''',

    'optional_stand_recovery_skips_ragdolls_and_regrabs': r'''
        controls.AntiGrabObsidian:SetValue(true)
        controls.RecoverMovementAfterGrab:SetValue(true)
        setHeld(true);hum.PlatformStand=true;setHeld(false)
        advance(0.25)
        assert(not hum.PlatformStand and hum.lastState=="GettingUp")
        advance(1);setHeld(true);hum.PlatformStand=true
        hum.ragdolled={Value=true};setHeld(false);advance(1.3)
        assert(hum.PlatformStand)
        hum.ragdolled.Value=false
        advance(2);setHeld(true);setHeld(false);setHeld(true);advance(2.3)
        assert(hum.PlatformStand) -- a new grab cancels pending stand recovery
        controls.AntiGrabObsidian:SetValue(false)
        assert(not root.Anchored)
    ''',

    'grab_ignores_seating_and_preserves_original_anchors_on_unload': r'''
        controls.AntiGrabObsidian:SetValue(true)
        hum.SeatPart={};setHeld(true)
        assert(not root.Anchored and #requests==0)
        hum.SeatPart=nil;setHeld(false);advance(1);setHeld(true)
        assert(root.Anchored)
        for _, cleanup in ipairs(cleanups) do cleanup() end
        assert(not root.Anchored and not head.Anchored and torso.Anchored)
        assert(Hub.releaseGrabProtection==nil)
    ''',

    'throw_impulse_after_release_is_damped_for_a_bounded_window': r'''
 controls.AntiGrabObsidian:SetValue(true);setHeld(true);setHeld(false)
 root.AssemblyLinearVelocity=Vector3.new(500,0,0)
 root.AssemblyAngularVelocity=Vector3.new(0,500,0)
 advance(0.1);emit(RunService.Heartbeat,0.1)
 assert(root.AssemblyLinearVelocity.Magnitude==0 and root.AssemblyAngularVelocity.Magnitude==0)
 assert(not root.Anchored and torso.Anchored)
 advance(0.31);root.AssemblyLinearVelocity=Vector3.new(10,0,0)
 emit(RunService.Heartbeat,0.21)
 assert(root.AssemblyLinearVelocity.Magnitude==10)
 ''',

    'release_guard_stops_on_disable_seating_and_character_change': r'''
 controls.AntiGrabObsidian:SetValue(true);setHeld(true);setHeld(false)
 hum.SeatPart={};root.AssemblyLinearVelocity=Vector3.new(20,0,0)
 advance(0.1);emit(RunService.Heartbeat,0.1)
 assert(root.AssemblyLinearVelocity.Magnitude==20)
 hum.SeatPart=nil;advance(1);setHeld(true);setHeld(false)
 controls.AntiGrabObsidian:SetValue(false)
 root.AssemblyLinearVelocity=Vector3.new(30,0,0)
 advance(1.1);emit(RunService.Heartbeat,0.1)
 assert(root.AssemblyLinearVelocity.Magnitude==30)
 controls.AntiGrabObsidian:SetValue(true);advance(2);setHeld(true);setHeld(false)
 Player.Character=nil;emit(Player.CharacterRemoving,char)
 root.AssemblyLinearVelocity=Vector3.new(40,0,0)
 advance(2.1);emit(RunService.Heartbeat,0.1)
 assert(root.AssemblyLinearVelocity.Magnitude==40 and not root.Anchored)
 ''',

    'respawn_resets_attempt_cooldown': r'''
 controls.AntiGrabObsidian:SetValue(true);setHeld(true)
 local count=#requests
 advance(0.05);emit(Player.CharacterRemoving,char);emit(Player.CharacterAdded,char)
 assert(#requests==count+3 and root.Anchored)
 ''',
}

class AntiGrab(unittest.TestCase):
    def test_toggle_has_one_handler(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        self.assertNotIn('Toggles.AntiGrabObsidian.Callback=',source)
        self.assertNotIn('tbl12.AntiGrab = function',source)
        self.assertNotIn('SourceAntiGrabMode',source)

def case(body):
    def test(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        start=source.index('-- Anti Grab: react to actual held-state changes')
        end=source.index('Hub.blobParts = {}',start)
        fixture=(ROOT/'tests/fixtures/anti_grab_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'anti_grab.luau'
            path.write_text(fixture+source[start:end]+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test

for name,body in CASES.items():
    setattr(AntiGrab,'test_'+name,case(body))

if __name__=='__main__': unittest.main()
