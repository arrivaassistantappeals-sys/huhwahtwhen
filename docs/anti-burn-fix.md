Anti Burn overlay repair

The active worker skipped visual suppression when the emitter or extinguisher was missing. Once the fire emitter disappeared, its cleanup restored the overlay's previously captured Visible value, which could bring back the orange overlay after extinguishing.

ScreenOverlayGui.FireFade is now suppressed independently of the emitter and extinguisher while Anti Burn is enabled. Late/replaced overlays are picked up on subsequent worker ticks. Extinguishers are resolved from either poison hole and returned when no longer needed. Disable/unload only restores a previously visible overlay for an existing fire on the same living character; ended fires and old characters cannot resurrect it. Destroyed tracked visual instances are pruned.

Validation: seven mocked worker tests cover missing emitters/maps, missing extinguishers, ended fires, late/replaced overlays, both hole locations, death, and character replacement. The 12 Anti Grab checks and 23 feature checks pass, as does Luau compilation. Live Roblox visual testing remains necessary.

Extinguisher appearance follow-up: both poison-hole ExtinguishPart trees are hidden locally for the entire hub session, independently of the Anti Burn toggle. Parts use LocalTransparencyModifier; decals/textures and GUI images use transparency; surface/billboard GUIs are disabled. Property listeners reapply hiding if another script resets it, and workspace events cover late/replaced parts and visuals. Original values are restored when objects leave the workspace or the hub unloads. Unrelated map parts remain untouched. Eight Anti Burn tests now pass, including visual suppression, late loading, property resets, and restoration.
