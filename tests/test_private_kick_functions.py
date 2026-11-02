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
    Hub.selectedTargets={[a.UserId]=a}
    Hub.isSelectedTarget=function(person) return person and Hub.selectedTargets[person.UserId]==person end
    local friendChecks=0
    local oldFriendCheck=Player.IsFriendsWithAsync
    Player.IsFriendsWithAsync=function(...) friendChecks+=1;return oldFriendCheck(...) end
    local function choose(method)
        controls.PrivateKickMethod:SetValue(method or "Grab-Drop")
        Hub.selectedTargets={[a.UserId]=a}
    end
'''
CASES={
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
