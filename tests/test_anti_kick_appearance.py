"""Drive the real Anti Kick appearance updater without advancing its ownership worker."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
local tbl7={AntiKickSettings={Highlight=false,HighlightFill=Color3.new(1,0,0),HighlightOutl=Color3.new(1,1,1),HighlightFT=0.5,HighlightOT=0,Transparency=0.9},CharacterHighlightAffects={}}
local tbl8={AntiKick=true,ForcefieldChar=false}
local tbl12={}
local settings=group
local updateAntiKickAppearance
local function shuriken()
    local part=node("Part",nil,"BasePart");part.Transparency=0.9
    local model=node("ShurikenRSC",{part},"Model");model.Parent=ownFolder
    return model,part
end
local v18,shurPart=shuriken()
local new=Hub.new
Hub.new=function(kind,parent)
    local object=new(kind,parent)
    object.IsA=function(_,class) return class==kind end
    if parent and parent.children then table.insert(parent.children,object) end
    local destroy=object.Destroy
    object.Destroy=function(self)
        local parent=self.Parent
        if parent and parent.children then
            local index=table.find(parent.children,self);if index then table.remove(parent.children,index) end
        end
        destroy(self)
    end
    return object
end
local saves=0
Hub.requestSave=function() saves+=1 end
local function tick(seconds) now+=seconds or 0.1;emit(RunService.Heartbeat,seconds or 0.1) end
local function currentHighlight() return v18 and v18:FindFirstChild("ShurHighlight") end
'''
CASES={
'rainbow_updates_the_actual_highlight_while_worker_is_idle':r'''
    controls.SourceAntiKickRainbowFill:SetValue(true)
    controls.SourceAntiKickRainbowOutline:SetValue(true)
    local h=currentHighlight();assert(h and h.Enabled)
    local firstFill,firstOutline=h.FillColor,h.OutlineColor
    tick(1)
    assert(h.FillColor~=firstFill and h.OutlineColor~=firstOutline)
    assert(h.FillColor==tbl7.AntiKickSettings.HighlightFill and h.OutlineColor==tbl7.AntiKickSettings.HighlightOutl)
    assert(#created==1,"must not create another Highlight every frame")
''',
'rainbow_is_visible_without_changing_manual_highlight_preference':r'''
    assert(not controls.SourceAntiKickHighlight.Value)
    controls.SourceAntiKickRainbowFill:SetValue(true)
    assert(currentHighlight().Enabled and shurPart.Transparency==0)
    assert(not controls.SourceAntiKickHighlight.Value)
    controls.SourceAntiKickRainbowFill:SetValue(false)
    assert(not currentHighlight().Enabled and shurPart.Transparency==0.9)
''',
'disabling_rainbow_restores_the_latest_static_color':r'''
    controls.SourceAntiKickHighlight:SetValue(true)
    controls.SourceAntiKickRainbowFill:SetValue(true)
    controls.SourceAntiKickFillColor:SetValue("123456")
    tick(0.4)
    controls.SourceAntiKickRainbowFill:SetValue(false)
    local h=currentHighlight()
    assert(h.Enabled and h.FillColor[1]==0x12 and h.FillColor[2]==0x34 and h.FillColor[3]==0x56)
    local color=h.FillColor;tick(1);assert(h.FillColor==color)
''',
'fill_and_outline_channels_are_independent':r'''
    controls.SourceAntiKickOutlineColor:SetValue("ABCDEF")
    controls.SourceAntiKickRainbowFill:SetValue(true)
    local outline=currentHighlight().OutlineColor
    tick(1)
    assert(currentHighlight().OutlineColor==outline and outline[1]==0xAB)
    controls.SourceAntiKickRainbowOutline:SetValue(true);tick(0.5)
    assert(currentHighlight().OutlineColor~=outline)
    controls.SourceAntiKickRainbowOutline:SetValue(false)
    assert(currentHighlight().OutlineColor[1]==0xAB)
''',
'new_and_replaced_shurikens_pick_up_saved_rainbow_choices':r'''
    local before=#created
    v18=nil
    controls.SourceAntiKickRainbowFill:SetValue(true);tick(0.2)
    assert(#created==before)
    v18,shurPart=shuriken();tick(0.1)
    local old=currentHighlight();assert(old and old.Enabled)
    v18,shurPart=shuriken();tick(0.1)
    assert(not old.Enabled and currentHighlight().Enabled and #created==before+2)
    v18=nil;tick(0.1)
    for _,object in ipairs(created) do assert(not object.Enabled) end
''',
'late_highlight_replacement_gets_current_style':r'''
    controls.SourceAntiKickRainbowOutline:SetValue(true)
    local h=currentHighlight();h:Destroy()
    local replacement=node("ShurHighlight",nil,"Highlight");replacement.Parent=v18
    table.insert(v18.children,replacement)
    tick(0.3)
    assert(currentHighlight()==replacement and replacement.Enabled and replacement.OutlineColor==tbl7.AntiKickSettings.HighlightOutl)
''',
'alpha_and_manual_color_controls_update_without_waiting_for_worker':r'''
    controls.SourceAntiKickHighlight:SetValue(true)
    controls.SourceAntiKickFillAlpha:SetValue(0.25)
    controls.SourceAntiKickOutlineAlpha:SetValue(0.75)
    controls.SourceAntiKickFillColor:SetValue("00FF00")
    local h=currentHighlight()
    assert(h.FillTransparency==0.25 and h.OutlineTransparency==0.75 and h.FillColor[2]==255)
''',
'animation_does_not_request_saves_each_frame_and_stops_on_cleanup':r'''
    controls.SourceAntiKickRainbowFill:SetValue(true)
    local count=saves;tick(1);tick(1);assert(saves==count)
    local h=currentHighlight();cleanups[#cleanups]();assert(not h.Enabled)
    local color=h.FillColor;tick(1);assert(h.FillColor==color)
''',
'disabled_anti_kick_does_not_spawn_or_display_a_highlight':r'''
    local before=#created
    tbl8.AntiKick=false;controls.SourceAntiKickRainbowFill:SetValue(true);tick(1)
    assert(#created==before)
    tbl8.AntiKick=true;tick(0.1);local h=currentHighlight();assert(h.Enabled)
    tbl8.AntiKick=false;tick(0.1);assert(not h.Enabled)
''',
}
class AntiKickAppearance(unittest.TestCase):
    def test_worker_paths_share_the_appearance_updater(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        a=source.index('local function sourceAntiKickWorker()');b=source.index('antiKickStart=sourceAntiKickWorker',a)
        worker=source[a:b]
        self.assertEqual(worker.count('if updateAntiKickAppearance then updateAntiKickAppearance() end'),4)
        self.assertNotIn('shurHighlight.FillColor =',worker)

def case(body):
    def test(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        a=source.index('-- ANTI KICK APPEARANCE BEGIN');b=source.index('-- ANTI KICK APPEARANCE END',a)
        c=source.index('settings:AddToggle("SourceAntiKickHighlight"')
        d=source.index('Hub.cleanup(function() tbl8.AntiKick=false',c)
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'appearance.luau';path.write_text(fixture+'\n'+SETUP+'\n'+source[c:d]+'\n'+source[a:b]+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,body in CASES.items():setattr(AntiKickAppearance,'test_'+name,case(body))
if __name__=='__main__':unittest.main()
