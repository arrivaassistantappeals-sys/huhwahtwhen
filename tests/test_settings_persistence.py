"""Exercise real save/load/restore code with a deterministic client filesystem."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

def between(source,start,end,offset=0):
    a=source.index(start,offset)
    return source[a:source.index(end,a)]

def actual_code(source):
    adapter=source.index('local Rayfield = createArrivaSidebar()')
    return '\n'.join([
        between(source,'function Hub.queueSavedCallbacks(records,invoke)','function Hub.fetch(url)'),
        between(source,'-- SETTINGS PERSISTENCE CORE','-- END SETTINGS PERSISTENCE CORE'),
        between(source,'\tlocal function copy(value)','\tfunction Library:Notify(info)',adapter),
        between(source,'\tlocal function register(id, kind, info, tab)','\tfunction Library:CreateWindow(info)',adapter),
        between(source,'\tfunction SaveManager:SetLibrary(value)','\tfunction ThemeManager:SetLibrary(value)',adapter),
    ])

CASES={
'round_trip_restores_manual_anti_lag_without_startup_delay':r'''
    newControls();Library.Toggles.AntiLagToggle:SetValue(true)
    Library.Options.StartupFeatureDelay:SetValue(9)
    Library.Options.Speed:SetValue(75);Library.Options.Mode:SetValue("B")
    Library.Options.Asset:SetValue("123");Library.Options.Key:SetValue("K")
    assert(Hub.persistSettings())
    newControls();assert(not manualOn)
    Hub.installConfigLoading(SaveManager)
    assert(SaveManager:Load("AutoSave"))
    assert(Library.Options.StartupFeatureDelay.Value==9)
    assert(Library.Options.Speed.Value==75 and Library.Options.Mode.Value=="B")
    assert(Library.Options.Asset.Value=="123" and Library.Options.Key.Value=="K")
    advance(0.01)
    assert(manualOn,"manual Anti Lag must activate before saved feature delay")
    assert(Hub.restoreProgress.done and Hub.restoreProgress.failed==0)
''',
'flush_persists_latest_change_before_debounced_save':r'''
    newControls();Hub.ready=true
    Library.Toggles.AntiLagToggle:SetValue(true)
    assert(writes==0 and Hub.saveThread)
    assert(Hub.flushSettings())
    assert(not Hub.saveThread)
    local count=writes;advance(2)
    assert(writes==count,"flush must cancel the stale scheduled save")
    local data=http:JSONDecode(files[SaveManager.folder.."/AutoSave.json"])
    local found=false
    for _,record in ipairs(data.objects) do if record.idx=="AntiLagToggle" then found=record.value end end
    assert(found)
''',
'failed_autosave_remains_dirty_and_retries_on_next_poll':r'''
    newControls();Hub.ready=true;assert(Hub.persistSettings())
    Library.Options.Speed:SetValue(90);failWrite=true
    advance(0.3);assert(Hub.lastSaveError)
    failWrite=false;Hub.pollSettings();advance(0.6)
    assert(not Hub.lastSaveError and Hub.lastSettings==Hub.captureSettings())
''',
'backup_loads_when_primary_is_corrupt':r'''
    newControls();Library.Toggles.AntiLagToggle:SetValue(true)
    assert(SaveManager:Save("AutoSave"));assert(SaveManager:Save("AutoSave"))
    files[SaveManager.folder.."/AutoSave.json"]="invalid JSON"
    newControls();assert(SaveManager:Load("AutoSave"));advance(0.01)
    assert(manualOn and Hub.lastLoadPath:sub(-4)==".bak")
''',
'unreadable_config_is_not_overwritten_by_autosave':r'''
    newControls();Hub.ready=true
    local path=SaveManager.folder.."/AutoSave.json";files[path]="broken"
    assert(not SaveManager:Load("AutoSave"));assert(Hub.configLoadFailed)
    Library.Toggles.AntiLagToggle:SetValue(true);advance(1)
    assert(files[path]=="broken" and not Hub.persistSettings())
''',
'ui_set_failure_is_reported_as_a_load_failure':r'''
    newControls()
    local content=http:JSONEncode({objects={{idx="AntiLagToggle",type="Toggle",value=true}}})
    Library.Toggles.AntiLagToggle.handle.fail=true
    local ok,err=SaveManager:LoadJSON(content)
    assert(not ok and err:find("UI rejected value",1,true))
''',
'user_changes_supersede_queued_startup_callbacks':r'''
    newControls()
    local calls={}
    local control=group:AddToggle("SlowFeature",{Default=false,Callback=function(value) table.insert(calls,value) end})
    control:SetValue(true);assert(Hub.persistSettings())
    control:SetValue(false);assert(SaveManager:Load("AutoSave"))
    control:SetValue(false);table.clear(calls);advance(5)
    assert(#calls==0 and not control.Value and Hub.restoreProgress.skipped==1)
''',
'callback_failures_are_visible_and_do_not_prevent_other_restores':r'''
    newControls()
    group:AddToggle("BrokenFeature",{Default=false,Callback=function(value) if value then error("restore failed") end end}):SetValue(true)
    assert(Hub.persistSettings());assert(SaveManager:Load("AutoSave"));advance(5)
    assert(Hub.restoreProgress.failed==1 and Hub.restoreProgress.done)
    assert(Hub.restoreProgress.errors.BrokenFeature:find("restore failed",1,true))
''',
}
class SettingsPersistence(unittest.TestCase):
    def test_force_anti_lag_round_trip_activates_real_watcher_and_restores_scripts(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        core=between(source,'do\n\t-- Anti Lag:','-- WARNING MONITOR BEGIN')
        addon=between(source,'local lagScripts={}','Hub.cleanup(function()',source.index('local lagScripts={}'))
        fixture=(ROOT/'tests/fixtures/settings_runtime.luau').read_text()
        lag_fixture=(ROOT/'tests/fixtures/anti_lag_settings_runtime.luau').read_text()
        body=r'''
            Toggles.AntiLagToggle:SetValue(true)
            assert(Hub.antiLag.on and line.Disabled and sticky.Disabled)
            assert(Hub.persistSettings())
            Toggles.AntiLagToggle:SetValue(false)
            assert(not line.Disabled and not sticky.Disabled,"both watchers must restore original script states")
            assert(SaveManager:Load("AutoSave"));advance(0.01)
            assert(Hub.antiLag.on and line.Disabled and sticky.Disabled,"restored Anti Lag must activate its actual watchers")
            local late=lineScript("CharacterAndBeamMove",false);late.Parent=scripts
            table.insert(scripts.children,late);Player.DescendantAdded:Emit(late)
            assert(late.Disabled,"late line scripts must also be disabled")
            Toggles.AntiLagToggle:SetValue(false)
            assert(not line.Disabled and not late.Disabled and not sticky.Disabled)
        '''
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'anti_lag.luau'
            path.write_text(fixture+'\n'+actual_code(source)+'\n'+lag_fixture+'\n'+core+'\n'+addon+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_all_controls_exist_before_startup_load(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        self.assertLess(source.index('MenuGroup:AddSlider("StartupFeatureDelay"'),source.index('local success,loadError=SaveManager:Load("AutoSave")'))

    def test_private_distribution_has_no_server_hop_or_remote_autoload(self):
        source=(ROOT/'dist/resonance.lua').read_text()
        removed=('queue_on_teleport','queueonteleport','hopPublicServer','choosePublicServer',
                 'PackAutoServerHop','PackAutoRejoin','PackKeepScript','PackServerSort',
                 'Rejoin + Auto Execute','Reload Hub','huhwahtwhen/codex/resonance-feature-port/dist/resonance.lua')
        for name in removed:
            self.assertNotIn(name,source)
        self.assertIn('local success,loadError=SaveManager:Load("AutoSave")',source)
        self.assertIn('Hub.connect(Player.OnTeleport',source)

    def test_distributions_match(self):
        self.assertEqual((ROOT/'dist/resonance.lua').read_bytes(),(ROOT/'dist/resonance.txt').read_bytes())

def case(body):
    def test(self):
        fixture=(ROOT/'tests/fixtures/settings_runtime.luau').read_text()
        code=actual_code((ROOT/'dist/resonance.lua').read_text())
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'settings.luau';path.write_text(fixture+'\n'+code+'\n'+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,body in CASES.items():setattr(SettingsPersistence,'test_'+name,case(body))
if __name__=='__main__':unittest.main()
