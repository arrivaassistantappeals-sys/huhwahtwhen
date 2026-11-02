Anti Grab repair

The later defense adapter replaced the AntiGrabObsidian callback and attached a listener only to the IsHeld instance present at startup. This bypassed the main handler's character lifecycle, replaced/late held-flag detection, bounded freezing, and recovery controls. Its imported render loop also assumed an R6 Torso and could leave its active-state flag set after character teardown.

Removed that duplicate handler and its method selector. The original Defense toggle owns protection again. Struggle uses the no-argument signature from the supplied implementation. Respawn binding resets the attempt cooldown. A 0.3-second local velocity guard covers the transition from held to released, when a throw impulse may arrive; it stops on character changes, seating, safe-zone activation, disable, timeout, or manual release. Original anchored states are restored.

Validation: 12 self-contained Anti Grab tests cover retry limits, re-grabs, missing/replaced held flags, optional recovery, original anchors, release impulses, seating, disable, respawn, and the absence of another callback override. The 23 feature tests and menu organizer test also pass, as does Luau compilation. These use mocks and do not prove live server acceptance or guaranteed immunity to throws.
