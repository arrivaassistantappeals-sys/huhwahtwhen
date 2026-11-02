"""Execute new feature sections from the current main-based bundle with Roblox mocks."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SECTIONS={
 'plots':('-- plot/slot utilities:','-- End  automation ports'),
 'cosmetics':('-- BEGIN PRIVATE SAFE FEATURE ADAPTER','-- END PRIVATE SAFE FEATURE ADAPTER'),
 'shape':('local function point(name,index,total,rotation)','Hub.creativeShapePoint=point'),
 'player':('-- Feature pack: standalone flight','-- End player feature pack'),
 'lines':('-- Feature pack: line textures','-- End line and object feature pack'),
 'world_esp':('-- Feature pack: sticky and blackhole overlays','-- End world overlay feature pack'),
 'groups':('-- Feature pack: reversible tools for the active own-toy group','-- End own-group feature pack'),
 'aim':('-- Feature pack: visible camera aim assistance','-- End aim feature pack'),
 'parts':('-- Feature pack: reversible local part editing','-- End part and travel feature pack'),
 'blackhole':('-- Feature pack: local blackhole image','-- End blackhole cosmetic feature pack'),
 'esp':('-- Main player ESP, including appearance controls.','-- Performance'),
}
CASES={
 'auto_claim_uses_nearby_empty_plot_and_has_a_cooldown':('plots',r'''
    local part=node("PlusGrabPart",nil,"BasePart");part.Position=root.Position
    local owners=node("ThisPlotsOwners")
    local plus=node("Plus",{part});local sign=node("PlotSign",{owners,plus})
    named.Plots=node("Plots",{node("Plot3",{sign})})
    controls.PackAutoClaimPlot:SetValue(true);Hub.sampleToolAutomation();Hub.sampleToolAutomation()
    assert(#requests==2)
    owners.children={node("Owner")};now=6;Hub.sampleToolAutomation()
    assert(#requests==2)
    owners.children={};now=12;Hub.sampleToolAutomation();assert(#requests==4)
 '''),
 'custom_crosshair_uses_the_existing_renderer_and_validates_assets':('cosmetics',r'''
    controls.PrivateCrosshair:SetValue(true)
    local image=lastCreated("ImageLabel")
    assert(not image.Visible)
    controls.PackCrosshairImage:SetValue("123")
    assert(image.Visible and image.Image=="rbxassetid://123")
    controls.PackCrosshairImage:SetValue("not an asset")
    assert(image.Image=="rbxassetid://123")
    controls.PackCrosshairImage:SetValue("");assert(not image.Visible)
 '''),
 'particle_texture_and_speed_extend_the_existing_emitter':('cosmetics',r'''
    controls.PrivateCharacterParticles:SetValue(true)
    local emitter=lastCreated("ParticleEmitter")
    assert(emitter)
    controls.PackParticleTexture:SetValue("456");controls.PackParticleMaxSpeed:SetValue(8)
    assert(emitter.Texture=="rbxassetid://456" and emitter.Speed[2]==8)
 '''),
 'new_formations_have_finite_bounded_offsets':('shape',r'''
    for _,name in ipairs({"Wings","Cape","67"}) do
        for index=1,13 do
            local offset=point(name,index,13,0.2)
            assert(offset.X==offset.X and offset.Y==offset.Y and offset.Z==offset.Z)
            assert(offset.Magnitude<2)
        end
    end
    local left,right=point("Wings",1,12,0),point("Wings",2,12,0)
    assert(left.X==-right.X)
 '''),
 'aim_visibility_check_rejects_an_obstructed_target':('aim',r'''
    assert(Hub.findAimTarget(Workspace.CurrentCamera,Vector2.new(0,0))==nil)
    hit={Instance={IsDescendantOf=function(_,target) return target==a.Character end}}
    assert(Hub.findAimTarget(Workspace.CurrentCamera,Vector2.new(0,0))==a.Character.HumanoidRootPart)
    a.protected=true
    assert(Hub.findAimTarget(Workspace.CurrentCamera,Vector2.new(0,0))==nil)
 '''),
 'flight_is_camera_relative_and_restores_humanoid':('player',r'''
    controls.PackCharacterFlight:SetValue(true);keyValues.W=true;Hub.sampleCharacterFlight()
    assert(Hub.characterFlightActive and hum.PlatformStand and not hum.AutoRotate)
    assert(created[1].Parent==root and created[1].Velocity.Z==-50)
    controls.PackCharacterFlightSpeed:SetValue(120);keyValues.D=true;Hub.sampleCharacterFlight()
    assert(math.abs(created[1].Velocity.Magnitude-120)<0.0001)
    controls.PackCharacterFlight:SetValue(false)
    assert(created[1].destroyed and created[2].destroyed and not hum.PlatformStand and hum.AutoRotate)
 '''),
 'flight_pauses_for_typing_seats_and_character_changes':('player',r'''
    controls.PackCharacterFlight:SetValue(true);keyValues.W=true;typing=true;Hub.sampleCharacterFlight()
    assert(created[1].Velocity.Magnitude==0)
    typing=false;hum.SeatPart={};Hub.sampleCharacterFlight();assert(created[1].destroyed)
    hum.SeatPart=nil;Hub.sampleCharacterFlight();assert(#created==4)
    Player.Character=nil;Hub.sampleCharacterFlight();assert(created[3].destroyed and not Hub.characterFlightActive)
 '''),
 'swimming_state_is_restored_including_originally_disabled_state':('player',r'''
    controls.PackNoSwimming:SetValue(true);assert(not humanoidStates.Swimming)
    controls.PackNoSwimming:SetValue(false);assert(humanoidStates.Swimming)
    humanoidStates.Swimming=false
    controls.PackNoSwimming:SetValue(true);controls.PackNoSwimming:SetValue(false)
    assert(not humanoidStates.Swimming)
 '''),
 'texture_only_does_not_override_other_color_controls':('lines',r'''
    local beam=node("Beam",nil,"Beam");beam.Texture="original";beam.Color="originalColor"
    named.GrabParts=node("GrabParts",{beam})
    controls.PackCustomLine:SetValue(true)
    beam.Color="anotherStyle";Hub.sampleLineStyles()
    assert(beam.Color=="anotherStyle")
    controls.PackCustomLine:SetValue(false)
    assert(beam.Texture=="original" and beam.Color=="anotherStyle")
 '''),
 'line_texture_and_gradient_restore_on_release':('lines',r'''
    local beam=node("Beam",nil,"Beam");beam.Texture="oldTexture";beam.Color="oldColor"
    local model=node("GrabParts",{beam});named.GrabParts=model
    controls.PackLineTexture:SetValue("Laser");controls.PackCustomLine:SetValue(true)
    assert(beam.Texture=="rbxassetid://8922958725")
    controls.PackGradientLine:SetValue(true)
    assert(type(beam.Color)=="table" and #beam.Color==9)
    named.GrabParts=nil;Hub.sampleLineStyles()
    assert(beam.Texture=="oldTexture" and beam.Color=="oldColor")
 '''),
 'line_gradient_server_sharing_is_optional_and_rate_limited':('lines',r'''
    controls.PackGradientLine:SetValue(true);Hub.sampleLineStyles();assert(#requests==0)
    controls.PackShareLineGradient:SetValue(true)
    Hub.sampleLineStyles();Hub.sampleLineStyles();assert(#requests==1 and #requests[1][2]==9)
    now=0.51;Hub.sampleLineStyles();assert(#requests==2)
    controls.PackShareLineGradient:SetValue(false);now=2;Hub.sampleLineStyles();assert(#requests==2)
 '''),
 'held_information_handles_no_target_and_copy_path':('lines',r'''
    controls.PackHeldInformation:SetValue(true);assert(labels[#labels].text=="Nothing held.")
    local part=node("Crate",nil,"BasePart");part.Position=Vector3.new(5,0,0)
    local grab=node("GrabPart");grab.FindFirstChildWhichIsA=function() return {Part1=part} end
    named.GrabParts=node("GrabParts",{grab});Hub.sampleHeldInformation()
    assert(labels[#labels].text:find("Crate",1,true))
    buttons["Copy held-object path"]();assert(copied=="Workspace.Crate")
 '''),
 'sticky_and_blackhole_esp_scan_stream_and_clean_up':('world_esp',r'''
    local sticky=node("StickyPart",nil,"BasePart")
    local hole=node("Hole",nil,"BasePart");local model=node("BlackHoleKick",{hole})
    scan={sticky,hole};controls.PackStickyESP:SetValue(true);controls.PackBlackholeESP:SetValue(true);Hub.sampleWorldESP()
    assert(#created==6)
    controls.PackStickyESP:SetValue(false);assert(created[1].destroyed)
    controls.PackBlackholeESP:SetValue(false);assert(created[4].destroyed)
 '''),
 'group_noclip_skips_foreign_models_and_restores_on_group_change':('groups',r'''
    local part=node("Body",nil,"BasePart");local model=node("Toy",{part},"Model");model.Parent=ownFolder
    local foreignPart=node("Body",nil,"BasePart");local foreign=node("Foreign",{foreignPart},"Model")
    local members={[model]=true,[foreign]=true};Hub.getOwnToySelection=function() return model,members end
    controls.PackGroupNoclip:SetValue(true);controls.PackGroupHighlight:SetValue(true)
    assert(not part.CanCollide and foreignPart.CanCollide and #created==1)
    members={};Hub.sampleGroupAppearance();assert(part.CanCollide and created[1].destroyed)
 '''),
 'aim_targeting_honors_protection_selection_and_fov':('aim',r'''
    controls.PackAimVisible:SetValue(false)
    local target=Hub.findAimTarget(Workspace.CurrentCamera,Vector2.new(0,0))
    assert(target==a.Character.HumanoidRootPart)
    a.protected=true
    assert(Hub.findAimTarget(Workspace.CurrentCamera,Vector2.new(0,0))==b.Character.HumanoidRootPart)
    controls.PackAimSelected:SetValue(true);chosenPlayers[c.UserId]=true
    assert(Hub.findAimTarget(Workspace.CurrentCamera,Vector2.new(0,0))==c.Character.HumanoidRootPart)
    position(c,1000);assert(Hub.findAimTarget(Workspace.CurrentCamera,Vector2.new(0,0))==nil)
 '''),
 'part_editor_restores_original_properties_and_rejects_characters':('parts',r'''
    local part=node("Crate",nil,"BasePart");part.CanTouch=false
    assert(Hub.selectWorldPart(part));buttons["Hide selected part (local)"]()
    assert(not part.CanCollide and not part.CanQuery and part.LocalTransparencyModifier==1)
    buttons["Restore selected part"]()
    assert(part.CanCollide and not part.CanTouch and part.CanQuery and part.LocalTransparencyModifier==0)
    assert(not Hub.selectWorldPart(root))
 '''),
 'smooth_teleport_is_optional_and_cancels_on_respawn':('parts',r'''
    assert(not Hub.smoothTeleport(root,{}))
    controls.PackSmoothClickTP:SetValue(true)
    local goal={};assert(Hub.smoothTeleport(root,goal))
    assert(tweenCalls[1].played and tweenCalls[1].goal.CFrame==goal)
    emit(Player.CharacterRemoving)
    assert(tweenCalls[1].cancelled)
 '''),
 'blackhole_cosmetics_restore_actual_original_assets':('blackhole',r'''
    local image=node("Large",nil,"ImageLabel");image.Image="oldImage";image.ImageColor3="oldColor"
    local sound=node("Sound",nil,"Sound");sound.SoundId="oldSound"
    local model=node("BlackHoleKick",{image,sound});scan={image,sound}
    controls.PackBlackholeImage:SetValue("123");controls.PackBlackholeImageOn:SetValue(true)
    controls.PackBlackholeSound:SetValue("rbxassetid://456");controls.PackBlackholeSoundOn:SetValue(true)
    assert(image.Image=="rbxassetid://123" and sound.SoundId=="rbxassetid://456")
    controls.PackBlackholeImageOn:SetValue(false);controls.PackBlackholeSoundOn:SetValue(false)
    assert(image.Image=="oldImage" and image.ImageColor3=="oldColor" and sound.SoundId=="oldSound")
 '''),
 'esp_controls_update_existing_entries_and_preserve_other_name_switches':('esp',r'''
    controls.NicknameESP:SetValue(true)
    local head=a.Character.HumanoidRootPart
    local gui=lastCreated("BillboardGui",head);local text=lastCreated("TextLabel",gui);local avatar=lastCreated("ImageLabel",gui)
    assert(gui and text and avatar and text.Text:find("Display A",1,true))
    controls.PackESPAvatar:SetValue(false);assert(not avatar.Visible)
    controls.PackESPFont:SetValue("Arial");controls.PackESPTextSize:SetValue(24)
    assert(text.FontFace.family:find("Arial",1,true) and text.TextSize==24)
    controls.PackESPNameplate:SetValue(false);assert(not text.Visible)
    controls.PackESPHighlight:SetValue(false)
    assert(not lastCreated("Highlight",a.Character).Enabled)
    controls.NicknameESP:SetValue(false);assert(gui.destroyed)
 '''),
}
class FeaturePack(unittest.TestCase):pass

def case(section,body):
    def test(self):
        source=(ROOT/'dist/resonance.lua').read_text();begin,end=SECTIONS[section]
        a=source.index(begin);b=source.index(end,a)
        fixture=(ROOT/'tests/fixtures/feature_pack_runtime.luau').read_text()
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'feature.luau';path.write_text(fixture+source[a:b]+body)
            result=subprocess.run([os.environ.get('LUAU_BIN','luau'),str(path)],capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    return test
for name,(section,body) in CASES.items():setattr(FeaturePack,'test_'+name,case(section,body))

