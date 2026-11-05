# Resonance transfer audit

This inventory covers the reference UI’s literal named toggles from line 34000 onward. “Counterpart” means related functionality exists under the listed Arriva controls; it does not establish identical implementation, server acceptance or complete configuration parity. Dynamic methods, buttons, sliders, inputs and keybinds are not counted as separate feature parity claims.

The latest pass adds zoom/stretch, ambient particles, selective FPS settings, public-server browsing/timed hopping, reconnect and optional queued hub reload, extended PCLD display, held-object HUD, Faster Escape timer/input, mouse-lock binding, toy-aura range and persistent blackhole visuals. Existing Anti Grab modes, two-respawn PCLD fix, Gucci lifecycle and earlier ports remain in place.

This is not a complete one-to-one port of Resonance. Nonported items are listed explicitly below. Original kill-loop replacements previously reverted by the user are not reintroduced; Auto Reset, the seven Gucci event-handler pairs and the working spawner are preserved. Packet/line flooders and Shutdown remain absent.

| Reference toggle | Reference line | Status | Arriva control(s) |
| --- | ---: | --- | --- |
| Auto Rejoin (`AutoRj`) | 35385 | Added/expanded in this pass | `ResonanceAutoRejoin` |
| Join with Anti-Lag (`RejoinWithAntiLag`) | 35393 | Not imported: automatic anti-lag injection during reconnect is not installed. |  |
| Join with script (`RejoinWithScript`) | 35402 | Added/expanded in this pass | `ResonanceReloadAfterTeleport` |
| Auto Server-Hop (`AutoServerHop`) | 35494 | Added/expanded in this pass | `ResonanceAutoHop` |
| Flight (`FlyT`) | 35551 | Existing/adapted counterpart | `PackCharacterFlight` |
| Walkspeed (`WalkspeedT`) | 35564 | Existing/adapted counterpart | `SpeedModifierToggle` |
| Jump Power (`JumpPowerT`) | 35581 | Existing/adapted counterpart | `JumpModifierToggle` |
| Character Spin (`SpinT`) | 35590 | Existing/adapted counterpart | `SpinToggle` |
| Noclip (`NoclipT`) | 35625 | Existing/adapted counterpart | `SelfNoclipToggle` |
| Inf Jump (`InfJumpT`) | 35642 | Existing/adapted counterpart | `infJumpToggle` |
| Jerk Off (`JerkOffT`) | 35650 | Not imported: reference-specific animation macro. |  |
| Position Desync (`DesyncT`) | 35692 | Not imported: executor/engine flag-based position desync; current Gucci remains separate. |  |
| Make Spawn Location (`MakeSpawnLoc`) | 35724 | Existing/adapted counterpart | `ReturnToSpawnBookmark` |
| Loop TP to Location (`LoopTPToLoc`) | 35752 | Existing/adapted counterpart | `LoopTP` |
| Spectate Player (`LoopSpectatePlayer`) | 35775 | Existing/adapted counterpart | `LocalSpectatorEnabled` |
| Loop TP to Player (`LoopTPToPlayer`) | 35800 | Existing/adapted counterpart | `SelfFollowEnabled` |
| Enabled (`LookFigures`) | 35834 | Not imported: separate rig-pose controller. |  |
| Show Locally (`LookFiguresPreview`) | 35836 | Not imported: preview depends on the rig-pose controller. |  |
| Toggle Animation (`AnimationToggle`) | 35948 | Existing/adapted counterpart | `PrivateAnimationEnabled` |
| Toggle Extend Line (`ExtLineToggle`) | 36000 | Existing/adapted counterpart | `ExtendToggle` |
| Super Strength (`SupStrength`) | 36022 | Existing/adapted counterpart | `ThrowStrengthToggle` |
| Line-Lag Server (`LineLagToggle`) | 36035 | Excluded: previously removed line flooder stays removed. |  |
| Crazy Line (`CrazyLineToggle`) | 36069 | Not imported: separate remote line-spam controller. |  |
| Packet-Lag Server (`PacketLagToggle`) | 36103 | Excluded: previously removed packet flooder stays removed. |  |
| Toggle Grabs (`ToggleGrabs`) | 36263 | Existing/adapted counterpart | `KillGrabToggle`, `ToolSpinGrab` |
| Toggle Auras (`ToggleAuras`) | 36333 | Existing/adapted counterpart | `Deathaura`, `FlingAura` |
| Show Aura Radius (`AuraVisualizer`) | 36342 | Existing/adapted counterpart | `PlayerAuraRangePreview` |
| Exclude Targets (`ExcludeT`) | 36358 | Existing/adapted counterpart | `WhitelistFriends` |
| Toggle Toy Auras (`ToggleTAuras`) | 36412 | Existing/adapted counterpart | `CreativeAuraEnabled` |
| Show Toy Aura Radius (`ToyAuraVisualizer`) | 36422 | Added/expanded in this pass | `CreativeAuraRangePreview` |
| Anti Grab (`AntiGrab`) | 36442 | Existing/adapted counterpart | `AntiGrabObsidian`, `AntiGrabType` |
| [GUCCI] Anti Grab (`GucciAntiGrab`) | 36452 | Existing/adapted counterpart | `AutoGucciBlobToggle`, `SourceGucciVehicle` |
| Anti Blobman (`AntiBlobman`) | 36467 | Existing/adapted counterpart | `AntiBlobmanToggle` |
| Anti Network Ownership (`AntiInputLag`) | 36476 | Existing/adapted counterpart | `AntiInputLag` |
| Anti Explosion (`AntiExplosion`) | 36491 | Existing/adapted counterpart | `AntiExplosionToggle` |
| Anti Burn (`AntiBurn`) | 36500 | Existing/adapted counterpart | `AntiBurnToggle` |
| Anti Void (`AntiVoid`) | 36509 | Existing/adapted counterpart | `AntiVoidToggle` |
| Anti Kick (`AntiKick`) | 36518 | Existing/adapted counterpart | `ShurikenAntiKick` |
| [Break PCLD] Anti Kick (`AntiKick2`) | 36528 | Existing/adapted counterpart | `SourceBreakPCLD` |
| Anti Sticky (`AntiSticky`) | 36537 | Existing/adapted counterpart | `AntiStickyToggle` |
| Anti Snowball (`AntiSnowball`) | 36576 | Existing/adapted counterpart | `SourceAntiSnowball` |
| Anti Banana (`AntiBanana`) | 36593 | Existing/adapted counterpart | `SourceAntiBanana` |
| Anti Paint (`AntiPaint`) | 36602 | Existing/adapted counterpart | `PaintDeleteToggle` |
| Anti Poison (`AntiPoison`) | 36648 | Existing/adapted counterpart | `PrivatePoisonTouch` |
| Anti Lag (`AntiLag`) | 36674 | Existing/adapted counterpart | `AntiLagToggle` |
| Auto Anti Lag (`AutoAntiLag`) | 36710 | Existing/adapted counterpart | `SourceLowFpsAntiLag` |
| Anti Invis (`AntiInvis`) | 36719 | Existing/adapted counterpart | `SourceAntiInvis` |
| Auto Reset (`AutoReset`) | 36751 | Existing/adapted counterpart | `AutoResetToggle` |
| Loop TP (`LoopTP`) | 36760 | Existing/adapted counterpart | `LoopTP` |
| Disable Void (`DisblVoid`) | 36801 | Existing/adapted counterpart | `SourceDisableVoid` |
| Water Walk (`WaterWalk`) | 36817 | Existing/adapted counterpart | `WaterWalkToggle` |
| Noclip Barrier (`DeleteBarriers`) | 36856 | Existing/adapted counterpart | `SourceNoclipBarrier` |
| Anti-Fling [Objects Noclip] (`OtherInvCollisions`) | 36879 | Existing/adapted counterpart | `SourceAntiObjectFling` |
| Counter Attack (`CAToggle`) | 36936 | Existing/adapted counterpart | `AutoAttacker` |
| Auto Leave (`AutoLeave`) | 36978 | Excluded: would change the Auto Reset behavior the user required unchanged. |  |
| Highlight (`AntiKickHL`) | 37090 | Existing/adapted counterpart | `SourceAntiKickHighlight` |
| Loop Ragdoll (`RagdollNK`) | 37201 | Not imported: optional modification to the reference kick controller; existing loops retained. |  |
| Remove Anti-Kick (`AntiKickRemoverNK`) | 37209 | Existing/adapted counterpart | `DestroyAntiKickToggle` |
| Experimental Kick Improvements [BETA] (`EKIToggle`) | 37217 | Not imported: experimental kick controller variant; existing loops retained. |  |
| Break Player? [Inf Ragdoll] (`RagdollInRG`) | 37270 | Existing scoped variant: SourceRagdollOnRemoveGucci; not a generic permanent ragdoll modifier. |  |
| Auto Sit Blobman (`AutoSeatBlobman`) | 37326 | Existing/adapted counterpart | `AutoSitZ` |
| Freeze Blobman (`FreezeBlob`) | 37346 | Existing/adapted counterpart | `HeavyBlobman` |
| Remove Anti-Kick [Sticky] (`ShurikenDeleteBlob`) | 37380 | Existing/adapted counterpart | `DestroyAntiKickToggle` |
| Net Owner Spam (`NetOwninKick`) | 37391 | Not imported: separate network-owner spam modifier. |  |
| Disable House Barrier (`BreakBarrierT`) | 37410 | Existing/adapted counterpart | `SourceNoclipBarrier` |
| Limit Toys (`ToysAuraLimitEnabled`) | 37750 | Not imported: exact reference toy-aura limit switch; current shape/toy budgets are separate. |  |
| Only Your Inventory (`ToysAuraOwnInventory`) | 37775 | Not imported: exact reference inventory filter; current own-toy picker is separate. |  |
| Auto Explode Target (`AutoExpTarget`) | 37915 | Existing/adapted counterpart | `BlitzExplodeEnabled` |
| Noclip Toys (`GroupNoclip`) | 38046 | Existing/adapted counterpart | `PackGroupNoclip` |
| Highlight Group (`GroupHighlight`) | 38054 | Existing/adapted counterpart | `PackGroupHighlight` |
| Affects you (`BreakPartAffectsYou`) | 38119 | Not imported: global part-break targeting modifier; existing part tools remain scoped. |  |
| Highlight Broken Parts (`HighlightBrokenParts`) | 38135 | Existing/adapted counterpart | `PackPartHighlight` |
| Coconut Forms (`CoconutFormsToggle`) | 38372 | Not imported: reference coconut formation rig; current local formations are not equivalent. |  |
| Break all Holdables (`DestroyAllHoldables`) | 38469 | Not imported: global holdable-breaking controller. |  |
| Player ESP (`PlrESPT`) | 38548 | Existing/adapted counterpart | `NicknameESP` |
| Server ESP [PCLD] (`PCLDESPT`) | 38593 | Existing/adapted counterpart | `BoxESPWhite` |
| Sticky ESP (`StickyESPT`) | 38641 | Existing/adapted counterpart | `PackStickyESP` |
| Blackhole ESP (`BlackholeESPT`) | 38670 | Existing/adapted counterpart | `PackBlackholeESP` |
| Enabled (`PlayerHighlightEnabled`) | 38725 | Existing/adapted counterpart | `PackESPHighlight` |
| Enabled (`NameESPEnabled`) | 38763 | Existing/adapted counterpart | `PackESPNameplate` |
| Bold? (`BoldToggleFF`) | 38791 | Existing/adapted counterpart | `DetailedESPBoldText` |
| Show Icon (`NameShowIconToggle`) | 38816 | Existing/adapted counterpart | `PackESPAvatar` |
| Smooth Movement (`SmoothPCLD`) | 38866 | Added/expanded in this pass | `PCLDESPSmooth` |
| Enabled (`PCLDNameEnabled`) | 38921 | Added/expanded in this pass | `PCLDESPLabels` |
| Bold? (`BoldTogglePCLDFF`) | 38949 | Existing/adapted counterpart | `PCLDESPFont` |
| Bold? (`BoldToggleFF2`) | 39117 | Existing/adapted counterpart | `PackWorldESPNames` |
| Disable Ragdoll Blur (`DisableBlurT`) | 39146 | Existing/adapted counterpart | `PrivateDisableBlur` |
| Third Person (`ThirdpersonT`) | 39160 | Existing/adapted counterpart | `PrivateThirdPerson` |
| Camera Noclip (`CameraNoclip`) | 39181 | Existing/adapted counterpart | `CameraClipFade` |
| Realistic First Person (`RealisticFirstPersonT`) | 39219 | Existing/adapted counterpart | `PrivateVisibleLimbs` |
| Realistic Water (`CustomWaterT`) | 39473 | Existing/adapted counterpart | `SourceRealisticWater` |
| Non-Swimmable Water (`NonSwimmableWater`) | 39492 | Existing/adapted counterpart | `PackNoSwimming` |
| Shaders (`ShadersT`) | 39596 | Existing/adapted counterpart | `PrivateShader` |
| Particles (`ParticlesT`) | 39737 | Added/expanded in this pass | `ResonanceParticles` |
| Boost FPS (`BoostFPS`) | 39831 | Added/expanded in this pass | `ResonanceFPSBoost` |
| Highlight Your Character (`ForcefieldChar`) | 39846 | Existing/adapted counterpart | `PrivateForcefieldCharacter` |
| China Hat (`ChinaHat`) | 39875 | Existing/adapted counterpart | `PrivateConeHat` |
| Toggle Custom Line (`EnableCL`) | 39907 | Existing/adapted counterpart | `PackCustomLine` |
| Grabbed Object Information (`GObjectInfo`) | 39917 | Added/expanded in this pass | `PackHeldInformation`, `ResonanceHeldHUD` |
| Custom Crosshair (`CustomCrosshair`) | 39928 | Existing/adapted counterpart | `PrivateCrosshair` |
| Toggle Custom Sound (`EnableCBHS`) | 40023 | Existing/adapted counterpart | `PackBlackholeSoundOn` |
| Toggle Custom Image (`EnableCBH`) | 40044 | Existing/adapted counterpart | `PackBlackholeImageOn` |
| Toggle Blackhole Staying (`EnableBHStaying`) | 40086 | Added/expanded in this pass | `ResonanceKeepBlackholes` |
| Custom Skybox (`CustomSkyboxT`) | 40308 | Existing/adapted counterpart | `PrivateSkyEnabled` |
| Enable Clouds (`CloudsEnabled`) | 40399 | Existing/adapted counterpart | `PrivateClouds` |
| Toggle (`AutoClicker`) | 40448 | Not imported: reference target-pose/autoclicker engine. |  |
| Independent Target Poses (`IndependentACPoses`) | 40456 | Not imported: depends on the reference target-pose engine. |  |
| Custom Pose Center (`CustomACPoseCenter`) | 40563 | Not imported: depends on the reference target-pose engine. |  |
| Smooth Click TP (`SmoothClickTP`) | 41140 | Existing/adapted counterpart | `PackSmoothClickTP` |
| Further Reach Line (`FartherReach`) | 41513 | Existing/adapted counterpart | `ExtendToggle` |
| Gradient Line (`GradientLineT`) | 41648 | Existing/adapted counterpart | `PackGradientLine` |
| Faster Escape (`FasterEscapeT`) | 41702 | Added/expanded in this pass | `ResonanceFasterEscape` |
| Sound Spam (`SoundSpamT`) | 41982 | Not imported: sound-spam controller; local audio filters are separate. |  |
| Auto-House Teleport (`autohouse`) | 41994 | Existing/adapted counterpart | `ToolAutoSaveHouse` |
| Auto-Slots (`AutoSlotsT`) | 42003 | Existing/adapted counterpart | `ToolAutoSpin` |
| Toggle (`AimbotToggle`) | 42016 | Existing/adapted counterpart | `PackAimAssist` |
| Always On (`AlwaysOnToggleAB`) | 42049 | Existing/adapted counterpart | `PackAimAlways` |
| FOV Circle (`FovCircle`) | 42062 | Existing/adapted counterpart | `PackAimCircle` |
| Toggle (`TriggerToggle`) | 42119 | Existing/adapted counterpart | `TriggerbotToggle` |
| Camera Tricks (`TriggerTricks`) | 42186 | Not imported: camera manipulation modifier for the trigger controller. |  |
| Silent Aim (`SilentAim`) | 42224 | Blitz-derived native grab-raycast counterpart | `SilentAimEnabled` |
| Ignore Whitelisted (`SilentAimIgnoreWhitelist`) | 42237 | Not imported: would bypass the current safety whitelist. |  |
| Selected Targets Only (`SilentAimTargetsOnly`) | 42246 | Existing/adapted counterpart | `SilentAimSelected` |
| Show FOV Circle (`SilentAimFOV`) | 42259 | Existing/adapted counterpart | `SilentAimCircle` |
| Auto-Claim Plot (`AutoClaimPlot`) | 42323 | Existing/adapted counterpart | `PackAutoClaimPlot` |
| Auto Whitelist Friends (`AutoWhitelistFriends`) | 42535 | Existing/adapted counterpart | `WhitelistFriends` |
| Toggle Whitelist (`WhitelistToggle`) | 42569 | Adapted: Arriva whitelist remains always enforced; no bypass master added. |  |
| Give Anti-Grab (`ImmunityAGToggle`) | 42591 | Existing/adapted counterpart | `WhitelistAssistGrab` |
| Give Anti-Kick (`ImmunityAKToggle`) | 42601 | Existing/adapted counterpart | `WhitelistAssistKick` |
| Give Anti-Explosion (`ImmunityAEToggle`) | 42610 | Existing/adapted counterpart | `WhitelistAssistExplosion` |
| Watermark (`WatermarkT`) | 42626 | Existing/adapted counterpart | `SessionWatermark` |
| Open Keybind Menu (`KeybindMenuOpen`) | 42636 | Existing/adapted counterpart | `KeybindOverlay` |
| Only Show Assigned (`OnlyAssignedKeybinds`) | 42645 | Existing/adapted counterpart | `KeybindAssignedOnly` |
| Unlock Mouse (`UnlockMouse`) | 42657 | Existing/adapted counterpart | `MenuKeybind` |
| Mouse-Lock (`MouseLockT`) | 42666 | Added/expanded in this pass | `ResonanceMouseLock` |
| Position Prediction (`PositionPrediction`) | 42724 | Existing/adapted counterpart | `BlitzPredictPlayer` |
| Direct Grab CFrame (`DirectGrab`) | 42733 | Not imported: direct-grab CFrame override. |  |
| Custom Cursor (`ShowCustomCursor`) | 42747 | Existing/adapted counterpart | `PrivateCustomCursor` |
| Master Switch (`NotificationMaster`) | 42836 | Existing/adapted counterpart | `NotificationMaster` |
