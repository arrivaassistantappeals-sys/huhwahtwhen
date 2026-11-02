"""Validate success only after continuous release/ownership/controller checks."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
CASES={
'weld_event_alone_never_claims_active':r'''
    tbl16.Hum.Sit=true;tbl16.Hum.SeatPart=tbl16.Seat;tbl16.Ragdoll=true
    beginGucciConfirmation(tbl16,current,true);runFor(3)
    assert(count("Active")==0 and Hub.gucciVerifiedRun==nil)
''',
'stable_release_confirms_once_after_one_second':r'''
    beginGucciConfirmation(tbl16,current,true);runFor(0.8)
    assert(count("Active")==0 and not tbl16.Confirmed)
    runFor(0.5)
    assert(count("Active")==1 and tbl16.Confirmed and Hub.gucciVerifiedRun==tbl16)
    runFor(3);assert(count("Active")==1)
''',
'loss_of_ownership_withdraws_success_and_requires_new_stable_window':r'''
    beginGucciConfirmation(tbl16,current,true);runFor(1.4);assert(tbl16.Confirmed)
    owned=false;step();assert(not tbl16.Confirmed and Hub.gucciVerifiedRun==nil and phases[#phases]=="Retrying")
    owned=true;runFor(0.5);assert(count("Active")==1)
    owned=false;step();owned=true;runFor(0.5);assert(count("Active")==1)
    runFor(0.8);assert(count("Active")==2)
''',
'enabled_weld_missing_force_or_ragdoll_prevent_success':r'''
    tbl16.testWeld.Enabled=true
    beginGucciConfirmation(tbl16,current,true);runFor(1.5);assert(count("Active")==0)
    tbl16.testWeld.Enabled=false;local bp=tbl16.BP;tbl16.BP=nil
    runFor(1.5);assert(count("Active")==0)
    tbl16.BP=bp;tbl16.testRagdoll.Value=true
    runFor(1.5);assert(count("Active")==0)
    tbl16.testRagdoll.Value=false;runFor(1.3);assert(count("Active")==1)
''',
'cleanup_cancels_confirmation_and_cannot_announce_late_success':r'''
    beginGucciConfirmation(tbl16,current,true);runFor(0.5)
    clearGucciConfirmation(tbl16,true);runFor(3)
    assert(count("Active")==0 and Hub.gucciVerifiedRun==nil)
''',
'replacement_attempt_does_not_inherit_old_confirmation':r'''
    local old=tbl16
    beginGucciConfirmation(old,current,true);runFor(0.7)
    tbl16=record();Player.Character=tbl16.Char
    beginGucciConfirmation(tbl16,current,true);runFor(0.5)
    assert(count("Active")==0 and not old.Confirmed)
    runFor(0.8);assert(count("Active")==1 and Hub.gucciVerifiedRun==tbl16)
''',
'respawn_disable_and_invalid_predicate_cannot_complete_setup':r'''
    beginGucciConfirmation(tbl16,current,true);runFor(0.7)
    Player.Character={};runFor(1.5);assert(count("Active")==0)
    tbl16=record();Player.Character=tbl16.Char;valid=true
    beginGucciConfirmation(tbl16,current,true);runFor(0.5)
    tbl8.GucciAntiGrab=false;runFor(2);assert(count("Active")==0)
''',
'held_or_reseated_state_withdraws_active':r'''
    beginGucciConfirmation(tbl16,current,true);runFor(1.4);assert(tbl16.Confirmed)
    tbl16.Hum.SeatPart=tbl16.Seat;step();assert(not tbl16.Confirmed and not Hub.gucciVerifiedRun)
    tbl16.Hum.SeatPart=nil;isHeld.Value=true;runFor(2);assert(count("Active")==1)
''',
'confirmed_cleanup_immediately_withdraws_active':r'''
    beginGucciConfirmation(tbl16,current,true);runFor(1.4)
    assert(tbl16.Confirmed and Hub.gucciVerifiedRun==tbl16)
    clearGucciConfirmation(tbl16,true)
    assert(not tbl16.Confirmed and Hub.gucciVerifiedRun==nil and phases[#phases]=="Retrying")
    runFor(2);assert(count("Active")==1)
''',
'train_confirms_release_without_requiring_a_vehicle_force':r'''
    tbl16.Type="Train";tbl16.Root=nil;tbl16.BP=nil
    beginGucciConfirmation(tbl16,current,true);runFor(1.4)
    assert(tbl16.Confirmed and count("Active")==1)
''',
'no_weld_observation_is_not_a_success_candidate':r'''
    beginGucciConfirmation(tbl16,current,false);runFor(2)
    assert(count("Active")==0 and #workers==0)
''',
}
class GucciConfirmation(unittest.TestCase):pass

def case(body):
    def test(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        a=source.index('-- GUCCI CONFIRMATION BEGIN');b=source.index('-- GUCCI CONFIRMATION END',a)
        fixture=(ROOT/'tests/fixtures/gucci_confirmation_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'confirm.luau';path.write_text(fixture+'\n'+source[a:b]+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,body in CASES.items():setattr(GucciConfirmation,'test_'+name,case(body))
if __name__=='__main__':unittest.main()
