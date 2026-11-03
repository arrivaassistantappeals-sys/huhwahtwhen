"""Loop status uses the UI label while retaining stable internal lifecycle keys."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class LoopDisplayNames(unittest.TestCase):
    def test_notices_use_registered_text_for_start_stop_and_unknown_controls(self):
        s=(ROOT/'dist/resonance.lua').read_text()
        self.assertIn('Text = info.Text or tostring(id)',s)
        method=s[s.index('function Hub.beginTargetLoop'):s.index('function Hub.loopTargetReady')]
        script='''local Hub={alive=true,targetLoopRuns={}}
local Toggles={LoopKickToggle2={Text="Loop Kick (grab + blob)"},DualHandLoopKick={Text="Two hand loop"}}
local Options={}
local notices={}
Hub.loopNotice=function(kind,title,message,key) table.insert(notices,{kind=kind,title=title,message=message,key=key}) end
'''+method+'''
local running=Hub.beginTargetLoop("LoopKickToggle2",true)
assert(running() and notices[1].message=="Loop Kick (grab + blob)" and notices[1].key=="LoopKickToggle2true")
Hub.beginTargetLoop("LoopKickToggle2",false)
assert(not running() and notices[2].message=="Loop Kick (grab + blob)" and notices[2].title=="Loop disabled")
Hub.beginTargetLoop("DualHandLoopKick",true);assert(notices[3].message=="Two hand loop")
Hub.beginTargetLoop("UnknownInternalID",true);assert(notices[4].message=="Selected loop")
'''
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'loop_labels.luau';p.write_text(script)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
