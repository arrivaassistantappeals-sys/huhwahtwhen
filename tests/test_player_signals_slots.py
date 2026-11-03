"""Check passive signal monitoring and independent nearby slot selection."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
for _,person in ipairs(Players.roster) do
    local r=person.Character.HumanoidRootPart
    r.FindFirstChild=function() return nil end
    r.GetConnectedParts=function() return {} end
    person.Character:FindFirstChildOfClass("Humanoid").FindFirstChild=function() return nil end
end
local originalDropdown=group.AddDropdown
function group:AddDropdown(id,info)
    local result=originalDropdown(self,id,info)
    function result:SetValues(values) self.Values=values;self.refreshes=(self.refreshes or 0)+1 end
    return result
end
local function slot(name,x,time,neon)
    local handle=node("Handle",{},"BasePart");handle.Position=Vector3.new(x,0,0)
    local light=node("LightBall",{},"BasePart");light.Material=neon and Enum.Material.Neon or "Plastic"
    local holder=node("SlotHandle",{handle,light})
    local timer=node("TimeText",{},"TextLabel");timer.Text=time
    local screen=node("Screen",{node("SlotGui",{node("TimeLeftFrame",{timer})})})
    return node(name,{holder,screen}),handle,timer
end
'''
CASES={
'combined_signals_show_multiple_observations_not_proof':('signals',r'''
    a.Character:FindFirstChildOfClass("Humanoid").SeatPart=node("Seat",{},"Seat")
    a.Character.HumanoidRootPart.GetConnectedParts=function() return {node("StickyPart",{},"BasePart")} end
    Hub.scanCheaterSignals();now=1;Hub.scanCheaterSignals()
    local record=Hub.cheaterSignals[a.UserId]
    assert(record.confirmed and record.families==2 and #notices==1)
    assert(notices[1].Description:find("not proof",1,true))
'''),
'movement_requires_repeats_and_excludes_ragdoll_and_fling':('signals',r'''
    local target=a.Character.HumanoidRootPart
    Hub.scanCheaterSignals();now=6;Hub.scanCheaterSignals()
    for i=1,3 do
        now=6+i*0.5;target.Position=Vector3.new(i*100,0,0);Hub.scanCheaterSignals()
        if i<3 then assert(not Hub.cheaterSignals[a.UserId]) end
    end
    assert(Hub.cheaterSignals[a.UserId].reason:find("movement anomaly",1,true))
    now=8;Hub.scanCheaterSignals();assert(Hub.cheaterSignals[a.UserId].confirmed)
    target.AssemblyLinearVelocity=Vector3.new(500,0,0);now=8.5;Hub.scanCheaterSignals()
    assert(not Hub.cheaterSignals[a.UserId])
'''),
'beam_source_uses_character_ancestry_never_target_attachment':('signals',r'''
    a.Character.IsA=function(_,kind) return kind=="Model" end
    a.Character.Parent=Workspace
    Players.GetPlayerFromCharacter=function(_,char) if char==a.Character then return a end end
    controls.CheaterBeamThreshold:SetValue(10)
    for i=1,10 do
        local beam=node("GrabBeam",{},"Beam");beam.Parent=Workspace;beam.Attachment1={Parent=a.Character.HumanoidRootPart}
        emit(Workspace.DescendantAdded,beam)
    end
    Hub.scanCheaterSignals();assert(not Hub.cheaterSignals[a.UserId])
    for i=1,10 do local beam=node("GrabBeam",{},"Beam");beam.Parent=a.Character;emit(Workspace.DescendantAdded,beam) end
    Hub.scanCheaterSignals();now=1;Hub.scanCheaterSignals()
    assert(Hub.cheaterSignals[a.UserId].reason:find("sender unverified",1,true))
'''),
'large_payload_stays_unattributed':('signals',r'''
    Hub.reportIncomingSignalPayload(300*1024,"SomeRemote")
    assert(next(Hub.cheaterSignals)==nil and #notices==0)
    local found=false
    for _,label in ipairs(labels) do if label.text:find("Source unknown",1,true) then found=true end end
    assert(found)
'''),
'slot_retries_use_player_origin_and_cancel_when_disabled':('slots',r'''
    local machine,handle,timer=slot("Ready",5,"0:00",true)
    named.Slots=node("Slots",{machine})
    controls.ToolAutoSpin:SetValue(true);Hub.sampleToolAutomation();assert(#requests==1)
    now=0.5;Hub.sampleToolAutomation();assert(#requests==2 and requests[2][3].Position.Y==1.593)
    controls.ToolAutoSpin:SetValue(false);now=1;Hub.sampleToolAutomation();assert(#requests==2)
'''),
'seat_signal_needs_repeat_and_notifies_once':('signals',r'''
    local ah=a.Character:FindFirstChildOfClass("Humanoid")
    local seat=node("Seat",{},"Seat");ah.SeatPart=seat
    Hub.scanCheaterSignals()
    assert(Hub.cheaterSignals[a.UserId] and not Hub.cheaterSignals[a.UserId].confirmed and #notices==0)
    now=0.6;Hub.scanCheaterSignals()
    assert(Hub.cheaterSignals[a.UserId].confirmed and #notices==1 and notices[1].Description:find(a.Name,1,true))
    local refreshes=controls.CheaterSignalPlayers.refreshes
    now=120;Hub.scanCheaterSignals();assert(#notices==1 and controls.CheaterSignalPlayers.refreshes==refreshes)
    local weld=node("SeatWeld");weld.Enabled=true;seat.children={weld};Hub.scanCheaterSignals()
    assert(not Hub.cheaterSignals[a.UserId])
'''),
'sticky_signal_excludes_self_and_cleans_departures':('signals',r'''
    local sticky=node("StickyPart",{},"BasePart")
    a.Character.HumanoidRootPart.GetConnectedParts=function() return {sticky} end
    Player.Character.HumanoidRootPart.GetConnectedParts=function() return {sticky} end
    Hub.scanCheaterSignals();now=1;Hub.scanCheaterSignals()
    assert(Hub.cheaterSignals[a.UserId].reason:find("StickyPart",1,true) and not Hub.cheaterSignals[Player.UserId])
    emit(Players.PlayerRemoving,a);assert(not Hub.cheaterSignals[a.UserId])
    cleanups[#cleanups]();assert(not Hub.cheaterSignals and not Hub.scanCheaterSignals)
'''),
'paused_or_muted_detector_does_not_notify':('signals',r'''
    local ah=a.Character:FindFirstChildOfClass("Humanoid")
    ah.SeatPart=node("Seat",{},"Seat")
    controls.CheaterSignalMonitor:SetValue(false)
    emit(RunService.Heartbeat,1);assert(next(Hub.cheaterSignals)==nil)
    controls.CheaterSignalAlerts:SetValue(false)
    Hub.scanCheaterSignals();now=1;Hub.scanCheaterSignals()
    assert(Hub.cheaterSignals[a.UserId].confirmed and #notices==0)
    a.Character=nil;Hub.scanCheaterSignals();assert(not Hub.cheaterSignals[a.UserId])
'''),
'slots_ignore_busy_machine_and_choose_ready_nearby_handle':('slots',r'''
    local busy,busyHandle=slot("Busy",1,"0:20",false)
    local ready,readyHandle=slot("Ready",5,"0:00",true)
    local far,farHandle=slot("Far",100,"0:00",true)
    named.Slots=node("Slots",{busy,ready,far})
    controls.ToolAutoSpin:SetValue(true);Hub.sampleToolAutomation()
    assert(#requests==1 and requests[1][2]==readyHandle)
    assert(requests[1][3].Position.Y==1.593 and requests[1][3].LookVector.X>0)
'''),
'slots_retry_another_handle_after_unconfirmed_spin_and_confirm_timer':('slots',r'''
    local first,h1,t1=slot("First",1,"0:00",true)
    local second,h2,t2=slot("Second",2,"0:00",true)
    named.Slots=node("Slots",{first,second})
    controls.ToolAutoSpin:SetValue(true);Hub.sampleToolAutomation();assert(requests[1][2]==h1)
    now=3;Hub.sampleToolAutomation();assert(#requests==2 and requests[2][2]==h2)
    t2.Text="0:30";now=3.5;Hub.sampleToolAutomation();assert(#requests==2)
    controls.ToolAutoSpin:SetValue(false);now=12;Hub.sampleToolAutomation();assert(#requests==2)
'''),
'slot_folder_streaming_and_unknown_timer_do_not_trigger_spins':('slots',r'''
    controls.ToolAutoSpin:SetValue(true);Hub.sampleToolAutomation();assert(#requests==0)
    local machine,handle,timer=slot("Loading",1,"",true)
    named.Slots=node("Slots",{machine});now=3;Hub.sampleToolAutomation();assert(#requests==0)
    timer.Text="0:00";now=6;Hub.sampleToolAutomation();assert(#requests==1)
'''),
}
class PlayerSignalsSlots(unittest.TestCase):pass
def case(section,body):
    def test(self):
        s=(ROOT/'dist/resonance.lua').read_text()
        begin,end=('-- BEGIN CHEATER SIGNAL MONITOR','-- END CHEATER SIGNAL MONITOR') if section=='signals' else ('-- plot/slot utilities:','-- End  automation ports')
        source=s[s.index(begin):s.index(end,s.index(begin))]
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'signals.luau';p.write_text(fixture+'\n'+SETUP+'\n'+source+'\n'+body)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    return test
for name,(section,body) in CASES.items():setattr(PlayerSignalsSlots,'test_'+name,case(section,body))
