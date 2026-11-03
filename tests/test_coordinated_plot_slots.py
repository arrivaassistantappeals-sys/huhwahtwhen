"""Test current map hierarchy and distant, serialized plot/slot/house visits."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
local frames={__mul=function(a,b) return a end}
CFrame.new=function(position) return setmetatable({Position=position,Rotation={}},frames) end
local rootState={position=Vector3.zero,frame=CFrame.new(Vector3.zero)}
rawset(root,"Position",nil);rawset(root,"CFrame",nil)
setmetatable(root,{__index=function(_,key) if key=="Position" then return rootState.position elseif key=="CFrame" then return rootState.frame end end,
    __newindex=function(_,key,value)
        if key=="CFrame" then rootState.frame=value;rootState.position=value.Position
        elseif key=="Position" then rootState.position=value else rawset(root,key,value) end
    end})
local signPart=node("PlusGrabPart",{},"BasePart");signPart.Position=Vector3.new(200,10,0)
local owners=node("ThisPlotsOwners")
local house=node("House",{},"BasePart");house.Position=Vector3.new(500,10,0)
local sign=node("PlotSign",{owners,node("Sign",{node("Plus",{signPart})})})
local plot=node("Plot3",{sign,house})
named.Plots=node("Plots",{plot})
local function slot(name,x,text)
    local handle=node("Handle",{},"BasePart");handle.Position=Vector3.new(x,10,0)
    local timer=node("TimeText",{},"TextLabel");timer.Text=text
    return node(name,{node("SlotHandle",{handle}),node("Screen",{node("SlotGui",{node("TimeLeftFrame",{timer})})})}),handle,timer
end
local function step()
    local ok,err=coroutine.resume(workers[#workers]);assert(ok,err)
end
'''
CASES={
'plot_and_slot_visits_wait_for_assistance_lock':r'''
    local another={};Hub.interactionVisitLock=another
    buttons["Claim selected plot"]()
    local ready=slot("Ready",1000,"0:00");named.Slots=node("Slots",{ready})
    buttons["Spin an available slot now"]()
    assert(#workers==0 and #requests==0 and Hub.interactionVisitLock==another)
    Hub.interactionVisitLock=nil
    buttons["Claim selected plot"]();step();assert(root.Position.X==200 and Hub.interactionVisitLock)
    controls.PackAutoClaimPlot:SetValue(false)
    assert(root.Position.Magnitude==0 and not Hub.interactionVisitLock)
''',
'claim_finds_nested_sign_and_uses_anchored_marker_confirmation':r'''
    buttons["Claim selected plot"]();step();assert(root.Position.X==200)
    step();assert(#requests==1 and requests[1][2]==signPart)
    local marker=node("AnchoredPartGrab");marker.Value=Player.Name;table.insert(signPart.children,marker)
    step();assert(root.Position.Magnitude==0)
''',
'far_slot_works_without_nearby_filter_and_ignores_busy_slot':r'''
    local busy=slot("Busy",1,"0:30")
    local ready,handle,timer=slot("Ready",1000,"0:00")
    named.Slots=node("Slots",{busy,ready})
    buttons["Spin an available slot now"]();step();assert(root.Position.X==1000)
    step();assert(#requests==1 and requests[1][2]==handle)
    timer.Text="0:30";step();assert(root.Position.Magnitude==0)
''',
'cancel_auto_slot_returns_without_late_requests':r'''
    local ready=slot("Ready",1000,"0:00");named.Slots=node("Slots",{ready})
    controls.ToolAutoSpin:SetValue(true);Hub.sampleToolAutomation();step()
    assert(root.Position.X==1000)
    controls.ToolAutoSpin:SetValue(false);assert(root.Position.Magnitude==0)
    step();assert(#requests==0)
''',
'house_uses_plot_house_and_waits_for_timer_reset_before_returning':r'''
    local owner=node("Owner");owner.Value=Player.Name
    local timer=node("TimeRemainingNum");timer.Value=10;owner.children={timer};timer.Parent=owner
    owners.children={owner}
    local ready=slot("Ready",1000,"0:00");named.Slots=node("Slots",{ready})
    controls.ToolAutoSaveHouse:SetValue(true);controls.ToolAutoSpin:SetValue(true)
    Hub.sampleToolAutomation();assert(#workers==1)
    step();assert(root.Position.X==500)
    Hub.sampleToolAutomation();assert(#workers==1 and #requests==0)
    timer.Value=90;step();assert(root.Position.Magnitude==0)
''',
'moving_away_does_not_force_return_and_seated_characters_stay_put':r'''
    buttons["Claim selected plot"]();step();root.Position=Vector3.new(999,30,0)
    step();assert(root.Position.X==999 and #requests==0)
    hum.SeatPart={};buttons["Claim selected plot"]();assert(#workers==1)
''',
'claim_timeout_is_bounded_and_returns':r'''
    buttons["Claim selected plot"]();step()
    for _=1,13 do step() end
    assert(#requests==12 and coroutine.status(workers[#workers])=="dead" and root.Position.Magnitude==0)
''',
}
class CoordinatedPlotSlots(unittest.TestCase):pass
def case(body):
    def test(self):
        source=(ROOT/'docs/review/plots-slots-replacement.lua').read_text()
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'visits.luau';p.write_text(fixture+'\n'+SETUP+'\n'+source+'\n'+body)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    return test
for name,body in CASES.items():setattr(CoordinatedPlotSlots,'test_'+name,case(body))
