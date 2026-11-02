"""Test the separate private-server kick build with mocked friend/server state."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'dist/resonance-private-kick-test.lua'
CASES={
'all_three_methods_dispatch_and_restore_after_timeout':r'''
    for _,method in ipairs({"Grab-Drop","Grab-Release","Ownership"}) do
        select(method);local before=#sent
        assert(buttons["Run selected kick test"]());runFor(3)
        local expected=method=="Grab-Drop" and dropRemote or method=="Grab-Release" and releaseRemote or ownerRemote
        local found=false
        for index=before+1,#sent do if sent[index].remote==expected then found=true end end
        assert(found,"selected method was not dispatched: "..method)
        restored()
    end
''',
'public_servers_and_unknown_server_state_send_no_actions':r'''
    select();game.PrivateServerId="";assert(not buttons["Run selected kick test"]())
    game.PrivateServerId=nil;assert(not buttons["Run selected kick test"]())
    assert(#sent==0 and #workers==0)
''',
'nonfriends_and_protected_players_are_rejected':r'''
    select();a.protected=true;assert(not buttons["Run selected kick test"]())
    a.protected=false;isFriend=false;assert(buttons["Run selected kick test"]());runFor(0.2)
    assert(#sent==0);restored()
''',
'ownership_failure_stops_without_editing_target_physics':r'''
    select("Ownership");ownership=false
    assert(buttons["Run selected kick test"]());runFor(3)
    assert(#created==0,"unconfirmed ownership must not create forces")
    assert(#sent<=7,"ownership requests must remain bounded")
    restored()
''',
'foreign_or_missing_blobman_is_not_used':r'''
    select();blob.Parent=Workspace
    assert(buttons["Run selected kick test"]());runFor(0.2)
    assert(#sent==0);restored()
    blob.Parent=ownFolder;seated=false
    assert(buttons["Run selected kick test"]());runFor(0.2)
    assert(#sent==0);restored()
''',
'stop_and_deselection_cancel_pending_work_and_restore':r'''
    select();assert(buttons["Run selected kick test"]());runFor(0.5)
    buttons["Stop kick test"]();local count=#sent;runFor(1)
    assert(#sent==count);restored()
    select("Ownership");assert(buttons["Run selected kick test"]());runFor(0.2)
    controls.PrivateKickTestTarget:SetValue(nil);count=#sent;runFor(1)
    assert(#sent==count);restored()
''',
'respawn_and_midrun_protection_cancel_test':r'''
    select("Ownership");assert(buttons["Run selected kick test"]());runFor(0.2)
    emit(Player.CharacterRemoving);local count=#sent;runFor(1)
    assert(#sent==count);restored()
    select("Ownership");assert(buttons["Run selected kick test"]());runFor(0.2)
    a.protected=true;runFor(0.2);count=#sent;runFor(1)
    assert(#sent==count);restored()
''',
'friend_lookup_cannot_apply_to_a_replacement_character':r'''
    select("Ownership");blockFriend=true
    assert(buttons["Run selected kick test"]());runFor(0.2)
    a.Character={};blockFriend=false;runFor(0.2)
    assert(#sent==0);restored()
''',
'friend_lookup_timeout_cannot_start_a_late_test':r'''
    select();blockFriend=true;assert(buttons["Run selected kick test"]());runFor(7)
    blockFriend=false;runFor(1)
    assert(#sent==0);restored()
''',
}
class PrivateKickMethods(unittest.TestCase):
    def test_entry_guard_blocks_public_unknown_and_unreadable_metadata(self):
        source=PATH.read_text();guard=source[:source.index('-- Arriva Core Hub 2.0.')]
        setup='local warnings=0;local function warn() warnings+=1 end\nlocal function gate(game)\n'
        checks=r'''
            assert(gate({PrivateServerId=""})==nil)
            assert(gate({})==nil)
            assert(gate(setmetatable({},{__index=function() error("Not available") end}))==nil)
            assert(warnings==3)
            assert(gate({PrivateServerId="verified-private"})==true)
        '''
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'guard.luau';path.write_text(setup+guard+'\nreturn true\nend\n'+checks)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_test_build_is_isolated_and_not_autostarted(self):
        source=PATH.read_text();working=(ROOT/'dist/resonance.lua').read_text()
        self.assertNotIn('-- BEGIN PRIVATE KICK TEST METHODS',working)
        self.assertIn('PrivateKickTestConfigs',source)
        self.assertNotIn('"ArrivaCoreHub/RayfieldConfigs"',source)
        self.assertNotIn('self.legacyFolder = value .. "/settings"',source)
        self.assertIn('PrivateKickTestWhitelist.json',source)
        self.assertIn('SetIgnoreIndexes({"MultiWhitelist","PrivateKickTestTarget"})',source)
        self.assertLess(source.index('Private server could not be verified'),source.index('local Hub ='))
        panel=source[source.index('-- BEGIN PRIVATE KICK TEST METHODS'):source.index('-- END PRIVATE KICK TEST METHODS')]
        self.assertNotIn('AddToggle(',panel)
        self.assertNotIn('KickServer',panel)
        self.assertIn('Default=3,Min=1,Max=10',panel)

def case(body):
    def test(self):
        source=PATH.read_text();a=source.index('-- BEGIN PRIVATE KICK TEST METHODS');b=source.index('-- END PRIVATE KICK TEST METHODS',a)
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()+'\n'+(ROOT/'tests/fixtures/private_kick_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'kick.luau';path.write_text(fixture+'\n'+source[a:b]+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,body in CASES.items():setattr(PrivateKickMethods,'test_'+name,case(body))
if __name__=='__main__':unittest.main()
