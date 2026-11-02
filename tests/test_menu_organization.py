"""Exercise the production menu organizer without Roblox UI instances."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MenuOrganization(unittest.TestCase):
    def test_sections_merge_without_recreating_controls_or_changing_search_groups(self):
        source = (ROOT / 'dist/resonance.lua').read_text()
        method = source.split('        function Tab:Organize(layout)', 1)[1].split('\n\t\tfunction Tab:CreateSection', 1)[0]
        script = '''local Tab={}
local filtered=0
local UI={search={Text="query"}}
local function filter() filtered+=1 end
function Tab:Organize(layout)''' + method + '''
local function frame() return {Destroy=function(self) self.destroyed=true end} end
function Tab:CreateSection(title)
 table.insert(self.entries,{frame=frame(),name=title,section=true})
 self.section=title
end
local oldHeading=frame()
local speed={frame=frame(),group="Movement",controlId="speed",name="Speed"}
local toggle={frame=frame(),group="Movement",controlId="toggle",name="Enabled"}
local camera={frame=frame(),group="Movement",controlId="camera",name="Camera"}
local texture={frame=frame(),group="Texture",name="Texture"}
local color={frame=frame(),group="Line",name="Color"}
local unknown={frame=frame(),group="Future",name="New control"}
local tab=setmetatable({entries={{frame=oldHeading,section=true},speed,camera,texture,toggle,color,unknown}},{__index=Tab})
local layout={sections={"Movement","Camera","Line","Empty"},controls={camera="Camera"},rename={Texture="Line"},order={Movement={"toggle","speed"}}}
tab:Organize(layout)
assert(oldHeading.destroyed)
assert(toggle.frame.LayoutOrder<speed.frame.LayoutOrder)
assert(speed.frame.LayoutOrder<camera.frame.LayoutOrder)
assert(texture.frame.LayoutOrder<color.frame.LayoutOrder)
assert(color.frame.LayoutOrder<unknown.frame.LayoutOrder)
assert(camera.group=="Camera" and texture.group=="Line")
local headings={}
for _,entry in ipairs(tab.entries) do
 if entry.section then headings[entry.name]=(headings[entry.name] or 0)+1 end
end
assert(headings.Line==1 and headings.Empty==nil and headings.Future==1)
assert(#tab.entries==10 and filtered==1)
for _,entry in ipairs({speed,toggle,camera,texture,color,unknown}) do assert(not entry.frame.destroyed) end
tab:Organize(layout)
assert(#tab.entries==10 and filtered==2)
assert(toggle.frame.LayoutOrder<speed.frame.LayoutOrder)
'''
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'menu.luau'
            path.write_text(script)
            result = subprocess.run([os.environ.get('LUAU_BIN', 'luau'), str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
