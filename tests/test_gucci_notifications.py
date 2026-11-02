"""Exercise the supplied Gucci controller's notification adapter."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class GucciNotifications(unittest.TestCase):
    def test_controller_notifications_and_retry_throttle(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        a=source.index('-- GUCCI NOTIFICATION STATES BEGIN')
        b=source.index('-- Replace the old callbacks',a)
        setup=r'''
            local now=0
            local os={clock=function() return now end}
            local Hub={alive=true,requestSave=function() end}
            local Player={Character={}}
            local tbl8={GucciAntiGrab=false}
            local tbl12={SetGucciAntiGrab=function(on) tbl8.GucciAntiGrab=on end}
            local status={SetText=function(self,text) self.text=text end}
            local emitted={}
            local function notify(title,message,duration)
                assert(title=="Gucci" and duration==4)
                table.insert(emitted,message)
            end
            local legacyUpdates=0
            Hub.updateGucciStatus=function() legacyUpdates+=1 end
        '''
        checks=r'''
            setGucci(false);assert(#emitted==0,"startup defaults must stay quiet")
            setGucci(true);assert(#emitted==1 and emitted[1]:find("starting",1,true))
            setGucci(true);assert(#emitted==1,"repeated enable must not announce a new activation")
            Hub.reportGucciStatus("Retrying");assert(#emitted==2)
            for _=1,100 do now+=0.01;Hub.reportGucciStatus("Retrying") end
            assert(#emitted==2,"retry frames must not flood notifications")
            now=10;Hub.reportGucciStatus("Retrying");assert(#emitted==3)
            Hub.reportGucciStatus("Active");assert(#emitted==4 and status.text=="Gucci: Verifying")
            Hub.gucciVerifiedRun={Confirmed=true,Char=Player.Character}
            Hub.reportGucciStatus("Active");assert(#emitted==5 and emitted[5]:find("active",1,true))
            Hub.reportGucciStatus("Active");assert(#emitted==5)
            assert(status.text=="Gucci: Active" and legacyUpdates>0)
            Hub.gucciVerifiedRun={Confirmed=true,Char={}}
            Hub.reportGucciStatus("Active");assert(status.text=="Gucci: Verifying" and #emitted==5)
            Hub.gucciStage="Waiting for respawn";Hub.updateGucciStatus()
            assert(#emitted==6 and emitted[6]:find("respawn",1,true))
            Hub.reportGucciStatus("Error","custom controller error")
            assert(emitted[7]=="custom controller error")
            setGucci(false);assert(#emitted==8 and emitted[8]=="Gucci disabled.")
            Hub.gucciStage="Waiting for respawn";Hub.updateGucciStatus();assert(#emitted==8)
            Hub.alive=false;now=30;Hub.reportGucciStatus("Retrying");assert(#emitted==8)
        '''
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'notifications.luau'
            path.write_text(setup+'\n'+source[a:b]+'\n'+checks)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_notifications_are_hooked_into_actual_controller(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        a=source.index('local function fn24()')
        b=source.index('-- Additional supplied defense behaviors',a)
        controller=source[a:b]
        self.assertEqual(controller.count('n37 = now4 + 0.15'),controller.count('beginGucciConfirmation(v27,fn25,flag14)'))
        self.assertGreater(controller.count('beginGucciConfirmation(v27,fn25,flag14)'),0)
        self.assertIn('if attempts>1 and Hub.reportGucciStatus then Hub.reportGucciStatus("Retrying") end',controller)
        self.assertIn('Hub.reportGucciStatus("Error",',controller)
        self.assertNotIn('Hub.updateGucciStatus=function() end',source)

if __name__=='__main__':unittest.main()
