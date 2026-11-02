"""Check camera fade restoration and per-category notification sound routing."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
Tabs.Notifications=Tabs.Misc
local originalDropdown=group.AddDropdown
function group:AddDropdown(id,info)
    if type(info.Default)=="string" then info.Default=table.find(info.Values,info.Default) end
    return originalDropdown(self,id,info)
end
local soundService={}
game.GetService=function(_,name) assert(name=="SoundService");return soundService end
local oldNew=Hub.new
Hub.new=function(class,parent)
    local object=oldNew(class,parent)
    if class=="Sound" then
        function object:Play() self.played=(self.played or 0)+1 end
        function object:Stop() self.stopped=true end
    end
    return object
end
Enum.DevCameraOcclusionMode={Invisicam="Invisicam"}
Enum.RenderPriority={Camera={Value=200}}
Player.DevCameraOcclusionMode="Zoom"
local bound={}
RunService.BindToRenderStep=function(_,name,priority,callback) bound[name]=callback end
RunService.UnbindFromRenderStep=function(_,name) bound[name]=nil end
local OverlapParams={new=function() return {} end}
local obstructed,inside={},{}
Workspace.CurrentCamera={Focus={Position={}},CFrame={}}
Workspace.CurrentCamera.GetPartsObscuringTarget=function() return obstructed end
Workspace.GetPartBoundsInBox=function() return inside end
local function part(base,modifier)
    local p=node("Wall",{},"BasePart");p.Transparency=base;p.LocalTransparencyModifier=modifier
    p.IsDescendantOf=function() return false end
    return p
end
local function frame()
    if bound.ArrivaCameraClipRestore then bound.ArrivaCameraClipRestore() end
    if bound.ArrivaCameraClipFade then bound.ArrivaCameraClipFade() end
end
local UI={}
local colors={card="card",noticeText="text"}
Color3.fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end
local UDim={new=function(_,value) return value end}
'''
CASES={
'style':r'''
    local border=node("Border",{},"UIStroke")
    local corner=node("Corner",{},"UICorner")
    local heading=node("NotificationHeading",{},"TextLabel")
    local icon=node("NotificationIcon",{},"ImageLabel")
    local body=node("NotificationBody",{},"TextLabel");body.Text='<font color="#FF737D">Player</font>'
    local f=node("Notice",{border,corner,heading,icon,body})
    local attributes={NoticeKind="danger",NoticeAccentHex="#FF737D"}
    f.GetAttribute=function(_,key) return attributes[key] end
    f.SetAttribute=function(_,key,value) attributes[key]=value end
    f.GetDescendants=function(self) return self.children end
    UI:RefreshNoticeStyle(f)
    assert(border.Color==heading.TextColor3 and border.Color==icon.ImageColor3)
    assert(border.Thickness==1.2 and f.BackgroundTransparency==0 and corner.CornerRadius==10)
    UI.noticeColor_danger=Color3.fromRGB(0,255,0)
    UI.noticeBorderThickness=3;UI.noticeCornerRadius=20;UI.noticeBackgroundTransparency=0.5
    UI:RefreshNoticeStyle(f)
    assert(border.Color==UI.noticeColor_danger and heading.TextColor3==border.Color)
    assert(body.Text:find("#00FF00",1,true) and border.Thickness==3 and corner.CornerRadius==20 and f.BackgroundTransparency==0.5)
''',
'camera':r'''
    local wall=part(0,0.1)
    controls.CameraClipFade:SetValue(true)
    assert(Player.DevCameraOcclusionMode=="Invisicam")
    obstructed={wall};frame();assert(wall.LocalTransparencyModifier==0.6)
    obstructed={};frame();assert(wall.LocalTransparencyModifier==0.1)
    inside={wall};frame();assert(wall.LocalTransparencyModifier==0.6)
    controls.CameraClipFade:SetValue(false)
    assert(wall.LocalTransparencyModifier==0.1 and Player.DevCameraOcclusionMode=="Zoom" and next(bound)==nil)
''',
'camera_partial_transparency_and_unload':r'''
    local wall=part(0.5,0);local glass=part(0.8,0)
    obstructed={wall,glass};controls.CameraClipFade:SetValue(true);frame()
    assert(math.abs(1-(1-wall.Transparency)*(1-wall.LocalTransparencyModifier)-0.6)<0.00001)
    assert(glass.LocalTransparencyModifier==0)
    emit(Player.CharacterRemoving);assert(wall.LocalTransparencyModifier==0)
    frame();cleanups[#cleanups]();assert(wall.LocalTransparencyModifier==0 and next(bound)==nil)
''',
'sound':r'''
    assert(Hub.notificationKind({Title="Gucci",Description="Gucci active.",Type="warning"})=="warning")
    assert(Hub.notificationKind({Title="Gucci",Description="Retrying"})=="warning")
    assert(Hub.notificationKind({Title="Failed to load"})=="danger")
    assert(Hub.notificationKind({Title="Settings saved"})=="success")
    assert(Hub.notificationKind({Title="Player joined"})=="success")
    for _,kind in ipairs({"info","warning","success","danger"}) do Hub.playNotificationSound({Type=kind}) end
    assert(#created==4 and created[1].SoundId~=created[2].SoundId and created[2].SoundId~=created[3].SoundId)
    Hub.playNotificationSound({Type="info"});assert(created[1].played==1)
    controls.NoticeInfoAsset:SetValue("rbxassetid://123456")
    controls.NoticeInfoSound:SetValue("Custom")
    controls.NoticeInfoVolume:SetValue(0.7)
    buttons["Preview info sound"]()
    assert(created[1].SoundId=="rbxassetid://123456" and created[1].Volume==0.7)
    controls.NoticeInfoSound:SetValue("Off");buttons["Preview info sound"]();assert(created[1].played==2)
    controls.NotificationSoundsEnabled:SetValue(false)
    now=2;Hub.playNotificationSound({Type="success"});assert(created[3].played==1)
    cleanups[#cleanups]()
    for _,voice in ipairs(created) do assert(voice.destroyed and not Hub.instances[voice]) end
    assert(not Hub.playNotificationSound)
''',
}
class CameraNotifications(unittest.TestCase):
    def test_controls_register_before_saved_settings_load(self):
        s=(ROOT/'dist/resonance.lua').read_text()
        self.assertLess(s.index('-- END NOTIFICATION SOUND LIBRARY'),s.index('SaveManager:Load("AutoSave")'))

def case(section,body):
    def test(self):
        s=(ROOT/'dist/resonance.lua').read_text()
        marker='NOTICE STYLE' if section=='style' else 'CAMERA CLIP FADE' if section.startswith('camera') else 'NOTIFICATION SOUND LIBRARY'
        source=s[s.index('-- BEGIN '+marker):s.index('-- END '+marker)]
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'test.luau';p.write_text(fixture+'\n'+SETUP+'\n'+source+'\n'+body)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    return test
for name,body in CASES.items():setattr(CameraNotifications,'test_'+name,case(name,body))
