"""Check distant claims visit and return without clobbering user movement."""
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
        elseif key=="Position" then rootState.position=value
        else rawset(root,key,value) end
    end})
local signPart=node("PlusGrabPart",{},"BasePart");signPart.Position=Vector3.new(200,10,0)
local owners=node("ThisPlotsOwners")
named.Plots=node("Plots",{node("Plot3",{node("PlotSign",{owners,node("Plus",{signPart})})})})
local function step()
    local thread=workers[#workers]
    local ok,err=coroutine.resume(thread);assert(ok,err)
end
'''
CASES={
'distant_claim_requests_near_sign_then_returns_on_confirmation':r'''
    buttons["Claim selected plot"]();assert(#workers==1)
    step();assert((root.Position-signPart.Position).Magnitude<30)
    step();assert(#requests==1 and (requests[1][3].Position-signPart.Position).Magnitude<30)
    local mine=node("Owner");mine.Value=Player.Name;owners.children={mine}
    step();assert(root.Position.Magnitude==0)
''',
'cancel_auto_claim_returns_and_does_not_send_late_requests':r'''
    controls.PackAutoClaimPlot:SetValue(true);Hub.sampleToolAutomation()
    step();assert(root.Position.X==200)
    controls.PackAutoClaimPlot:SetValue(false);assert(root.Position.Magnitude==0)
    step();assert(#requests==0)
''',
'moving_away_during_claim_is_not_overwritten':r'''
    buttons["Claim selected plot"]();step()
    root.Position=Vector3.new(999,30,0)
    step();assert(root.Position.X==999 and #requests==0)
''',
'held_or_seated_characters_do_not_start_visit':r'''
    hum.SeatPart=node("Seat",{},"Seat")
    buttons["Claim selected plot"]();assert(#workers==0 and root.Position.Magnitude==0)
''',
}
class PlotClaimVisits(unittest.TestCase):pass
def case(body):
    def test(self):
        s=(ROOT/'dist/resonance.lua').read_text()
        source=s[s.index('-- plot/slot utilities:'):s.index('-- End  automation ports')]
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'claim.luau';p.write_text(fixture+'\n'+SETUP+'\n'+source+'\n'+body)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    return test
for name,body in CASES.items():setattr(PlotClaimVisits,'test_'+name,case(body))
