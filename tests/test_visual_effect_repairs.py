"""Regression tests with parenting/property events and the game's effect hierarchy."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SETUP=r'''
local children={}
local Options=controls
local deferred={}
task.defer=function(fn) table.insert(deferred,fn) end
local function flush()
    local steps=0
    while #deferred>0 do
        steps+=1;assert(steps<100,"deferred callback loop")
        table.remove(deferred,1)()
    end
end
local function descendants(object)
    local result={}
    local function visit(parent)
        for _,child in ipairs(children[parent] or {}) do table.insert(result,child);visit(child) end
    end
    visit(object);return result
end
local function mock(name,class,parent,properties)
    local data={Name=name,ClassName=class,ChildAdded={},ChildRemoved={},DescendantAdded={},DescendantRemoving={},
        Enabled=true,Cover=0.1,Density=0.2,Transparency=0,Visible=true,ImageTransparency=0,IsPlaying=false}
    for key,value in pairs(properties or {}) do data[key]=value end
    local signals={}
    local methods={}
    local object
    function methods:IsA(kind) return kind==class or kind=="BasePart" and (class=="Part" or class=="MeshPart") end
    function methods:GetChildren() return table.clone(children[self] or {}) end
    function methods:GetDescendants() return descendants(self) end
    function methods:FindFirstChild(name) for _,c in ipairs(children[self] or {}) do if c.Name==name then return c end end end
    function methods:FindFirstChildOfClass(kind) for _,c in ipairs(children[self] or {}) do if c:IsA(kind) then return c end end end
    function methods:GetPropertyChangedSignal(key) signals[key]=signals[key] or {};return signals[key] end
    function methods:SetAttribute(key,value) data["attr_"..key]=value end
    function methods:Destroy() self.Parent=nil;data.destroyed=true end
    function methods:Stop() data.IsPlaying=false;data.stops=(data.stops or 0)+1 end
    function methods:Play() data.IsPlaying=true;data.plays=(data.plays or 0)+1 end
    object=setmetatable({}, {__index=function(_,key) return methods[key] or data[key] end,
        __newindex=function(_,key,value)
            if data[key]==value then return end
            if key=="Parent" then
                local old=data.Parent
                local branch={object};for _,c in ipairs(descendants(object)) do table.insert(branch,c) end
                local ancestor=old
                while ancestor do if ancestor.DescendantRemoving then for _,c in ipairs(branch) do emit(ancestor.DescendantRemoving,c) end end;ancestor=ancestor.Parent end
                if old then
                    local index=table.find(children[old] or {},object);if index then table.remove(children[old],index) end
                end
                data.Parent=value
                if old and old.ChildRemoved then emit(old.ChildRemoved,object) end
                if value then
                    children[value]=children[value] or {};table.insert(children[value],object)
                    if value.ChildAdded then emit(value.ChildAdded,object) end
                    ancestor=value
                    while ancestor do if ancestor.DescendantAdded then for _,c in ipairs(branch) do emit(ancestor.DescendantAdded,c) end end;ancestor=ancestor.Parent end
                end
            else data[key]=value end
            if signals[key] then emit(signals[key]) end
        end})
    object.Parent=parent
    return object
end
Workspace.ChildAdded={};Workspace.ChildRemoved={};Workspace.DescendantAdded={};Workspace.DescendantRemoving={}
Workspace.GetDescendants=descendants
Workspace.FindFirstChild=function(_,name) for _,child in ipairs(children[Workspace] or {}) do if child.Name==name then return child end end end
local terrain=mock("Terrain","Terrain",Workspace,{WaterWaveSize=0.2,WaterWaveSpeed=5,WaterTransparency=0.4,WaterReflectance=0.6})
Workspace.FindFirstChildOfClass=function(_,kind) if kind=="Terrain" then return terrain end end
local lighting=mock("Lighting","Lighting")
game.GetService=function(_,kind) assert(kind=="Lighting");return lighting end
Hub.new=function(class,parent)
    local object=mock(class,class,parent)
    table.insert(created,object);Hub.instances[object]=true
    return object
end
Hub.scanDescendants=function(root,visit,valid) for _,object in ipairs(descendants(root)) do if valid() then visit(object) end end end
local function effect()
    local model=mock("BlackHoleKick","Model",Workspace)
    local hole=mock("Hole","Part",model,{Transparency=0.25})
    local gui=mock("BillboardGui","BillboardGui",hole)
    local large=mock("Large","ImageLabel",gui,{Image="original-image",ImageColor3="black",ImageTransparency=0.2})
    local small=mock("Small","ImageLabel",gui)
    local drone=mock("Drone","Sound",hole,{SoundId="original-sound",IsPlaying=true})
    return model,hole,large,small,drone
end
'''
CASES={
'blackhole_geometry_overlay_and_playing_audio_restore':('blackhole',r'''
    local model,hole,large,small,drone=effect()
    controls.PackBlackholeImage:SetValue("https://create.roblox.com/store/asset/123/image")
    controls.PackBlackholeImageOn:SetValue(true)
    controls.PackBlackholeSound:SetValue("456");controls.PackBlackholeSoundOn:SetValue(true)
    assert(hole.Transparency==1 and not small.Visible and large.Visible and large.ImageTransparency==0)
    assert(large.Image=="rbxassetid://123" and drone.SoundId=="rbxassetid://456" and drone.IsPlaying)
    assert(drone.plays and drone.plays>=1)
    large.Image="game-overwrite";small.Visible=true;drone.SoundId="game-sound"
    assert(large.Image=="rbxassetid://123" and not small.Visible and drone.SoundId=="rbxassetid://456")
    controls.PackBlackholeImageOn:SetValue(false)
    assert(hole.Transparency==0.25 and small.Visible and large.Image=="original-image" and large.ImageColor3=="black" and large.ImageTransparency==0.2)
    assert(drone.SoundId=="rbxassetid://456")
    cleanups[#cleanups]()
    assert(drone.SoundId=="original-sound" and drone.IsPlaying)
    for connection in pairs(Hub.connections) do assert(connection.disconnected) end
'''),
'blackhole_delayed_setup_and_cancelled_deferred_callbacks':('blackhole',r'''
    controls.PackBlackholeImage:SetValue("123");controls.PackBlackholeImageOn:SetValue(true)
    controls.PackBlackholeSound:SetValue("456");controls.PackBlackholeSoundOn:SetValue(true)
    local model,hole,large,small,drone=effect()
    large.Image="initialized-after-parenting";drone.SoundId="initialized-audio"
    flush()
    assert(large.Image=="rbxassetid://123" and hole.Transparency==1 and not small.Visible and drone.SoundId=="rbxassetid://456")
    local _,second,secondImage=effect()
    controls.PackBlackholeImageOn:SetValue(false);controls.PackBlackholeSoundOn:SetValue(false)
    flush()
    assert(second.Transparency==0.25 and secondImage.Image=="original-image")
'''),
'blackhole_invalid_assets_warn_without_losing_current_selection':('blackhole',r'''
    local _,hole,large,small,drone=effect()
    controls.PackBlackholeImage:SetValue("123");controls.PackBlackholeImageOn:SetValue(true)
    controls.PackBlackholeImage:SetValue("https://example.com/image.png")
    assert(large.Image=="rbxassetid://123" and #notices>0)
    controls.PackBlackholeImage:SetValue("")
    assert(large.Image=="original-image" and small.Visible and hole.Transparency==0.25)
'''),
'clouds_reuse_disabled_map_clouds_and_restore_originals':('environment',r'''
    local existing=mock("MapClouds","Clouds",terrain,{Enabled=false,Cover=0.12,Density=0.22})
    controls.PrivateCloudCover:SetValue(0.8);controls.PrivateCloudDensity:SetValue(0.9)
    assert(existing.Cover==0.12 and existing.Density==0.22 and not existing.Enabled)
    controls.PrivateClouds:SetValue(true)
    assert(terrain:FindFirstChildOfClass("Clouds")==existing and existing.Enabled and existing.Cover==0.8 and existing.Density==0.9)
    for _,object in ipairs(created) do assert(object.ClassName~="Clouds") end
    controls.PrivateClouds:SetValue(false)
    assert(not existing.Enabled and existing.Cover==0.12 and existing.Density==0.22 and not existing.destroyed)
'''),
'cloud_creation_replacement_and_unload_do_not_leave_duplicate_clouds':('environment',r'''
    controls.PrivateClouds:SetValue(true)
    local owned=terrain:FindFirstChildOfClass("Clouds");assert(owned and owned.Enabled)
    local incoming=mock("ReplicatedClouds","Clouds",terrain,{Cover=0.11,Density=0.21,Enabled=false})
    assert(owned.destroyed and terrain:FindFirstChildOfClass("Clouds")==incoming and incoming.Enabled)
    incoming:Destroy();flush()
    local replacement=terrain:FindFirstChildOfClass("Clouds");assert(replacement and replacement~=incoming)
    cleanups[#cleanups]();flush()
    assert(replacement.destroyed and terrain:FindFirstChildOfClass("Clouds")==nil)
'''),
'late_cloud_replication_cannot_overwrite_active_controls':('environment',r'''
    controls.PrivateClouds:SetValue(true)
    local replicated=mock("ReplicatedClouds","Clouds",terrain)
    replicated.Enabled=false;replicated.Cover=0.13;replicated.Density=0.23
    assert(replicated.Enabled and replicated.Cover==0.5 and replicated.Density==0.5)
    controls.PrivateCloudCover:SetValue(0.9)
    assert(replicated.Cover==0.9)
    controls.PrivateClouds:SetValue(false)
    assert(not replicated.Enabled and replicated.Cover==0.13 and replicated.Density==0.23)
'''),
'sky_stays_parented_and_restores_existing_sky':('environment',r'''
    local original=mock("MapSky","Sky",lighting)
    controls.PrivateSkyEnabled:SetValue(true)
    local custom=lighting:FindFirstChildOfClass("Sky")
    assert(custom and custom~=original and original.Parent==nil and custom.Parent==lighting)
    controls.PrivateSkyImage:SetValue("123")
    assert(custom.SkyboxFt=="rbxassetid://123" and custom.SkyboxUp=="rbxassetid://123")
    controls.PrivateSkyEnabled:SetValue(false)
    assert(original.Parent==lighting and custom.destroyed)
'''),
'shader_and_water_settings_apply_and_cleanup':('environment',r'''
    controls.PrivateShader:SetValue(true)
    local correction=lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    local bloom=lighting:FindFirstChildOfClass("BloomEffect")
    assert(correction and bloom and correction.Parent==lighting and bloom.Parent==lighting)
    controls.PrivateSaturation:SetValue(0.8);controls.PrivateBloom:SetValue(1.2)
    assert(correction.Saturation==0.8 and bloom.Intensity==1.2)
    controls.PrivateWaterEnabled:SetValue(true);controls.PrivateWaterWaveSpeed:SetValue(25)
    assert(terrain.WaterWaveSpeed==25)
    cleanups[#cleanups]()
    assert(correction.destroyed and bloom.destroyed and terrain.WaterWaveSpeed==5 and terrain.WaterTransparency==0.4)
'''),
'water_ocean_parts_and_overlays_apply_restore_and_ignore_other_models':('environment',r'''
    local map=mock("Map","Model",Workspace)
    local objects=mock("AlwaysHereTweenedObjects","Folder",map)
    local ocean=mock("Ocean","Model",objects)
    local object=mock("Object","Model",ocean)
    local model=mock("ObjectModel","Model",object)
    local surface=mock("Surface","MeshPart",model,{Transparency=0.2,TextureID="water-texture"})
    local decal=mock("WaterDecal","Decal",surface,{Transparency=0.1})
    local appearance=mock("Appearance","SurfaceAppearance",surface)
    local invisible=mock("Collider","Part",model,{Transparency=1})
    local unrelated=mock("Building","Part",map,{Transparency=0.4})
    controls.PrivateWaterEnabled:SetValue(true)
    controls.PrivateWaterTransparency:SetValue(1)
    assert(surface.Transparency==1 and decal.Transparency==1 and surface.TextureID=="" and appearance.Parent==nil)
    assert(unrelated.Transparency==0.4 and invisible.Transparency==1)
    controls.PrivateWaterTransparency:SetValue(0.6)
    assert(surface.Transparency==0.6 and decal.Transparency==1)
    controls.PrettyHideWaterOverlay:SetValue(false)
    assert(decal.Transparency==0.6 and surface.TextureID=="water-texture" and appearance.Parent==surface)
    controls.PrivateWaterEnabled:SetValue(false);flush()
    assert(surface.Transparency==0.2 and decal.Transparency==0.1 and appearance.Parent==surface and unrelated.Transparency==0.4)
'''),
'water_new_surface_receives_current_transparency':('environment',r'''
    local map=mock("Map","Model",Workspace)
    local objects=mock("AlwaysHereTweenedObjects","Folder",map)
    local ocean=mock("Ocean","Model",objects)
    local object=mock("Object","Model",ocean)
    local model=mock("ObjectModel","Model",object)
    controls.PrivateWaterEnabled:SetValue(true);controls.PrivateWaterTransparency:SetValue(0.8)
    local surface=mock("Surface","Part",model,{Transparency=0.2})
    local overlay=mock("Overlay","ImageLabel",surface)
    flush();assert(surface.Transparency==0.8 and overlay.ImageTransparency==1)
    cleanups[#cleanups]();flush();assert(surface.Transparency==0.2 and overlay.ImageTransparency==0)
'''),
'sky_faces_stars_sun_moon_and_rotation_apply_independently':('environment',r'''
    controls.PrivateSkyEnabled:SetValue(true)
    local sky=lighting:FindFirstChildOfClass("Sky")
    controls.PrettySkyboxUp:SetValue("123");controls.PrettySkyboxDn:SetValue("456")
    controls.PrettyStarCount:SetValue(5000);controls.PrettySunSize:SetValue(30);controls.PrettyMoonSize:SetValue(20)
    controls.PrettySunImage:SetValue("789");controls.PrettyMoonImage:SetValue("987")
    controls.PrettySkyRotation2:SetValue(90)
    assert(sky.SkyboxUp=="rbxassetid://123" and sky.SkyboxDn=="rbxassetid://456" and sky.SkyboxLf=="rbxassetid://159454299")
    assert(sky.StarCount==5000 and sky.SunAngularSize==30 and sky.MoonAngularSize==20 and sky.SkyboxOrientation.Y==90)
    assert(sky.SunTextureId=="rbxassetid://789" and sky.MoonTextureId=="rbxassetid://987")
    controls.PrettySkyboxUp:SetValue("");assert(sky.SkyboxUp=="rbxassetid://159454299")
    controls.PrettyCelestialBodies:SetValue(false);assert(not sky.CelestialBodiesShown)
'''),
'shader_presets_keep_saved_values_customizable_and_optional_blur':('environment',r'''
    controls.PrivateShader:SetValue(true)
    controls.PrettyShaderPreset:SetValue("Warm Sunset")
    local correction=lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    local dof=lighting:FindFirstChildOfClass("DepthOfFieldEffect")
    local rays=lighting:FindFirstChildOfClass("SunRaysEffect")
    assert(correction.Contrast==0.1 and correction.Saturation==0.2 and controls.PrettyShaderPreset.Value=="Custom")
    assert(not dof.Enabled and not rays.Enabled)
    controls.PrettyDepthOfField:SetValue(true);controls.PrettyFarBlur:SetValue(0.3)
    controls.PrettySunRays:SetValue(true)
    assert(dof.Enabled and dof.FarIntensity==0.3 and rays.Enabled)
    controls.PrivateShader:SetValue(false);assert(dof.destroyed and rays.destroyed and correction.destroyed)
'''),
'sun_latitude_override_restores_map_setting':('environment',r'''
    lighting.GeographicLatitude=35
    controls.PrettySunLatitude:SetValue(75)
    assert(lighting.GeographicLatitude==35)
    controls.PrettyLatitudeOverride:SetValue(true);assert(lighting.GeographicLatitude==75)
    controls.PrettyLatitudeOverride:SetValue(false);assert(lighting.GeographicLatitude==35)
'''),
}
class VisualRepairs(unittest.TestCase):pass
def case(section,body):
    def test(self):
        s=(ROOT/'dist/resonance.lua').read_text()
        begin,end=('-- Feature pack: local blackhole image','-- End blackhole cosmetic feature pack') if section=='blackhole' else ('-- BEGIN LOCAL ENVIRONMENT OPTIONS','-- END LOCAL ENVIRONMENT OPTIONS')
        source=s[s.index(begin):s.index(end,s.index(begin))]
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'visual.luau';p.write_text(fixture+'\n'+SETUP+'\n'+source+'\n'+body)
            r=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(p)],capture_output=True,text=True,timeout=15)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    return test
for name,(section,body) in CASES.items():setattr(VisualRepairs,'test_'+name,case(section,body))
