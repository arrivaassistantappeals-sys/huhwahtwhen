# Supplied Resonance feature comparison

Private distribution: load the script manually. The hub no longer downloads itself, queues execution after teleport, fetches server lists or offers server-hop/auto-rejoin controls. Historical comparison entries below describe the earlier import.

Base: main commit `980549990efb367e93740e7c41a4aecf9cadb2eb` (2 November 2026). The upload contains eight embedded source modules; its Main section has 365 literal UI-control construction sites. These are controls, not 365 distinct features. Dynamically generated method menus and option values require additional runtime context.

The uploaded Intro/Library/ThemeManager/SaveManager/Bootstrap are not executed or substituted into the existing hub. Its paid-access/crack wrapper and global remote hooks are not imported. Existing user modifications, current missile/cache implementation, tab order, icon table and previous feature removals are preserved.

## Added / extended

- Standalone Flight (H), movement speed and lifecycle restoration; non-swimmable water. Existing blur suppression is reused.
- Player ESP nameplate/avatar/highlight switches, font family/size/height, draw distance, text/outline colors and rainbow options.
- Sticky and Blackhole world ESP with streamed-in discovery, label/color/range/depth/transparency controls.
- All twelve supplied grab-line textures, nine-stop gradient defaults and editable colors, optional server gradient sharing (2 Hz maximum), and object name/distance/mass/owner information.
- Current own-toy-group noclip and highlighting, restoring per-part values when selection changes.
- Server browser, server-hop, auto-rejoin, teleport auto-execute and remote Reload Hub were removed for the private distribution. Local settings saving and restoration remain available.
- Visible camera Aim Assist, right-mouse/always activation, protected/selected/visible-target filters, aim part, FOV circle/radius and smoothing. No silent-aim hook or protection bypass.
- Reversible local part selection, decollision/hiding/highlight/path copy and optional cancellable smooth click teleport using existing validated landing checks.
- Existing crosshair gains custom image assets and size up to 128; existing particle emitter gains texture/max-speed controls; existing audio filter gains explosion muting.
- Reversible local blackhole image/tint/sound customization using Roblox asset IDs.
- Wings, Cape and the supplied 67-point pattern integrated into existing object formations.
- Nearby empty-plot auto claim, limited to one attempt per five seconds and paused for conflicting character actions.

There are 69 new saved option IDs, including the generated gradient-color fields, plus new buttons. New active effects default off; existing ESP defaults remain enabled only when the existing ESP master is enabled. Stop all action loops also stops the new flight, aim, auto-hop and auto-claim modes.

## Important limits / remaining work

This is not a complete transplant of every unmatched control. Intentional network/server flooders and crash controls are excluded. Previously removed poison/ragdoll/banana/radioactive/Ultra/player-grab controls are not restored. Global namecall hooks, paid-perk spoofing, limb deletion, shared map destruction, datacenter discovery, arbitrary MP3 downloading, target-pose tooling and original-runtime-specific methods are not ported. Cosmetic body forms outside Wings/Cape/67 are not imported. Features marked Not ported below remain unavailable in this branch; an existing-label match is not a claim of exact implementation parity.

Physics and remote acceptance still depend on the live game. Overlay/asset rendering, server HTTP access and teleport APIs need in-game validation. Server sorting uses fields returned by the public API only. Queue-on-teleport support is executor-dependent. Local part/image/audio edits do not claim server replication or deletion. Shared gradients intentionally alter the game setting; its previous server value is not known/restored.

## Validation

23 new self-contained Lua/Roblox mock regressions pass. The full 15K-line bundle compiles with Luau and git diff whitespace checks pass. A clean checkout can run these tests without the older local harness:

```sh
LUAU_BIN=/path/to/luau python3 -m unittest discover -s tests -p test_feature_pack.py
luau-compile --null dist/resonance.lua
```

The older untracked local test harness had 11 failures/errors against unmodified main (nine obsolete missile tests plus stale keybind/layout assumptions). Its exact URL-count assertion also becomes stale with the new optional teleport loader. Those files are not treated as validation of this main revision and their mismatches are not fixed by overwriting the user's newer missile code. No live Roblox gameplay was executed.

## Every literal uploaded control site

Line numbers below are relative to the extracted `sources.Main` section. Generic/dynamically generated labels can represent multiple runtime controls.

| Main line | Kind | Uploaded ID | Label | Disposition | Destination / limitation |
| --- | --- | --- | --- | --- | --- |
| 14260 | KeyPicker | `` | Add To List | Not ported | No verified compatible implementation added; see limitations below. |
| 14463 | Toggle | `` | Loop Apply Method  | Not ported | No verified compatible implementation added; see limitations below. |
| 14519 | Button | `` | Apply Method  | Not ported | No verified compatible implementation added; see limitations below. |
| 18051 | Button | `` | Unload Script | Existing | Existing emergency unload and settings action. |
| 18059 | Button | `` | Rejoin | Existing/extended | Existing rejoin retained; colocated configurable rejoin added to Servers. |
| 18067 | Button | `` | Server-hop | Ported | World & Travel / Servers. |
| 18081 | Toggle | `AutoRj` | Auto Rejoin | Ported | PackAutoRejoin: Disconnect-message rejoin, opt-in and throttled. |
| 18089 | Toggle | `RejoinWithAntiLag` | Join with Anti-Lag | Not ported | Retained anti-lag settings load normally; no extra pre-join injector. |
| 18098 | Toggle | `RejoinWithScript` | Join with script | Ported | PackKeepScript: Queue-on-teleport support required. |
| 18119 | Dropdown | `ServerHopRegion` | Preferred Region | Not ported | Public server data does not reliably provide datacenter/continent metadata; no misleading region selector. |
| 18131 | Dropdown | `ServerHopSort` | Selection | Ported | PackServerSort: Public API sort modes: population/FPS/ping/random. |
| 18147 | Slider | `ServerHopMinPlayers` | Minimum Players | Ported | PackServerMinimum: Minimum population filter. |
| 18159 | Slider | `ServerHopMaxPlayers` | Maximum Players | Ported | PackServerMaximum: Maximum population filter. |
| 18173 | Slider | `AutoServerHopTime` | Server-hop after | Ported | PackServerHopDelay: 30–3600-second bounded interval. |
| 18190 | Toggle | `AutoServerHop` | Auto Server-Hop | Ported | PackAutoServerHop: Opt-in scheduled server hop. |
| 18203 | Slider | `WalkspeedS` | Walk Speed | Existing/partial | Existing movement speed modifier. |
| 18213 | Slider | `JumpPowerS` | Jump Power | Existing/partial | Existing jump modifier. |
| 18223 | Slider | `FlightSpeedS` | Flight Speed | Ported | PackCharacterFlightSpeed: Standalone flight speed. |
| 18233 | Slider | `SpinS` | Spin Speed | Existing/partial | Existing spin-speed control. |
| 18247 | Toggle | `FlyT` | Flight | Ported | PackCharacterFlight: Standalone camera-relative flight, separate from Blob Fly. |
| 18258 | KeyPicker | `FlightKey` | Flight | Not ported | No verified compatible implementation added; see limitations below. |
| 18260 | Toggle | `WalkspeedT` | Walkspeed | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18275 | KeyPicker | `WSKey` | Walkspeed | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18277 | Toggle | `JumpPowerT` | Jump Power | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18284 | KeyPicker | `JPKey` | Jump Power | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18286 | Toggle | `SpinT` | Character Spin | Existing/partial | Existing character spin. |
| 18317 | KeyPicker | `CSKey` | Character Spin | Not ported | No verified compatible implementation added; see limitations below. |
| 18321 | Toggle | `NoclipT` | Noclip | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18336 | KeyPicker | `NCKey` | Noclip | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18338 | Toggle | `InfJumpT` | Inf Jump | Existing/partial | Existing Infinite Jump. |
| 18344 | KeyPicker | `IJKey` | Inf Jump | Not ported | No verified compatible implementation added; see limitations below. |
| 18346 | Toggle | `JerkOffT` | Jerk Off | Not ported | No verified compatible implementation added; see limitations below. |
| 18384 | KeyPicker | `JerkOffK` | Jerk Off | Not ported | No verified compatible implementation added; see limitations below. |
| 18388 | Toggle | `DesyncT` | Position Desync | Not ported | Previously supplied desync tooling already exists; no new replication-spoofing implementation imported. |
| 18396 | KeyPicker | `DesyncKey` | Position Desync | Not ported | No verified compatible implementation added; see limitations below. |
| 18410 | Dropdown | `TeleportToDropdown` | Location | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18420 | Toggle | `MakeSpawnLoc` | Make Spawn Location | Existing/partial | Existing saved safe-zone destination and spawn-at-safe-zone toggle. |
| 18448 | Toggle | `LoopTPToLoc` | Loop TP to Location | Existing/partial | Existing loop-go-to-safe-zone. |
| 18471 | Toggle | `LoopSpectatePlayer` | Spectate Player | Existing/partial | Existing camera-only spectator. |
| 18494 | KeyPicker | `SpectateKey` | Spectate Player | Not ported | No verified compatible implementation added; see limitations below. |
| 18496 | Toggle | `LoopTPToPlayer` | Loop TP to Player | Existing/partial | Existing follow-selected-player positioning. |
| 18516 | Dropdown | `LookFigure` | Figure | Not ported | No verified compatible implementation added; see limitations below. |
| 18530 | Toggle | `LookFigures` | Enabled | Not ported | No verified compatible implementation added; see limitations below. |
| 18532 | Toggle | `LookFiguresPreview` | Show Locally | Not ported | No verified compatible implementation added; see limitations below. |
| 18588 | Dropdown | `AnimationToPlay` | Animation to Play | Existing/partial | Existing animation selector. |
| 18596 | Slider | `AnimS` | Animation Speed | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18644 | Toggle | `AnimationToggle` | Toggle Animation | Existing/partial | Existing play-animation toggle. |
| 18684 | Slider | `ExtSpeedSlider` | Extend speed | Existing/partial | Existing Extend Amount. |
| 18696 | Toggle | `ExtLineToggle` | Toggle Extend Line | Existing/partial | Existing Further Extend. |
| 18706 | Slider | `SupStrengthSlider` | Strength | Existing label match | Same visible control label exists in main; behavior may differ. |
| 18718 | Toggle | `SupStrength` | Super Strength | Existing/partial | Existing grab throw-strength modifier. |
| 18731 | Toggle | `LineLagToggle` | Line-Lag Server | Excluded | Intentional flood/crash functionality is excluded. |
| 18743 | KeyPicker | `LineLagKey` | Line-Lag Server | Excluded | Intentional flood/crash functionality is excluded. |
| 18751 | Slider | `LineLagSSlider` | Lag Strength | Excluded | Intentional flood/crash functionality is excluded. |
| 18765 | Toggle | `CrazyLineToggle` | Crazy Line | Not ported | No verified compatible implementation added; see limitations below. |
| 18788 | Slider | `SoftLagSlider` | Speed (seconds) | Excluded | Intentional flood/crash functionality is excluded. |
| 18799 | Toggle | `PacketLagToggle` | Packet-Lag Server | Excluded | Intentional flood/crash functionality is excluded. |
| 18819 | KeyPicker | `PacketLagKey` | Packet-Lag Server | Excluded | Intentional flood/crash functionality is excluded. |
| 18828 | Button | `` | Send One Packet | Excluded | Intentional flood/crash functionality is excluded. |
| 18840 | KeyPicker | `OnePacketKey` | Packet Once | Excluded | Intentional flood/crash functionality is excluded. |
| 18844 | Slider | `PacketLagSlider` | Packet Size | Excluded | Intentional flood/crash functionality is excluded. |
| 18857 | Slider | `PacketLagSlider2` | Sending Delay | Excluded | Intentional flood/crash functionality is excluded. |
| 18870 | Input | `CustomPacketPrefix` | Custom Prefix | Excluded | Intentional flood/crash functionality is excluded. |
| 18882 | Button | `` | Break Server (Lobotomy) | Excluded | Intentional flood/crash functionality is excluded. |
| 18918 | Slider | `LoboStrengthSl` | Length | Excluded | Intentional flood/crash functionality is excluded. |
| 18934 | Dropdown | `GrabsDropdown` | Grabs | Not ported | Removed modes excluded; retained modes already available. |
| 18959 | Toggle | `ToggleGrabs` | Toggle Grabs | Existing/partial | Existing per-mode grab switches. |
| 18971 | Dropdown | `UnstickGrabDD` | Unstick Grab | Not ported | No verified compatible implementation added; see limitations below. |
| 18988 | Dropdown | `AurasDropdown` | Auras | Existing/partial | Existing independent player aura toggles; previously removed modes stay absent. |
| 19016 | Slider | `AuraSlider` | Aura Distance | Existing/partial | Existing player aura range. |
| 19029 | Toggle | `ToggleAuras` | Toggle Auras | Existing/partial | Existing independent player auras and stop action. |
| 19038 | Toggle | `AuraVisualizer` | Show Aura Radius | Existing/partial | Existing aura ring. |
| 19054 | Toggle | `ExcludeT` | Exclude Targets | Not ported | No verified compatible implementation added; see limitations below. |
| 19066 | Dropdown | `BLAuraDropdown` | Limbs to delete | Not ported | Limb deletion is not imported. |
| 19082 | Dropdown | `TAurasDropdown` | Auras | Existing/partial | Existing object attraction and shape controls; individual toy-contact effects not imported. |
| 19095 | Slider | `ToyAuraDistance` | Aura Distance | Existing/partial | Existing formation distance/range controls. |
| 19108 | Toggle | `ToggleTAuras` | Toggle Toy Auras | Existing/partial | Existing creative object aura. |
| 19118 | Toggle | `ToyAuraVisualizer` | Show Toy Aura Radius | Not ported | No verified compatible implementation added; see limitations below. |
| 19138 | Toggle | `AntiGrab` | Anti Grab | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19148 | Toggle | `GucciAntiGrab` | [GUCCI] Anti Grab | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19155 | KeyPicker | `GucciK` | [GUCCI] Anti Grab | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19163 | Toggle | `AntiBlobman` | Anti Blobman | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19172 | Toggle | `AntiInputLag` | Anti Network Ownership | Existing | Existing option ID preserved from main. |
| 19179 | KeyPicker | `AntiNetK` | Anti Network Ownership | Not ported | No verified compatible implementation added; see limitations below. |
| 19187 | Toggle | `AntiExplosion` | Anti Explosion | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19196 | Toggle | `AntiBurn` | Anti Burn | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19205 | Toggle | `AntiVoid` | Anti Void | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19214 | Toggle | `AntiKick` | Anti Kick | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19224 | Toggle | `AntiKick2` | [Break PCLD] Anti Kick | Existing/partial | Existing own-shuriken Anti Kick; PCLD-breaking variant not added. |
| 19233 | Toggle | `AntiSticky` | Anti Sticky | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19272 | Toggle | `AntiSnowball` | Anti Snowball | Not ported | Depends on original rig/limb and runtime state functions; no immunity claim or destructive rig port. |
| 19289 | Toggle | `AntiBanana` | Anti Banana | Not ported | Previously removed at user request; not reintroduced. |
| 19298 | Toggle | `AntiPaint` | Anti Paint | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19344 | Toggle | `AntiPoison` | Anti Poison | Existing/partial | Existing local poison-touch filter. |
| 19370 | Toggle | `AntiLag` | Anti Lag | Not ported | No verified compatible implementation added; see limitations below. |
| 19404 | KeyPicker | `AntiLagK` | Anti Lag | Not ported | No verified compatible implementation added; see limitations below. |
| 19406 | Toggle | `AutoAntiLag` | Auto Anti Lag | Not ported | No verified compatible implementation added; see limitations below. |
| 19415 | Toggle | `AntiInvis` | Anti Invis | Not ported | No verified compatible implementation added; see limitations below. |
| 19447 | Toggle | `AutoReset` | Auto Reset | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19456 | Toggle | `LoopTP` | Loop TP | Existing | Existing option ID preserved from main. |
| 19497 | Toggle | `DisblVoid` | Disable Void | Existing/partial | Existing supplied Disable Void. |
| 19513 | Toggle | `WaterWalk` | Water Walk | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19552 | Toggle | `DeleteBarriers` | Noclip Barrier | Not ported | No verified compatible implementation added; see limitations below. |
| 19575 | Toggle | `OtherInvCollisions` | Anti-Fling [Objects Noclip] | Existing/partial | Existing object/local collision controls and extreme-motion recovery; no claimed immunity. |
| 19621 | Dropdown | `CADropdown` | Consequences | Existing/partial | Existing Auto Attacker Kill/Fling modes. |
| 19632 | Toggle | `CAToggle` | Counter Attack | Existing/partial | Existing Auto Attacker. |
| 19645 | Dropdown | `deleteLimbsCounterBoxDropdown` | Limbs to delete | Not ported | Limb deletion is not imported. |
| 19661 | Slider | `AntiLagSens` | Auto Anti-Lag Sensitivity | Existing/partial | Existing auto anti-lag sensitivity controls. |
| 19674 | Toggle | `AutoLeave` | Auto Leave | Existing/partial | Existing rapid-correction auto leave. |
| 19685 | Dropdown | `AGTDropdown` | Anti-Grab Type | Existing/partial | Existing Anti Grab method selector. |
| 19696 | Dropdown | `GTDropdown` | GUCCI Type | Existing/partial | Existing Gucci vehicle selection. |
| 19717 | Dropdown | `AITDropdown` | Type | Existing/partial | Existing Anti Input interactable-toy selection. |
| 19758 | Slider | `AntiInpLagDel` | Grab & Drop Delay | Existing/partial | Existing anti-input hold/drop delay. |
| 19772 | Slider | `ItemTransAK` | Item Transparency | Existing/partial | Existing Anti Input item transparency. |
| 19786 | Toggle | `AntiKickHL` | Highlight | Not ported | No verified compatible implementation added; see limitations below. |
| 19814 | Slider | `FillTransAK` | Fill Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19825 | Slider | `OutlTransAK` | Outline Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 19836 | Slider | `ShurTransAK` | Shuriken Transparency | Existing/partial | Existing Anti Kick visual customization. |
| 19864 | Dropdown | `MethodSettingsTargets` | Methods | Not ported | No verified compatible implementation added; see limitations below. |
| 19887 | Dropdown | `NKDelayConf` | Delay Mode | Not ported | No verified compatible implementation added; see limitations below. |
| 19897 | Toggle | `RagdollNK` | Loop Ragdoll | Not ported | No verified compatible implementation added; see limitations below. |
| 19905 | Toggle | `AntiKickRemoverNK` | Remove Anti-Kick | Not ported | No verified compatible implementation added; see limitations below. |
| 19913 | Toggle | `EKIToggle` | Experimental Kick Improvements [BETA] | Not ported | No verified compatible implementation added; see limitations below. |
| 19925 | Slider | `HeightNK` | Kick Height | Not ported | No verified compatible implementation added; see limitations below. |
| 19937 | Button | `` | TP To Void Platform | Not ported | No verified compatible implementation added; see limitations below. |
| 19952 | Dropdown | `KickServerMethod` | Kick Server Method | Not ported | No verified compatible implementation added; see limitations below. |
| 19966 | Toggle | `RagdollInRG` | Break Player? [Inf Ragdoll] | Not ported | No verified compatible implementation added; see limitations below. |
| 19975 | Button | `` | Fix Gucci Remover | Not ported | No verified compatible implementation added; see limitations below. |
| 20022 | Toggle | `AutoSeatBlobman` | Auto Sit Blobman | Existing/partial | Existing auto-seat and reseating controller. |
| 20034 | KeyPicker | `ASBK` | Auto Sit Blobman | Not ported | No verified compatible implementation added; see limitations below. |
| 20042 | Toggle | `FreezeBlob` | Freeze Blobman | Existing/partial | Existing Heavy Blobman idle stabilization. |
| 20048 | Dropdown | `MethodSettingsBlobs` | Blobman Method | Not ported | No verified compatible implementation added; see limitations below. |
| 20062 | Dropdown | `KickSettingBlob` | Kick Method | Not ported | No verified compatible implementation added; see limitations below. |
| 20076 | Toggle | `ShurikenDeleteBlob` | Remove Anti-Kick [Sticky] | Not ported | No verified compatible implementation added; see limitations below. |
| 20087 | Toggle | `NetOwninKick` | Net Owner Spam | Not ported | No verified compatible implementation added; see limitations below. |
| 20096 | Slider | `BlobKickX` | X Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 20097 | Slider | `BlobKickY` | Y Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 20098 | Slider | `BlobKickZ` | Z Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 20106 | Toggle | `BreakBarrierT` | Disable House Barrier | Existing/partial | Existing local plot barrier control. |
| 20287 | Dropdown | `MethodSettingsTEf` | Effects | Not ported | No verified compatible implementation added; see limitations below. |
| 20309 | Dropdown | `BLTEDropdown` | Limbs to delete | Not ported | Limb deletion is not imported. |
| 20325 | Dropdown | `FlingMethod` | Fling Method | Not ported | No verified compatible implementation added; see limitations below. |
| 20421 | Dropdown | `ShapesDropdown` | Shape | Existing label match | Same visible control label exists in main; behavior may differ. |
| 20434 | Dropdown | `GrabTypeDropdown` | Grab Type | Not ported | No verified compatible implementation added; see limitations below. |
| 20446 | Toggle | `ToysAuraLimitEnabled` | Limit Toys | Not ported | No verified compatible implementation added; see limitations below. |
| 20458 | Slider | `ToysAuraLimit` | Toys Limit | Not ported | No verified compatible implementation added; see limitations below. |
| 20471 | Toggle | `ToysAuraOwnInventory` | Only Your Inventory | Not ported | No verified compatible implementation added; see limitations below. |
| 20489 | Button | `` | Grab All Toys | Not ported | No verified compatible implementation added; see limitations below. |
| 20515 | Button | `` | Release Toys | Existing | Existing object formation stop/release. |
| 20539 | Dropdown | `PositionTypeDropdown` | Position Type | Not ported | No verified compatible implementation added; see limitations below. |
| 20557 | Button | `` | Set Custom Position | Not ported | No verified compatible implementation added; see limitations below. |
| 20584 | Dropdown | `ExplosionType` | Explosion Type | Existing label match | Same visible control label exists in main; behavior may differ. |
| 20597 | Slider | `missilesToFire` | How much to fire at once? | Not ported | No verified compatible implementation added; see limitations below. |
| 20611 | Toggle | `AutoExpTarget` | Auto Explode Target | Not ported | No verified compatible implementation added; see limitations below. |
| 20642 | Button | `` | Release All | Existing | Existing aura/formation/loop stop controls. |
| 20647 | KeyPicker | `ReleaseAll` | Release All | Existing | Existing aura/formation/loop stop controls. |
| 20715 | Dropdown | `ObjectGroup` | Group | Existing/partial | Existing named own-toy groups. |
| 20740 | Button | `` | Create Group | Existing | Existing named groups. |
| 20742 | Toggle | `GroupNoclip` | Noclip Toys | Ported | PackGroupNoclip: Current own-toy group; restores original collisions. |
| 20750 | Toggle | `GroupHighlight` | Highlight Group | Ported | PackGroupHighlight: Current own-toy group highlight. |
| 20772 | Button | `` | Add Object | Existing | Existing selected-toy group action. |
| 20772 | KeyPicker | `GroupAddObject` | Add Object to Group | Existing | Existing selected-toy/group manager. |
| 20774 | Button | `` | Remove Object | Not ported | No verified compatible implementation added; see limitations below. |
| 20783 | KeyPicker | `GroupRemoveObject` | Remove Object from Group | Not ported | No verified compatible implementation added; see limitations below. |
| 20787 | Button | `` | Anchor / Release Group | Not ported | No verified compatible implementation added; see limitations below. |
| 20798 | Button | `` | Delete Group | Not ported | No verified compatible implementation added; see limitations below. |
| 20815 | Toggle | `BreakPartAffectsYou` | Affects you | Not ported | No verified compatible implementation added; see limitations below. |
| 20831 | Toggle | `HighlightBrokenParts` | Highlight Broken Parts | Not ported | No verified compatible implementation added; see limitations below. |
| 20907 | KeyPicker | `DecollidePart` | Decollide Part | Ported | Part Tools / Decollide selected part (local). |
| 20918 | Button | `` | Create Button | Not ported | No verified compatible implementation added; see limitations below. |
| 20925 | Button | `` | Remove Button | Not ported | No verified compatible implementation added; see limitations below. |
| 20934 | Button | `` | Break Spawn | Not ported | No verified compatible implementation added; see limitations below. |
| 20958 | Dropdown | `BreakMethod` | Break Method | Not ported | No verified compatible implementation added; see limitations below. |
| 20980 | Dropdown | `WhichToBreak` | Which to Break | Not ported | No verified compatible implementation added; see limitations below. |
| 20998 | Button | `` | Break | Not ported | No verified compatible implementation added; see limitations below. |
| 21029 | Button | `` | Destroy Train | Not ported | No verified compatible implementation added; see limitations below. |
| 21031 | Button | `` | Make Tsunami | Not ported | No verified compatible implementation added; see limitations below. |
| 21043 | Dropdown | `CoconutFormsDropdown` | Forms | Not ported | No verified compatible implementation added; see limitations below. |
| 21068 | Toggle | `CoconutFormsToggle` | Coconut Forms | Partial port | Wings, Cape and 67 added to existing object formations; other body forms not imported. |
| 21070 | Slider | `CoconutFormsTransparency` | Transparency | Not ported | No verified compatible implementation added; see limitations below. |
| 21083 | Slider | `CoconutShaftLength` | Penis Shaft Length | Not ported | No verified compatible implementation added; see limitations below. |
| 21093 | Slider | `CoconutShaftSpacing` | Penis Shaft Spacing | Not ported | No verified compatible implementation added; see limitations below. |
| 21109 | Slider | `CoconutWingsSpacing` | Wings Spacing | Not ported | No verified compatible implementation added; see limitations below. |
| 21124 | Dropdown | `CoconutCapeMode` | Cape Layout | Not ported | No verified compatible implementation added; see limitations below. |
| 21138 | Slider | `Coconut67Spacing` | 67 Spacing | Not ported | No verified compatible implementation added; see limitations below. |
| 21151 | Dropdown | `Coconut67Display` | 67 Direction | Not ported | No verified compatible implementation added; see limitations below. |
| 21165 | Toggle | `DestroyAllHoldables` | Break all Holdables | Not ported | No verified compatible implementation added; see limitations below. |
| 21188 | Button | `` | Destroy All Toys | Not ported | Global shared-toy deletion is not added; own-toy deletion controls remain. |
| 21244 | Toggle | `PlrESPT` | Player ESP | Not ported | No verified compatible implementation added; see limitations below. |
| 21289 | Toggle | `PCLDESPT` | Server ESP [PCLD] | Not ported | No verified compatible implementation added; see limitations below. |
| 21337 | Toggle | `StickyESPT` | Sticky ESP | Ported | PackStickyESP: Streamed sticky-part overlay. |
| 21366 | Toggle | `BlackholeESPT` | Blackhole ESP | Ported | PackBlackholeESP: Blackhole/Hole overlay. |
| 21409 | Dropdown | `EspConfDD` | Select which to configure | Not ported | No verified compatible implementation added; see limitations below. |
| 21421 | Toggle | `PlayerHighlightEnabled` | Enabled | Ported | PackESPHighlight: Highlight independent of nameplate. |
| 21429 | Slider | `PlayerFillTrans` | Fill Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21441 | Slider | `PlayerOutlTrans` | Outline Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21459 | Toggle | `NameESPEnabled` | Enabled | Ported | PackESPNameplate: Nameplate visibility. |
| 21467 | Dropdown | `FFNameESP` | Font Face | Ported | PackESPFont: Four font families, with bold support. |
| 21487 | Toggle | `BoldToggleFF` | Bold? | Not ported | No verified compatible implementation added; see limitations below. |
| 21512 | Toggle | `NameShowIconToggle` | Show Icon | Ported | PackESPAvatar: Avatar icon visibility. |
| 21523 | Slider | `NameOutlTrans` | Outline Transparency | Ported | PackESPTextOutline: Text-stroke transparency. |
| 21535 | Slider | `NameESize` | Size | Ported | PackESPTextSize: Name text size. |
| 21547 | Slider | `NameYOffsetSlider` | Vertical Offset | Ported | PackESPNameOffset: Billboard height. |
| 21562 | Toggle | `SmoothPCLD` | Smooth Movement | Not ported | No verified compatible implementation added; see limitations below. |
| 21577 | Slider | `PCLDFillTrans` | Fill Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21589 | Slider | `PCLDOutlTrans` | Outline Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21601 | Slider | `PCLDOutlThick` | Outline Thickness | Not ported | No verified compatible implementation added; see limitations below. |
| 21617 | Toggle | `PCLDNameEnabled` | Enabled | Not ported | No verified compatible implementation added; see limitations below. |
| 21625 | Dropdown | `FFPCLDNameESP` | Font Face | Not ported | No verified compatible implementation added; see limitations below. |
| 21645 | Toggle | `BoldTogglePCLDFF` | Bold? | Not ported | No verified compatible implementation added; see limitations below. |
| 21672 | Slider | `PCLDNameOutlTrans` | Name Outline Transparency | Not ported | No verified compatible implementation added; see limitations below. |
| 21684 | Slider | `PCLDOwnerDistance` | Show When Away | Not ported | No verified compatible implementation added; see limitations below. |
| 21696 | Slider | `PCLDNameSize` | Name Size | Not ported | No verified compatible implementation added; see limitations below. |
| 21708 | Slider | `PCLDNameYOffset` | Name Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 21723 | Slider | `StickyFillTrans` | Fill Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21735 | Slider | `StickyOutlTrans` | Outline Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21747 | Slider | `StickyOutlThick` | Outline Thickness | Not ported | No verified compatible implementation added; see limitations below. |
| 21765 | Slider | `BlackholeFillTrans` | Fill Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21777 | Slider | `BlackholeOutlTrans` | Outline Transparency | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21793 | Dropdown | `FFBHESP` | Font Face | Not ported | No verified compatible implementation added; see limitations below. |
| 21813 | Toggle | `BoldToggleFF2` | Bold? | Not ported | No verified compatible implementation added; see limitations below. |
| 21842 | Toggle | `DisableBlurT` | Disable Ragdoll Blur | Existing/partial | Existing PrivateDisableBlur retained, no duplicate toggle. |
| 21856 | Toggle | `ThirdpersonT` | Third Person | Existing/partial | Existing third-person controls. |
| 21869 | KeyPicker | `ThirdPersonK` | Third Person | Not ported | No verified compatible implementation added; see limitations below. |
| 21877 | Toggle | `CameraNoclip` | Camera Noclip | Not ported | Depends on private CameraModule hooks; not blindly transplanted. |
| 21879 | Slider | `FOVsl` | FOV | Existing label match | Same visible control label exists in main; behavior may differ. |
| 21915 | Toggle | `RealisticFirstPersonT` | Realistic First Person | Existing/partial | Existing first-person limb visibility. |
| 21929 | Slider | `RFPTransparency` | Limb Transparency | Existing/partial | Existing limb-transparency slider. |
| 22169 | Toggle | `CustomWaterT` | Realistic Water | Existing/partial | Existing custom water appearance. |
| 22188 | Toggle | `NonSwimmableWater` | Non-Swimmable Water | Ported | PackNoSwimming: Restores humanoid state settings; independent of custom water appearance. |
| 22198 | Slider | `WaterWaveSize` | Wave Size | Existing/partial | Existing water controls. |
| 22210 | Slider | `WaterWaveSpeed` | Wave Speed | Existing/partial | Existing water controls. |
| 22222 | Slider | `WaterTransparency` | Transparency | Existing/partial | Existing water controls. |
| 22234 | Slider | `WaterReflectance` | Reflectance | Existing/partial | Existing water controls. |
| 22292 | Toggle | `ShadersT` | Shaders | Existing/partial | Existing local shaders. |
| 22356 | Slider | `ShaderBrightness` | Brightness | Existing/partial | Existing shader brightness. |
| 22372 | Slider | `ShaderExposure` | Exposure | Not ported | No verified compatible implementation added; see limitations below. |
| 22388 | Slider | `ShaderBloomIntensity` | Bloom Intensity | Existing/partial | Existing shader bloom. |
| 22405 | Slider | `ShaderSaturation` | Saturation | Existing/partial | Existing shader saturation. |
| 22433 | Toggle | `ParticlesT` | Particles | Existing/partial | Existing local character particles. |
| 22444 | Dropdown | `ParticlesDropdown` | Texture | Not ported | No verified compatible implementation added; see limitations below. |
| 22466 | Input | `customParticleBoxInput` | Custom Image ID/Link | Ported | PackParticleTexture: Extends the existing emitter texture; world-box placement is not ported. |
| 22480 | Slider | `PDensity` | Density (Count) | Existing/partial | Existing particle-rate slider. |
| 22491 | Slider | `PSize` | Size | Existing/partial | Existing particle-size slider. |
| 22503 | Slider | `PMaxSp` | Max Speed | Ported | PackParticleMaxSpeed: Existing character particle emitter speed. |
| 22515 | Slider | `PBoxSize` | Box Size | Not ported | No verified compatible implementation added; see limitations below. |
| 22527 | Toggle | `BoostFPS` | Boost FPS | Existing/partial | Existing Improve/Restore FPS and local visual filters. |
| 22529 | Dropdown | `BoostFPSOptions` | Disable | Not ported | No verified compatible implementation added; see limitations below. |
| 22542 | Toggle | `ForcefieldChar` | Highlight Your Character | Existing/partial | Existing Forcefield character appearance. |
| 22557 | Dropdown | `CharacterHighlightAffect` | Affect | Not ported | No verified compatible implementation added; see limitations below. |
| 22571 | Toggle | `ChinaHat` | China Hat | Existing/partial | Existing cone hat. |
| 22592 | Dropdown | `CustomLineDropdown` | Line Texture | Ported | PackLineTexture: All twelve supplied texture assets. |
| 22603 | Toggle | `EnableCL` | Toggle Custom Line | Ported | PackCustomLine: Reversible local line textures. |
| 22613 | Toggle | `GObjectInfo` | Grabbed Object Information | Ported | PackHeldInformation: Held name, distance, assembly mass, anchor state and owner. |
| 22624 | Toggle | `CustomCrosshair` | Custom Crosshair | Existing/partial | Existing crosshair renderer. |
| 22633 | Input | `CustomCrosshairImage` | Image Link/ID | Ported | PackCrosshairImage: Extends the existing crosshair renderer; asset IDs only. |
| 22644 | Slider | `CustomCrosshairSize` | Crosshair Size | Existing/partial | Existing size slider extended to 128 pixels. |
| 22709 | Input | `BlackholeSoundLink` | Sound ID/MP3 Link | Ported | PackBlackholeSound: Roblox sound IDs; executor MP3 download path not imported. |
| 22719 | Toggle | `EnableCBHS` | Toggle Custom Sound | Ported | PackBlackholeSoundOn: Local blackhole sound override, reversible. |
| 22729 | Input | `BlackholeLink` | Image Link/ID | Ported | PackBlackholeImage: Roblox image IDs. |
| 22740 | Toggle | `EnableCBH` | Toggle Custom Image | Ported | PackBlackholeImageOn: Local Large image override, reversible. |
| 22782 | Toggle | `EnableBHStaying` | Toggle Blackhole Staying | Not ported | No verified compatible implementation added; see limitations below. |
| 22935 | Toggle | `` | ResonanceSky | Not ported | No verified compatible implementation added; see limitations below. |
| 23004 | Toggle | `CustomSkyboxT` | Custom Skybox | Existing/partial | Existing local custom sky. |
| 23016 | Input | `SkyboxLink` | Skybox Link/Image ID | Existing/partial | Existing sky asset input. |
| 23032 | Slider | `TimeOfDay` | Time Of Day | Existing label match | Same visible control label exists in main; behavior may differ. |
| 23043 | Slider | `SunSize` | Sun Size | Not ported | No verified compatible implementation added; see limitations below. |
| 23073 | Slider | `CloudsDensity` | Clouds Density | Existing/partial | Existing cloud density. |
| 23084 | Slider | `CloudsCover` | Clouds Cover | Existing/partial | Existing cloud cover. |
| 23095 | Toggle | `CloudsEnabled` | Enable Clouds | Existing/partial | Existing local clouds. |
| 23144 | Toggle | `AutoClicker` | Toggle | Not ported | No verified compatible implementation added; see limitations below. |
| 23152 | Toggle | `IndependentACPoses` | Independent Target Poses | Not ported | No verified compatible implementation added; see limitations below. |
| 23178 | Dropdown | `ACPoseTarget` | Edit Target Pose | Not ported | No verified compatible implementation added; see limitations below. |
| 23259 | Toggle | `CustomACPoseCenter` | Custom Pose Center | Not ported | No verified compatible implementation added; see limitations below. |
| 23277 | Slider | `ACCSecXO` | X Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 23290 | Slider | `ACCSecYO` | Y Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 23303 | Slider | `ACCSecZO` | Z Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 23316 | Slider | `ACCharacterTransparency` | Targets Transparency | Not ported | No verified compatible implementation added; see limitations below. |
| 23334 | Dropdown | `ACLimbO` | Select limb | Not ported | No verified compatible implementation added; see limitations below. |
| 23342 | Dropdown | `ACLimbR` | Select limb | Not ported | No verified compatible implementation added; see limitations below. |
| 23354 | Slider | `ACRSecXO` | X Rotation | Not ported | No verified compatible implementation added; see limitations below. |
| 23367 | Slider | `ACRSecYO` | Y Rotation | Not ported | No verified compatible implementation added; see limitations below. |
| 23380 | Slider | `ACRSecZO` | Z Rotation | Not ported | No verified compatible implementation added; see limitations below. |
| 23397 | Slider | `ACOSecXO` | X Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 23410 | Slider | `ACOSecYO` | Y Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 23423 | Slider | `ACOSecZO` | Z Offset | Not ported | No verified compatible implementation added; see limitations below. |
| 23536 | Dropdown | `ACPoseS` | Choose Preset | Not ported | No verified compatible implementation added; see limitations below. |
| 23547 | Button | `` | Load Preset | Not ported | No verified compatible implementation added; see limitations below. |
| 23563 | Input | `ACCustomPresetName` | Preset Name | Not ported | No verified compatible implementation added; see limitations below. |
| 23572 | Dropdown | `ACCustomPoseS` | Custom Preset | Not ported | No verified compatible implementation added; see limitations below. |
| 23592 | Button | `` | Save Current Preset | Not ported | No verified compatible implementation added; see limitations below. |
| 23682 | Button | `` | Load Custom Preset | Not ported | No verified compatible implementation added; see limitations below. |
| 23706 | Button | `` | Delete Custom Preset | Not ported | No verified compatible implementation added; see limitations below. |
| 23836 | Toggle | `SmoothClickTP` | Smooth Click TP | Ported | PackSmoothClickTP: Optional tween using existing validated landing checks. |
| 24189 | Dropdown | `MobileKeybindsList` | Select Keybind to Map | Not ported | No verified compatible implementation added; see limitations below. |
| 24191 | Button | `` | Create Button | Not ported | No verified compatible implementation added; see limitations below. |
| 24196 | Button | `` | Remove Button | Not ported | No verified compatible implementation added; see limitations below. |
| 24209 | Toggle | `FartherReach` | Further Reach Line | Not ported | Gamepass event renaming/reparenting bypass not imported. |
| 24344 | Toggle | `GradientLineT` | Gradient Line | Ported | PackGradientLine: Nine supplied default gradient stops; optional server sharing at 2 Hz. |
| 24398 | Toggle | `FasterEscapeT` | Faster Escape | Not ported | Gamepass/cooldown patch not imported. |
| 24409 | Slider | `FastEscapeSlider` | Faster Escape | Not ported | Dependent on the unported cooldown patch. |
| 24666 | Slider | `SoundSpamS` | Delay | Not ported | No verified compatible implementation added; see limitations below. |
| 24678 | Toggle | `SoundSpamT` | Sound Spam | Not ported | No verified compatible implementation added; see limitations below. |
| 24690 | Toggle | `autohouse` | Auto-House Teleport | Existing/partial | Existing house-time visits. |
| 24699 | Toggle | `AutoSlotsT` | Auto-Slots | Existing/partial | Existing nearby slot automation. |
| 24712 | Toggle | `AimbotToggle` | Toggle | Ported | PackAimAssist: Visible camera assistance; no global remote interception. |
| 24723 | KeyPicker | `AimbotKeybind` | Aim Key | Not ported | No verified compatible implementation added; see limitations below. |
| 24736 | Dropdown | `TargetPartDD` | Target Part | Ported | PackAimPart: Head/root/torso targeting. |
| 24745 | Toggle | `AlwaysOnToggleAB` | Always On | Ported | PackAimAlways: Always aim or hold right mouse. |
| 24758 | Toggle | `FovCircle` | FOV Circle | Ported | PackAimCircle: Cursor-centered FOV circle. |
| 24774 | Slider | `AimDistance` | Distance | Existing label match | Same visible control label exists in main; behavior may differ. |
| 24787 | Slider | `AimSmoothness` | Smoothness | Ported | PackAimSmoothing: Frame-time-based camera interpolation. |
| 24799 | Slider | `FOVSize` | FOV Radius | Ported | PackAimRadius: Pixel radius. |
| 24815 | Toggle | `TriggerToggle` | Toggle | Not ported | No verified compatible implementation added; see limitations below. |
| 24832 | KeyPicker | `TriggerKeybind` | Triggerbot | Existing label match | Same visible control label exists in main; behavior may differ. |
| 24843 | Slider | `TriggerDelay` | Delay | Not ported | No verified compatible implementation added; see limitations below. |
| 24856 | Slider | `TriggerDistance` | Distance | Existing label match | Same visible control label exists in main; behavior may differ. |
| 24869 | Slider | `TriggerCooldown` | Cooldown | Not ported | No verified compatible implementation added; see limitations below. |
| 24882 | Toggle | `TriggerTricks` | Camera Tricks | Not ported | No verified compatible implementation added; see limitations below. |
| 24893 | Dropdown | `TriggerTrick` | Trick | Not ported | No verified compatible implementation added; see limitations below. |
| 24903 | Slider | `TriggerTrickSpeed` | Trick Speed | Not ported | No verified compatible implementation added; see limitations below. |
| 24920 | Toggle | `SilentAim` | Silent Aim | Not ported | Global namecall/remote interception needs separate compatibility review; not imported. |
| 24925 | KeyPicker | `SAIMKeybind` | Silent Aim | Not ported | No verified compatible implementation added; see limitations below. |
| 24933 | Toggle | `SilentAimIgnoreWhitelist` | Ignore Whitelisted | Not ported | Protected-player rules are preserved. |
| 24942 | Toggle | `SilentAimTargetsOnly` | Selected Targets Only | Not ported | No verified compatible implementation added; see limitations below. |
| 24955 | Toggle | `SilentAimFOV` | Show FOV Circle | Not ported | No verified compatible implementation added; see limitations below. |
| 24966 | Slider | `SilentAimRadius` | Aim Radius | Not ported | No verified compatible implementation added; see limitations below. |
| 24980 | Slider | `SilentAimSize` | Hitbox Size | Not ported | No verified compatible implementation added; see limitations below. |
| 25003 | Dropdown | `SelectedPlotDropdown` | Select Plot | Not ported | No verified compatible implementation added; see limitations below. |
| 25019 | Toggle | `AutoClaimPlot` | Auto-Claim Plot | Ported | PackAutoClaimPlot: Nearby empty plots only, at most once per five seconds. |
| 25036 | Button | `` | Break Plot Area | Not ported | No verified compatible implementation added; see limitations below. |
| 25044 | Button | `` | Fix Plot Area | Not ported | No verified compatible implementation added; see limitations below. |
| 25056 | Button | `` | Fling all toys in plot | Not ported | No verified compatible implementation added; see limitations below. |
| 25065 | Button | `` | Find Cheaters | Not ported | No verified compatible implementation added; see limitations below. |
| 25231 | Toggle | `AutoWhitelistFriends` | Auto Whitelist Friends | Existing/partial | Existing friends protection. |
| 25265 | Toggle | `WhitelistToggle` | Toggle Whitelist | Existing/partial | Existing protected-player selector. |
| 25287 | Toggle | `ImmunityAGToggle` | Give Anti-Grab | Not ported | No verified compatible implementation added; see limitations below. |
| 25297 | Toggle | `ImmunityAKToggle` | Give Anti-Kick | Not ported | No verified compatible implementation added; see limitations below. |
| 25306 | Toggle | `ImmunityAEToggle` | Give Anti-Explosion | Not ported | No verified compatible implementation added; see limitations below. |
| 25319 | KeyPicker | `menukey` | Menu Keybind | Existing label match | Same visible control label exists in main; behavior may differ. |
| 25322 | Toggle | `WatermarkT` | Watermark | Existing/partial | Existing FPS/ping widget. |
| 25332 | Toggle | `KeybindMenuOpen` | Open Keybind Menu | Not ported | No verified compatible implementation added; see limitations below. |
| 25341 | Toggle | `OnlyAssignedKeybinds` | Only Show Assigned | Not ported | No verified compatible implementation added; see limitations below. |
| 25353 | Toggle | `UnlockMouse` | Unlock Mouse | Existing/partial | Existing Free Mouse shortcut. |
| 25360 | KeyPicker | `unlockmousekey` | Unlock Mouse | Not ported | No verified compatible implementation added; see limitations below. |
| 25362 | Toggle | `MouseLockT` | Mouse-Lock | Not ported | No verified compatible implementation added; see limitations below. |
| 25397 | KeyPicker | `MouseLockKey` | Mouse-Lock Key | Not ported | No verified compatible implementation added; see limitations below. |
| 25420 | Toggle | `PositionPrediction` | Position Prediction | Existing/partial | Existing missile prediction option. |
| 25429 | Toggle | `DirectGrab` | Direct Grab CFrame | Not ported | No verified compatible implementation added; see limitations below. |
| 25443 | Toggle | `ShowCustomCursor` | Custom Cursor | Existing label match | Same visible control label exists in main; behavior may differ. |
| 25455 | Input | `CursorImage` | Image Link/ID | Existing/partial | Existing custom cursor asset input. |
| 25472 | Slider | `CursorIconSize` | Custom Cursor Size | Existing/partial | Existing custom cursor size. |
| 25486 | Button | `` | Reset to Default | Not ported | No verified compatible implementation added; see limitations below. |
| 25498 | Dropdown | `DPIDropdown` | UI Scale | Existing label match | Same visible control label exists in main; behavior may differ. |
| 25509 | Slider | `UICornerSlider` | Corner Radius | Existing/partial | Existing UI appearance/scale controls; independent corner-radius control not added. |
| 25532 | Toggle | `NotificationMaster` | Master Switch | Existing/partial | Existing notification settings. |
| 25541 | Dropdown | `NotificationReceivers` | Event Notifications | Not ported | No verified compatible implementation added; see limitations below. |
| 25556 | Dropdown | `NotifDropdown` | Presets | Not ported | No verified compatible implementation added; see limitations below. |
| 25569 | Input | `CustomNotificationSound` | Sound ID/MP3 Link | Not ported | No verified compatible implementation added; see limitations below. |
| 25587 | Dropdown | `NotificationSide` | Notification Side | Existing/partial | Existing notification positioning. |
| 25596 | Slider | `NotifVolumeSlider` | Volume | Existing/partial | Existing alert audio preferences; dedicated per-preset volume not imported. |
| 25607 | Button | `` | Test Notification | Not ported | No verified compatible implementation added; see limitations below. |
| 25624 | Input | `KickedPlayerNotification` | Kicked Player Message | Not ported | No verified compatible implementation added; see limitations below. |
| 25635 | Input | `LeftPlayerNotification` | Player Left Message | Not ported | No verified compatible implementation added; see limitations below. |
| 25646 | Input | `RejoinedPlayerNotification` | Player Rejoined Message | Not ported | No verified compatible implementation added; see limitations below. |
