"""Exercise row moves, protection grouping and search through collapsed sections."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
local UI={search={Text=""},tabs={}}
local function activate(tab) UI.active=tab end
local Tab={}
local Hub={connect=function(signal,callback) signal.callback=callback end}
local UDim2={fromScale=function() return {} end}
local function button(parent) return {Parent=parent,Activated={}} end
local function newTab(name)
    local tab=setmetatable({name=name,page={},entries={},nav={Visible=true}},{__index=Tab})
    table.insert(UI.tabs,tab);UI.active=UI.active or tab;return tab
end
local function entry(tab,id,name,group,section)
    local frame={Parent=tab.page,Visible=true,Destroy=function(self) self.destroyed=true end}
    local e={controlId=id,name=name or id,group=group,section=section,frame=frame}
    table.insert(tab.entries,e);return e
end
function Tab:CreateSection(name) entry(self,nil,name,name,true) end
'''
CASES={
'moving_preserves_existing_rows_and_handles':r'''
    local from,to=newTab("Notifications"),newTab("Sound")
    local a=entry(from,"LoopNotifySounds","Play sounds","Alerts")
    a.handle={Value=true,Callback=function() return "original" end}
    local b=entry(from,"Other","Other","Alerts")
    from:MoveEntriesTo(to,function(e) if e.controlId=="LoopNotifySounds" then return "Loop Sounds" end end)
    assert(#from.entries==1 and from.entries[1]==b and #to.entries==1 and to.entries[1]==a)
    assert(a.frame.Parent==to.page and a.group=="Loop Sounds" and a.handle.Value and a.handle.Callback()=="original")
''',
'search_finds_closed_sections_and_restores_collapse_state':r'''
    local tab=newTab("Protections")
    local grab=entry(tab,"Grab","Anti Grab","Old")
    local rainbow=entry(tab,"SourceAntiKickRainbowFill","Rainbow fill","Old")
    tab:Organize({sections={"Grab","Appearance"},controls={Grab="Grab"},prefixes={{"SourceAntiKick","Appearance"}},collapsible=true,openSection="Grab"})
    assert(grab.frame.Visible and not rainbow.frame.Visible)
    UI.search.Text="rainbow";filter()
    assert(rainbow.frame.Visible and not grab.frame.Visible and tab.nav.Visible)
    UI.search.Text="";filter();assert(not rainbow.frame.Visible and grab.frame.Visible)
    tab:SetSectionCollapsed("Appearance",false);assert(rainbow.frame.Visible)
''',
'production_layout_routes_sound_and_protections_without_losing_rows':r'''
    local Tabs={}
    for _,key in ipairs({"Player","Defense","Target","AntiLag","Blob","Aura","Grab","Fun","Visual","Misc","Whitelist","Explosions","KeyBinds","Sound","Notifications","Customization","UI Settings"}) do
        Tabs[key]={native=newTab(key)}
    end
    local force=entry(Tabs.Defense.native,"AntiLagToggle","Force Anti Lag","Defense Main")
    local low=entry(Tabs.Defense.native,"SourceLowFpsThreshold","Threshold","Extra Defense")
    local sound=entry(Tabs.Notifications.native,"LoopNotifySounds","Play sounds for loop alerts","Loop & Blobman Alerts")
    local hole=entry(Tabs.Visual.native,"PackBlackholeSound","Blackhole sound ID","Blackhole Appearance")
    local gucci=entry(Tabs.Defense.native,"SourceGucciVehicle","Gucci vehicle","Extra Defense")
    local grab=entry(Tabs.Defense.native,"AntiGrabObsidian","Anti Grab","Defense Main")
    local rainbow=entry(Tabs.Defense.native,"SourceAntiKickRainbowFill","Rainbow","Extra Defense")
    local warning=entry(Tabs.Defense.native,nil,"Movement warning count","Defense Main")
    local preview=entry(Tabs.Sound.native,nil,"Preview success sound","Notification Sounds")
    local asset=entry(Tabs.Sound.native,"NoticeSuccessAsset","Custom ID","Notification Sounds")
    local original={force,low,sound,hole,gucci,grab,rainbow,warning,preview,asset}
    __LAYOUT__
    assert(force.group=="Manual Line Protection" and force.frame.Parent==Tabs.AntiLag.native.page)
    assert(low.group=="Low FPS Protection")
    assert(sound.frame.Parent==Tabs.Sound.native.page and hole.frame.Parent==Tabs.Sound.native.page)
    assert(gucci.group=="Gucci Settings" and rainbow.group=="Anti Kick Appearance" and warning.group=="Movement Warnings")
    assert(grab.group=="Protection Toggles" and grab.frame.LayoutOrder<gucci.frame.LayoutOrder)
    assert(preview.group=="Success Notifications" and asset.group==preview.group)
    for _,e in ipairs(original) do
        local count=0
        for _,tab in pairs(Tabs) do for _,current in ipairs(tab.native.entries) do if current==e then count+=1 end end end
        assert(count==1 and not e.frame.destroyed and e.frame.Visible)
    end
''',
}
class Navigation(unittest.TestCase):pass
def case(body):
    def test(self):
        s=(ROOT/'dist/resonance.lua').read_text()
        filtering=s[s.index('local function filter()'):s.index('local function registerEntry')]
        methods=s[s.index('-- BEGIN NAVIGATION METHODS'):s.index('-- END NAVIGATION METHODS')]
        organize=s[s.index('function Tab:Organize(layout)'):s.index('function Tab:CreateSection(name)')]
        layout=s[s.index('-- Keep sidebar order fixed;'):s.index('-- Send loaded message')]
        rendered=body.replace('__LAYOUT__',layout)
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'navigation.luau';p.write_text(SETUP+'\n'+filtering+'\n'+methods+'\n'+organize+'\n'+rendered)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    return test
for name,body in CASES.items():setattr(Navigation,'test_'+name,case(body))
