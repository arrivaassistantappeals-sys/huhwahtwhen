"""Exercise the production dance catalog and animation-track lifecycle."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
local oldDropdown=group.AddDropdown
function group:AddDropdown(id,info)
    local control=oldDropdown(self,id,info);control.Values=info.Values;return control
end
Enum.HumanoidRigType={R6="R6",R15="R15"}
Enum.AnimationPriority={Action="Action"}
hum.RigType=Enum.HumanoidRigType.R6
local tracks={}
local denied=false
local animator={}
function animator:LoadAnimation(asset)
    if denied then error("asset denied") end
    local track={id=asset.AnimationId}
    function track:Play(fade) self.played=true;self.fade=fade end
    function track:Stop(fade) self.stopped=true end
    function track:Destroy() self.destroyed=true end
    function track:AdjustSpeed(speed) self.speed=speed end
    table.insert(tracks,track);return track
end
hum.FindFirstChildOfClass=function(_,kind) if kind=="Animator" then return animator end end
hum.WaitForChild=function(_,kind) if kind=="Animator" then return animator end end
char.WaitForChild=function(_,kind) if kind=="Humanoid" then return hum end end
Hub.requestSave=function() end
local function warn() end
'''
CASES={
'custom_presets_load_and_reject_r15':r'''
    for name,id in pairs({["Happy Dance"]="248335946",["Moon Dance 2"]="27789359"}) do
        hum.RigType=Enum.HumanoidRigType.R6
        assert(table.find(controls.PrivateAnimationPreset.Values,name))
        controls.PrivateAnimationPreset:SetValue(name)
        controls.PrivateAnimationEnabled:SetValue(true)
        local t=tracks[#tracks]
        assert(t.id=="rbxassetid://"..id and t.Looped and t.played and t.Priority=="Action")
        hum.RigType=Enum.HumanoidRigType.R15
        local count=#tracks
        controls.PrivateAnimationPreset:SetValue(name)
        assert(#tracks==count and t.stopped and t.destroyed)
        assert(notices[#notices].Title=="R6 character required")
        controls.PrivateAnimationEnabled:SetValue(false)
    end
''',
'all_nine_classic_variants_load_with_r6_loop_and_action_priority':r'''
    local expected={
        ["R6 Dance 1"]="182435998",["R6 Dance 1 (Alt 1)"]="182491037",["R6 Dance 1 (Alt 2)"]="182491065",
        ["R6 Dance 2"]="182436842",["R6 Dance 2 (Alt 1)"]="182491248",["R6 Dance 2 (Alt 2)"]="182491277",
        ["R6 Dance 3"]="182436935",["R6 Dance 3 (Alt 1)"]="182491368",["R6 Dance 3 (Alt 2)"]="182491423",
    }
    for name,id in pairs(expected) do
        assert(table.find(controls.PrivateAnimationPreset.Values,name))
        controls.PrivateAnimationPreset:SetValue(name)
        controls.PrivateAnimationEnabled:SetValue(true)
        local t=tracks[#tracks]
        assert(t.id=="rbxassetid://"..id and t.Looped and t.played and t.Priority=="Action")
        controls.PrivateAnimationEnabled:SetValue(false)
        assert(t.stopped and t.destroyed)
    end
''',
'r15_cannot_load_an_r6_dance':r'''
    hum.RigType=Enum.HumanoidRigType.R15
    controls.PrivateAnimationPreset:SetValue("R6 Dance 1")
    controls.PrivateAnimationEnabled:SetValue(true)
    assert(#tracks==0 and #created==0 and notices[#notices].Title=="R6 character required")
''',
'legacy_presets_and_default_selection_stay_available':r'''
    assert(controls.PrivateAnimationPreset.Value=="Arm Detach")
    for _,name in ipairs({"Spin Dance","Spin Dance 2","Moving Dance","Moon Dance","Struggle"}) do assert(table.find(controls.PrivateAnimationPreset.Values,name)) end
    controls.PrivateAnimationPreset:SetValue("Moon Dance")
    controls.PrivateAnimationEnabled:SetValue(true)
    assert(tracks[#tracks].id=="rbxassetid://45834924")
''',
'speed_control_and_selection_change_manage_only_our_track':r'''
    controls.PrivateAnimationPreset:SetValue("R6 Dance 2")
    controls.PrivateAnimationEnabled:SetValue(true)
    local first=tracks[#tracks]
    controls.PrivateAnimationSpeed:SetValue(2.5);assert(first.speed==2.5)
    controls.PrivateAnimationPreset:SetValue("R6 Dance 3")
    assert(first.stopped and first.destroyed and tracks[#tracks].speed==2.5)
    controls.PrivateAnimationSpeed:SetValue(0);assert(tracks[#tracks].speed==0)
''',
'respawn_stops_old_track_and_resumes_current_choice_when_ready':r'''
    controls.PrivateAnimationPreset:SetValue("R6 Dance 3 (Alt 2)")
    controls.PrivateAnimationEnabled:SetValue(true)
    local first=tracks[#tracks]
    emit(Player.CharacterRemoving,char);assert(first.stopped and first.destroyed)
    emit(Player.CharacterAdded,char);resume(#workers)
    assert(#tracks==2 and tracks[2].id=="rbxassetid://182491423")
''',
'failed_animation_load_and_unload_release_created_assets':r'''
    denied=true
    controls.PrivateAnimationPreset:SetValue("R6 Dance 1")
    controls.PrivateAnimationEnabled:SetValue(true)
    assert(#tracks==0 and created[#created].destroyed and notices[#notices].Title=="Animation unavailable")
    denied=false;controls.PrivateAnimationEnabled:SetValue(true)
    local t=tracks[#tracks]
    cleanups[#cleanups]()
    assert(t.stopped and t.destroyed and created[#created].destroyed)
''',
}
class R6Dances(unittest.TestCase):pass

def case(body):
    def test(self):
        source=(ROOT/'dist/resonance.lua').read_text();a=source.index('-- BEGIN LOCAL ANIMATION OPTIONS');b=source.index('-- END LOCAL ANIMATION OPTIONS',a)
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'dance.luau';path.write_text(fixture+'\n'+SETUP+'\n'+source[a:b]+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,body in CASES.items():setattr(R6Dances,'test_'+name,case(body))
if __name__=='__main__':unittest.main()
