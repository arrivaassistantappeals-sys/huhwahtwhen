"""Exercise the active Anti Burn worker, including late and stale overlays."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
MOCKS=r'''
local action,cleanup
local function bind(id,key,interval,callback,stop) action,cleanup=callback,stop end
local function node(class,children)
 return {Parent=true,FindFirstChild=function(self,name) return self.children[name] end,
 IsA=function(self,kind) return kind==class end,children=children or {}}
end
local char={}
local root=node("BasePart");root.CFrame={}
local alive=true
local function charAlive() return char,root,{},alive end
local overlay=node("GuiObject");overlay.Visible=true
local screen=node("ScreenGui",{FireFade=overlay})
local gui=node("PlayerGui",{ScreenOverlayGui=screen})
local Player={Character=char,FindFirstChildOfClass=function() return gui end}
local Workspace=node("Workspace")
local fire=node("ParticleEmitter");fire.Enabled=true
local function burn() root.children.FireParticleEmitter=fire end
local function extinguish() root.children.FireParticleEmitter=nil end
local function addExtinguisher(areaName)
 local part=node("BasePart");part.CFrame={original=true}
 local area=node("Folder",{ExtinguishPart=part})
 Workspace.children.Map=node("Folder",{Hole=node("Folder",{[areaName]=area})})
 return part
end
'''
CASES={
 'overlay_is_hidden_without_emitter_or_map':r'''
 action();assert(not overlay.Visible)
 cleanup();assert(not overlay.Visible)
 ''',
 'missing_extinguisher_does_not_skip_visuals':r'''
 burn();action();assert(not overlay.Visible and not fire.Enabled)
 cleanup();assert(overlay.Visible and fire.Enabled)
 ''',
 'extinguishing_does_not_resurrect_stale_overlay':r'''
 burn();action();extinguish();overlay.Visible=true
 action();assert(not overlay.Visible)
 cleanup();assert(not overlay.Visible)
 ''',
 'late_and_replaced_overlays_are_hidden':r'''
 screen.children.FireFade=nil;burn();action()
 screen.children.FireFade=overlay;action();assert(not overlay.Visible)
 overlay.Parent=nil
 local replacement=node("GuiObject");replacement.Visible=true
 screen.children.FireFade=replacement;action();assert(not replacement.Visible)
 extinguish();cleanup();assert(not replacement.Visible)
 ''',
 'extinguisher_returns_home_when_fire_ends':r'''
 local part=addExtinguisher("PoisonSmallHole");local home=part.CFrame
 burn();action();assert(part.CFrame==root.CFrame)
 extinguish();action();assert(part.CFrame==home and not overlay.Visible)
 cleanup();assert(not overlay.Visible)
 ''',
 'big_hole_fallback_and_death_cleanup':r'''
 local part=addExtinguisher("PoisonBigHole");local home=part.CFrame
 burn();action();assert(part.CFrame==root.CFrame)
 alive=false;action();assert(part.CFrame==home)
 cleanup();assert(not overlay.Visible)
 ''',
 'respawn_does_not_restore_old_character_overlay':r'''
 burn();action();Player.Character={};char=Player.Character
 cleanup();assert(not overlay.Visible)
 ''',
}
class AntiBurn(unittest.TestCase): pass

def case(body):
 def test(self):
  source=(ROOT/'dist/resonance.lua').read_text()
  code=source.split('-- Anti Burn: suppress the screen effect independently',1)[1].split('-- Source manual Anti Lag',1)[0]
  with tempfile.TemporaryDirectory() as tmp:
   path=Path(tmp)/'burn.luau';path.write_text(MOCKS+'\n-- Anti Burn: suppress the screen effect independently'+code+body)
   result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
   self.assertEqual(result.returncode,0,result.stdout+result.stderr)
 return test
for name,body in CASES.items(): setattr(AntiBurn,'test_'+name,case(body))
if __name__=='__main__': unittest.main()
