# Arriva Core Hub 2.5: additional transfers and tools

These additions adapt useful controls from the original Resonance to Arriva's current UI. They do not replace the current gameplay controllers.

| Where | Addition | Behavior |
| --- | --- | --- |
| Notifications → Event messages | Master switch and event filters | Enable/disable all hub notifications, or join/rejoin, leave, respawn, blackhole, and kicked-player alerts independently. |
| Notifications → Event messages | Editable event messages | Use `%player%`, `%event%`, and `%message%`. Blank restores the original message. Original `%kickedPlayer%`, `%leftPlayer%`, and `%rejoinedPlayer%` names also work. Templates apply to player event calls with player context. |
| Notifications → Notification history | Recent alerts | Refresh to see up to 50 recent alerts; select to read, replay, copy, or clear. Replaying does not add duplicate history. History stays in the current session. |
| Settings → Config profiles | Named settings | Enter a name to save/overwrite it, refresh the list, select a profile to load/delete, or copy the current settings as JSON. File APIs are required; a listfiles API is needed to populate the list. |
| World & Travel → Session tools | Rejoin | Save first, then rejoin the current server. A failed save stops the rejoin. You must execute the hub again after joining; this does not install an execution queue. |
| World & Travel → Session tools | Server sharing | Copy the current server ID or join link. |
| World & Travel → Session tools | Mouse controls | Unlock the mouse or restore control using the hub's existing mouse controller. |
| Player → Spawn bookmark | Save / return | Save the current position, return manually, optionally return after respawn, or clear it. The location lasts for this session. |
| Appearance → Session overlay | Watermark | Optional compact overlay with version, approximate FPS, data ping when available, and session duration. |
| KeyBinds → Keybind display | Shortcut overlay | Show assigned keys and their actions. Include unassigned keys if wanted, and check shortcut conflicts. |
| Protected Players → Whitelist Shuriken Appearance | Assistance shuriken highlights | Separate fill/outline HEX colors, transparency, and rainbow controls. Applies only to the assistance controller’s managed shurikens; previous body transparency is restored when disabled or cleaned up. |
| Chat: `!protect name` | Immediate whitelist | Resolve a display name or username, add its UserId to the manual whitelist, immediately apply protection, refresh the UI and queue saving. Use `!protect @username` to resolve by username; ambiguous names are rejected. |

The original reference provides notification switches/templates, config profiles/export, rejoin, saved spawn location, watermark, and keybind-list concepts. History, copy-server tools, and bounded respawn-return handling are companion additions.

Examples of event messages:

- Join/rejoin: `Welcome back, %player%!`
- Leave: `%player% dipped out.`
- Respawn: `%player% is back in action.`
- Blackhole: `%player% left near a blackhole.`

The original message is the default. Blackhole departure/proximity detection still does not establish a server kick.

Named profiles remain separate from `AutoSave`. Saving a named profile does not bypass failed-load protection on your automatic config. Profile names cannot contain paths, and `AutoSave` is reserved. Delete removes the selected profile and its backup. Clipboard export includes the current whitelist.

Spawn return waits up to 20 seconds after respawn for a free current character and, when enabled, Gucci confirmation. It avoids active interaction visits, flights, safe-zone loops, selected-player action loops, seats and holds. Turning the option off or clearing the bookmark cancels a pending return. Automatic return, the watermark, and the shortcut overlay default to off.

Target join and respawn alerts now use the shared event sound controls. Their old additional hard-coded sounds were removed so the notification master switch and event sound choices apply consistently.

Packet/line flooders and server-breaking features were not transferred. Shutdown remains absent. The existing Gucci spawner, controller, seven event-handler pairs, train/RunService fixes, plot/slot visit logic, and explicit/automatic-save protection were preserved.

Automated validation: full Luau compilation; mock checks of notification templates (including literal `%` text), master/event filtering, bounded history/replay, profile name/path validation, control initialization, profile save/load/delete callbacks, save-gated rejoin and teleport-failure retry, server link generation, spawn bookmark return and cancellation. Previous Gucci/save/visit and notification-type/color regression checks also pass.

In-game validation remains necessary for UI layout, file and clipboard APIs, Roblox teleports, sound playback, overlay placement, and physical respawn/Gucci behavior. No live server actions were performed during verification.

`!protect` does not enable assistance toggles or promise a shuriken attachment. Enabled whitelist assistance picks up the protected player using its existing character, plot, ownership and attachment checks.

All notifications share the same timer bar, entrance animation and tinted-background design. Under Notifications → Notification theme, Background transparency ranges from 0 (solid) to 1 (hidden). Background color tint at 0% keeps the neutral base color; 14% is the default. Text, icons, borders and timer bars stay visible. These settings save with your other controls and update existing cards.

See [Commands and protection startup](Arriva%20Core%20Hub%202.5%20commands.md) for the new ! prefix, Commands panel and leg-removal-only Gucci startup rule.

Manual and automatic slot spins now show a Slot winnings notification and a last-result label under Plots & Slots. Like the original, the amount comes from the selected machine’s Screen → SlotGui → CoinsFrame → CoinAmount display. The reader waits about a second and allows animated text to settle, parses the complete amount (including thousands separators), and does not block the return visit. Missing results are marked unavailable rather than guessed.

## Formations, ownership, NPCs and camera travel

- **Objects & Toys → Shape Settings:** choose Follow selected player under Formation center, then select Formation player. Existing shapes work with local decorations or your own eligible toys. The formation pauses when the player leaves, dies, or moves beyond 100 studs, and resolves their current character after respawn. It never collects their toys.
- **Objects & Toys → Own Toy Builder & Recovery:** Check selected group ownership reports local/unconfirmed assemblies. Recover nearby own-toy ownership handles the named group, or the selected toy when no group is populated. It requests at most 12 nearby assemblies, with at most two attempts each and a 30-stud limit. Rigs, seats, external assemblies, other movement controllers and reserved missiles are excluded. It does not teleport. Ownership recovery does not pause or restart Gucci. Cancel ownership recovery and `!stop` cancel the action.
- **Player → NPC Camera & Control:** Refresh NPC list, select an NPC, and enable View selected NPC. Steer my selected NPC requires a live NPC in your own toy folder with local ownership and no external/seated assembly. Controls are WASD/arrows, gamepad stick and Space/jump; touch buttons are provided. This uses the NPC's normal humanoid movement and does not teleport or freeze your character under the NPC. Losing ownership, removing the NPC, respawning or returning ends control and restores the camera, bindings and NPC walking speed. Steering pauses while typing.
- **World & Travel → Camera Travel:** Move to ground below camera checks for stable anchored ground/terrain, a destination within 512 studs, a free character and a current confirmed Gucci root when enabled. Move below NPC camera when exiting is optional and defaults off.
- **Commands:** `!camhere` moves to safe ground below the camera, `!npcreturn` exits NPC viewing/steering, and `!recoverbuild` runs the selected own-toy group's nearby ownership recovery. `!stop` also stops NPC control and ownership recovery while keeping protection choices.

NPC selection is session-only. NPC viewing, steering and exit teleport default off. Roblox must actually grant local NPC/prop ownership for movement to replicate; these controls do not guarantee the server accepts it. NPCs driven by game scripts may override humanoid movement.

Automated verification covers formation target/range/death/leave/respawn handling; NPC view/input/camera restoration and ownership-loss cleanup; camera ground, distance, interaction-lock and confirmed-Gucci-root gates; own-folder, anchored, external-connection and missile exclusions; and recovery cancellation/error cleanup. Full-script compilation and existing Gucci-order, command UI and slot-result regressions also pass. UI layout, touch/gamepad feel, NPC movement, ownership replication and camera travel still need in-game verification.

The latest [respawn and verification patch](Arriva%20Core%20Hub%202.5%20respawn%20fixes.md) restarts enabled protections for the new character and aligns the Gucci observer with the original setup checkpoint. Use !status to see exact pending setup and anti-kick details.

Latest correction: anti-kick and Gucci are independent. Gucci waits only for Anti Banana leg removal when enabled, including the active removal pass; unrelated protection and config callback completion are not startup barriers. Cancelled spawn callers no longer retain the same-character spawn mutex.


### Aura ownership and icons

Visuals, KeyBinds, Commands and Sound now have their own Lucide sprite icons. Assets are embedded metadata from the pinned Rayfield icon set; no icon library executes at runtime.

Player attraction/tornado and object attraction wait for observed simulation ownership before applying forces. Ownership requests stay within 30 studs, share a six-request-per-second budget, and use a two-second per-object cooldown. Objects awaiting ownership remain untouched. Object attraction uses BodyVelocity instead of local CFrame stepping and excludes humanoid rigs, seats, anchored assemblies and protected targets. Forces are removed when ownership is lost.

Creative shapes (including Tornado) use actual toys in your spawned-toy folder. The former local-decoration source is retired; saved source choices migrate to My spawned toys. Creative controllers also wait for ownership and release on ownership loss.

Validation: full-script Luau compilation and mocked ownership/cooldown/protection/loss checks passed, along with Gucci ordering, confirmation and cancelled-spawn-lock regressions. Roblox replication and appearance require in-game verification. Ownership uses isnetworkowner when available, otherwise the original ReceiveAge signal; server acceptance is not guaranteed.


### Original train, water and owner commands

- **World & Travel → Train → Destroy Train** ports the original train-seat/hamburger interaction. Gucci must be off. Occupied or unavailable train seats are rejected. Waits are bounded; cleanup restores the destruction threshold, removes the temporary hamburger and returns the current living character to its saved position (unless Gucci was enabled during the interaction). Completion means the interaction ran, not proof that the server removed the train.
- **World & Travel → Non-Swimmable Water** disables swimming for your character, following the original. Turning it off restores the previous swimming setting; respawn reapplies it if enabled. No actual Destroy Water or Remove Water feature was found in this reference. This does not delete water for other players.
- **Commands → Owner commands → Allow owner commands** exposes the previously hidden opt-in flag. Off by default. Enabling it permits the configured hub owner to bring, reveal, kill or kick this client and send announcements. Owner identity is still checked. Both ! and legacy : prefixes work, with repeated whitespace and @username matching supported.
- Active **Destroy Gucci (sit)** now checks nested Seat/VehicleSeat instances throughout the target's toy and plot inventories, covering Blobman, tractors, sleighs and toy trains. It also checks the target's existing SeatPart, including the shared train when attributable that way. Protected targets are excluded; it does not scan unrelated shared train seats. Your own Gucci still must be disabled for the original removal interaction to run.

Validation: full Luau compilation, mocked owner-command opt-in/identity/prefix/parser and recursive/plot-only/protected-seat checks passed. Train cleanup and tab wiring were checked statically; server-side train removal, swimming and vehicle interactions still need in-game verification. Existing Gucci confirmation and leg-only startup regression checks pass.


### Destroy Train readiness and spawn-lock correction

Compared the train sequence and spawn helper against Resonance. Omitted spawn frames now receive a valid position 15 studs above and 20 studs forward on the world Z axis from the character, matching the original default placement. Explicit frames, including Gucci's, are unchanged. Spawn InvokeServer requests run inside a bounded worker; the timeout starts before invocation and cancels the waiting worker, allowing the shared spawn lock to release. Cancellation of the caller also leaves a scheduled deadline to reap the invocation worker. This cannot force the server's CanSpawnToy flag or reverse a request already processed by the server.

Destroy Train waits for HoldItemRemoteFunction, DropItemRemoteFunction and RigidConstraint instead of requiring them to exist immediately. Hold requests retry every 0.15 seconds for at most one second until the left grip attachment confirms. All outstanding hold workers are cleaned by the train interaction's existing cleanup. Missing toy and missing component errors are reported separately.

Automated validation reproduced the old nil-frame and indefinite-remote lock failures, then verified default placement, unchanged explicit frames, timeout cancellation, later successful spawning, remote errors, delayed component replication and repeated grip acquisition. Full Luau compilation and existing Gucci, respawn, Anti Banana and plot-visit regressions pass. Actual train destruction remains unverified in Roblox.


### Anti Paint coverage correction

Rechecked the latest supplied Resonance source: Anti Paint immediately queries every BasePart named PaintPlayerPart, sets CanTouch false, maintains that property and handles newly added parts. There is no separate named radioactive, toilet or sickness filter in that source. Coverage for those effects depends on their shared touch parts.

Arriva previously used an incremental initial scan. Changing the poison toggle invalidated that scan; turning poison off while paint remained enabled did not start a replacement. This could leave existing paint/effect parts unprotected. Anti Paint/Poison now reconcile immediately with the original named-part query (GetDescendants fallback when unavailable), on either toggle change, on new parts, and once per second while enabled for late names/reparenting. The existing CanTouch enforcement remains. Overlapping modes share saved values, so disabling one does not release the other's coverage. No blanket character-touch, collision or query suppression is added.

Protection settings show the number of effect parts currently blocked and include Refresh touch protection. This confirms detected parts, not proof of immunity to server-triggered effects or effects already applied.

Automated validation reproduces the cancelled-scan bug and verifies immediate coverage, overlapping toggle changes, external CanTouch re-enable, late names, query fallback, exact baseline restoration and untouched ordinary interactions. Full script compiles; Gucci recovery and train/spawn regressions pass. Radioactive/toilet/sickness effects have not been verified in a live game.


### Cleaner Loop Players controls

Loop Players now has one **Loop type** dropdown and **Enable loop** switch. Types cover the existing kill, kill all, spam-grab kick, grab/blob kick, dual-hand blob kick, fling, Remove Gucci, bring all, Grab Anti Kick and Anti Anti Input Lag actions. Changing type while enabled stops other selected action modes before starting the chosen one. Individual legacy toggle rows are hidden, including from search. Their existing implementations, IDs, saved enabled values, targeting and protection checks remain in use.

The master switch reflects legacy shortcuts, target rejection and emergency stops. Loading an older config with multiple enabled modes reconciles to one mode after restore finishes. Loop type is saved; enabled state continues through the original IDs. No loop algorithm changed.

Validation: full Luau compilation and mocked selector transitions, stop-before-switch, rejected starts, emergency stops, legacy controls/configs and hidden-row checks passed. Existing command UI checks also pass. Layout has not been viewed in a live Roblox session.


### Shared teleport display, old kill loops, and Terrain water

The latest imported Resonance kill port is reverted. Kill and Kill all again use the previous implementation behind the single loop dropdown. Their self-teleport writes now use the common display mask; their target-action algorithm is unchanged.

**World & Travel → Teleport display → Mask teleports (except Z)** is enabled by default, as requested. Script-owned teleport writes, including temporary action visits, protections, travel commands/bookmarks and Loop TP, keep a local visual stand-in at the previous display position. Only the explicit teleport moves the real rig; the shared renderer does not continuously rewrite its root/head. Feature distance checks use the real position. Ordinary movement and joint animation are reflected in the display copy. Returning to the original position releases the mask; one-way travel remains hidden until Z, disabling the option, or **Show actual position**. This does not prevent server-side movement or mask server-originated teleports outside the hub.

Z cancels active plot/slot and private assist masks, clears shared masking, and uses its existing visible teleport/smooth-click handler. Gucci's existing ownership mask retains its own frame sequence and yields when cancelled. Stale callbacks and respawn/unload cleanup cannot clear a newer character's mask.

**Visuals → Water Appearance → Realistic Water** now performs the conversion seen in Resonance, rather than merely adjusting the existing surface: ocean part bounds, shifted down four studs by default, are filled with local Terrain water in 128-stud chunks; original ocean surfaces are hidden. Water height offset is adjustable. Each chunk is backed up before filling, and turning it off, cancelling a build, or unloading restores previous terrain and transparency instead of clearing existing terrain to Air. Terrain coordinates are checked and conversion yields after every chunk. The former 4,096-region cap has been removed so large oceans can finish converting. Appearance sliders and Non-Swimmable Water remain separate settings. Terrain changes are local to your client.

Automated validation: full-script Luau compilation; mocked display/physics split, logical positions, walking, return-to-origin, model pivots, stale callbacks, visible Z, disabling and respawn; Terrain conversion/offset, exact restoration and partial-build cancellation. Existing save/Anti Banana/plot visit, selector, command, Gucci, respawn, train, paint, whitelist, build/recovery, formation and QOL regressions pass. Rendering, replication, actual swimming and gameplay interactions have not been verified in Roblox.


### Blitz kill/Death Grab comparison

Compared the newly supplied Blitz loop-kill, Kill All and Death_Grab branches. Both Blitz kill loops use up to 51 heartbeat passes, request ownership before checking completion, move near the target after an unsuccessful pass, set BreakJointsOnDeath=false, then change Dead state/Jump/Sit. Arriva had 15 delayed passes, a different move/request order and omitted the death-joints flag. Those differences are corrected for selected/all modes. Selected mode also requires the target's Head as in Blitz. Attempts retain a two-second wall-clock bound, current-character/selection/whitelist checks and existing masked self-teleports. No Resonance kill helper is reintroduced.

Blitz uses the same enormous upward SkyVelocity, including the >500 velocity shortcut. This remains a Blitz-style method, not a guarantee against sky states or game movement kicks. Loop-created forces are now tracked independently, expire after two seconds, and clear on stop, death, target respawn, whitelist changes or unload. Existing forces belonging to another feature are not claimed or removed by the loop.

Kill Grab now follows Blitz Death_Grab: wait for confirmed player ownership, set BreakJointsOnDeath=false, change Dead state/Jump/Sit, and release the actual grabbed part when Dead state is enabled. Removed direct Health=0 and character BreakJoints calls, which could fake a local death without server ownership. Added delayed GrabPart/weld readiness, current real-grab detection on enable, duplicate-worker prevention, weld/character identity checks and cancellation on off/local respawn/unload. Protected players and fake grab models are excluded.

Automated validation reproduces the previous ownership-bypassing local Health write and verifies the corrected ownership gate, state/release behavior, already-active grabs, off cancellation, protected targets and weld retargeting. Loop tests verify pass cadence/death flag, retained force completion and stop/expiry cleanup. Full script compiles; shared masking, loop selector and save/Anti Banana/plot-visit regressions pass. Live kill replication and movement-kick behavior remain unverified.


### Remaining action-loop cleanup review

Reviewed the remaining loop modes using the supplied Blitz handshakes and Resonance BringPlayer/EatAntiInput behavior as references. The current Blitz-based Kill/Kill all and Kill Grab algorithms are unchanged in this review.

- Added optional per-run cleanup and worker registration to the shared loop lifecycle. Registered workers/resources stop immediately on off/replacement and local respawn; failed workers are cleaned and their UI toggle is turned off. Older callers keep their original running/ownsRun semantics. These action modes stop on respawn rather than silently leaving an enabled switch with a stale worker. Protections are unaffected.
- Spam-grab kick now cancels its worker and restores only its bound character's saved position. Grab/blob kick restores its own saved blob position and target PlatformStand/Sit values. Dual-hand kick retains its existing hand sequence, but its per-run BodyPosition is tracked, whitelist-aware and cleaned on off/error/respawn; delayed steps cannot recreate it after cancellation.
- Fling retains the same angular-force mechanism. It now snapshots and restores exact collision values, respects current noclip, removes its force on target loss/off/error and restores only the same local character. It no longer creates a new Heartbeat connection per target attempt.
- Bring All now uses ownership confirmation followed by three short whole-character pivots, velocity reset and grab release, following Resonance's BringPlayer pattern. It does not freeze the camera, return to an unrelated hard-coded coordinate or leave a permanent BringBody. The one-shot Bring helper's temporary mover is also tracked and expires after 0.35 seconds.
- Anti Anti Input Lag examines holdables physically connected to the selected character's arms/hands, following Resonance's attached-item targeting. It skips your own toys and protected objects. Removed the global hamburger scan and per-enable DescendantAdded listener. Requests are bounded and selection/character/protection are rechecked before dropping.
- Grab Anti Kick now refreshes SetNetworkOwner at use time and binds its worker to the loop lifecycle.

Automated validation: full Luau compilation; mocked exact collision/noclip restoration, Fling target loss and respawn, confirmed three-frame Bring All without persistent movers, protected-target exclusion, attached-item scope/off/timeout/selection changes, dual-hand delayed handshake cancellation and error cleanup. Existing masking, Terrain water, loop selector, commands, Gucci and Blitz kill regression checks pass. Live remote acceptance and gameplay outcomes are unverified in Roblox.


### New loop modes: selected Bring and own-toy recovery

Two modes are added to the existing Loop type dropdown:

- **Bring selected** rotates through selected players, confirms ownership, and uses the short three-frame bring/release sequence. The destination follows your current anchor between attempts. No selection means no action; protected or invalid targets are skipped. Stop/respawn cancels the worker, releases its requested grab ownership and restores only the same local character.
- **Own toy ownership recovery** repeats the existing nearby recovery routine at a three-second polling interval. Choose a toy or named group under Objects & Toys → My Toy Manager and Groups. Only eligible assemblies in your own spawned-toy folder, within 30 studs, are considered; a transaction handles at most 12 assemblies with up to two requests each. Rigs, seats, external assemblies, other active movement controllers, missiles and Gucci's reserved vehicle remain excluded. It never teleports.

The own-recovery mode has a narrow exception to the free-character action-loop gate so it does not block itself; other active action loops still block it. Selection changes are rechecked before each request. Stopping cancels pending recovery and releases any build pause it owned. Both modes use existing saved IDs/selector lifecycle and are mutually exclusive with the other dropdown modes.

Validation: full Luau compilation; mocked selected-only Bring/release, stop and protected-target checks; recovery cadence/off/respawn; own-loop gate exception and other-loop blocking; current selection validation and build-pause release. Existing selector and own-toy eligibility/range/cancellation/error checks pass. In-game ownership acceptance and gameplay results remain unverified.


### Stability pass: water, Heavy Blobman, masking and UI

- **Auto Reset is unchanged.** Its correction-event block matches the previous version byte for byte. It still responds to the game's Flying notification using the same settings/counters. No suppression of loop-generated corrections was added.
- The old persistent shared root/head mask was replaced because repeated physical rig rewrites could interfere with movement. The new shared display uses a non-colliding, non-queryable local avatar copy, mirrors joint animation, preserves normal movement and restores camera/visibility on return, Z, disable, respawn and construction failure. Display construction respects realHrp-based body joints. NPC tools ignore the display. Appearance backups read the original visibility rather than temporary hiding. This removes a concrete movement/visibility conflict; it does not establish that every possible Flying flag or invisibility effect is resolved.
- **Z / Click TP:** removed the 512-stud feature distance check; uses Roblox's 15,000-stud maximum ray reach. It still requires a real collidable surface, rejects empty sky/nonfinite hits, validates the final offset position, and maintains a void guard even when the destruction height is NaN or temporarily lowered.
- **Realistic Water:** removed CopyRegion/PasteRegion dependencies. Water now backs up via ReadVoxels and restores via WriteVoxels; originally empty chunks use compact Air restoration. Conversion yields after each chunk; restoration yields in small batches. Flat surfaces hide before filling, late ocean loading/replacement is handled, appearance-hidden surfaces remain eligible, and Terrain transparency is made visible when custom water appearance is off. Turning it off restores terrain, surface opacity and appearance baselines correctly. The removed region-count cap stays removed.
- **Heavy Blobman:** uses Blitz's BodyPosition idle hold with zero force while moving and a fresh anchor on idle/teleport. It requires actual Blobman seating and clears on seat exit, off, flight or respawn. The previous AlignPosition hold is removed.
- **X hides the menu**, leaving the script running. Menu key reopening remains available; explicit unload remains separate.
- The nearby-blackhole departure alert now displays **@username has been kicked from the server.** The underlying proximity-based trigger is unchanged; it does not provide an authoritative disconnect reason.
- **Grab Anti Kick** and **Grab Anti Input** are ordinary checkboxes under Loop assistance, outside the Loop type dropdown. They can coexist with one player action loop, idle without one, and retain enabled intent across respawn. They do not count as mutually exclusive action loops or block unrelated tool gates.

Automated checks: full Luau compilation; display/camera/visibility/error cleanup without per-frame real rig movement; distant Z/solid/sky/void/NaN guards; voxel water, large conversions, empty/occupied restoration, streaming and appearance overlap; Heavy Blobman seating/movement/teleport cleanup; unchanged Auto Reset, X handler and message text; assist independence/respawn/off; existing loop, kill, own-toy recovery, selector, Gucci, train, command and notification regressions. In-game rendering, actual water appearance and server acceptance remain unverified.

### Water performance and display pose follow-up

Resonance uses 128-stud fills and a roughly 4 ms yield budget, without voxel backups. This version retains backups to restore existing terrain, but limits conversion to one chunk per frame. Completed surfaces and identical chunks are cached; streamed additions no longer restore/rebuild the ocean. Chunk order starts nearest the camera on each axis. No region-count cap is added.

The teleport display anchors every copied part and copies source poses explicitly instead of simulating copied character joints. Missing source parts are hidden. Auto Reset is unchanged.

Automated checks cover full compilation, water cancellation/restoration and duplicate streaming, and display anchoring/cleanup without per-frame real-character movement. Actual FPS, terrain rendering and the reported split-character symptom still require in-game verification.

### Resonance parity replacement (supersedes previous water/display notes)

Realistic Water uses the attached Resonance's fn21–fn24 algorithm: 128-stud chunks, a 0.004-second Heartbeat yield budget, the original -4 height offset, original visible-surface selection, and FillRegion(Air) on removal. Voxel backups, per-chunk yields, chunk caches, streaming rebuild callbacks and the terrain-transparency override are removed. Turning it off clears the converted regions rather than restoring earlier terrain contents, matching the reference.

Teleport masking uses Resonance's root-only ClientVision sequence: maintain independent visible and destination frames, sample normal visible movement at Heartbeat, apply the destination for the action, then restore the visible frame before the camera render step. The cloned stand-in, copied joints, visibility overrides and CameraSubject replacement are removed. Hub adapters retain enable/off controls, return/respawn cleanup, broader teleport coverage and the visible Z exception. Auto Reset is unchanged. The reference itself scopes this helper to individual actions rather than all teleports.

Validation: full compilation; mocked direct water fills/Air cleanup, cancellation and budget yielding; mocked root-only Heartbeat/render ordering and return/off/respawn cleanup; direct comparison of water function bodies after adapting Workspace naming. Actual FPS and rendered character behavior remain unverified in Roblox.

Readable-reference correction: teleport requests update the destination only; they no longer overwrite the visible sample or immediately move the root during the render phase. Repeated destination changes and ordinary visible movement are covered by mocked ordering checks. Full compilation passes; Auto Reset and the reference water implementation are unchanged. Live rendering and server-side results require Roblox verification.

Remove Gucci is a separate checkbox under Loop assistance alongside Grab Anti Kick and Grab Anti Input. It is excluded from the loop-type dropdown, primary-loop counts and loop enabled/disabled notices. Its worker waits while no player action loop is active; stopping/switching the primary loop preserves the assist preference. The active source controller uses shared cancellation, current-character position cleanup and assist respawn restart. Automated compilation, selector visibility/coexistence and assist lifecycle checks pass; live gameplay is unverified.

### Gucci notification and retry comparison

Removed the observer-added RebuildRequired flag and its deletion condition. Clearing a confirmation now leaves vehicle reuse/deletion to Resonance's original controller decisions. Retry/verifying status messages no longer clear or override a live current-character proof; actual controller cleanup still invalidates it. Cleanup for an old/dead character does not emit an interruption warning. Anti Banana's temporary Gucci pause remains unchanged.

Validation: full Luau compilation; controller comparison against the attached readable Resonance (control-flow tokens, literals and branches, with renamed identifiers/passive hooks accounted for); existing original-source parity and ownership/proof checks; mocked success/retry consistency, true interruption warnings, silent old-character cleanup and absence of observer-forced rebuilds. All seven original event-handler pairs and the spawner are unchanged. Actual respawn/retry behavior requires in-game verification.

Movement-command readiness now ignores enabled loop assists, matching auto-claim/slot visits, spawn return and recovery gates. All three assists can remain checked without blocking movement; actual active loops still block it. Full compilation and a mocked assist-only/active-loop/stopped-loop movement check pass.

### Break PCLD and PCLD ESP

Compared Break PCLD with readable Resonance: both perform two respawns and mark the final humanoid BrokenPCLD. The hub now requires each replacement character to be nonnil, validates its humanoid/current-character identity before proceeding and marking completion, and includes themed start/death/completion notifications. Toggle-off/unload cancellation remains in place. This is a cancellation-aware adaptation rather than a verbatim copy of the original spawned reset workers. The completion marker records the sequence; it does not independently prove a server-side detector result.

PCLD ESP replaces the former plain white box with a slim purple outline, subtle fill and a rounded dark distance label with a diamond marker. The saved BoxESPWhite toggle ID is retained with the label PCLD ESP. Labels, fill transparency and accent hex colour are configurable. Waiting detectors at Vector3.zero are hidden. Initial scans are incremental, updates run at 5 Hz, and off/stream removal/unload destroy adornments and release tracked children. Detectors and their assignments are not modified by the ESP.

Validation: full compilation; mocked two-respawn/nil-transition/idempotence/cancellation/missing-humanoid scenarios; mocked ESP duplicate prevention, waiting/label visibility and complete object cleanup. Auto Reset remains byte-identical. Visual appearance and the server-side Break PCLD outcome require Roblox testing.

### Resonance Anti Grab types

Added Anti Grab type under Grab & Seat Settings with Normal (default), No Ragdoll, Anti-Kill, and Escapes Anything, but buggy. The existing Anti Grab toggle and saved ID remain. For the R6 torso rig used by the reference, the controller now follows Resonance's held recovery: disable automatic rotation/neck requirement while recovering, zero root velocity, maintain and steer the torso position, preserve intentional teleport destinations, repair disconnected limbs/collisions, stop the grab animation and mute its scream. Struggle is requested at 30 Hz while held; Normal requests ragdoll 0, Anti-Kill requests 0.11 and sits, and the other two skip that request. Escape mode uses the existing tractor escape helper initially and every two seconds, with no overlapping attempts. That helper now checks current character/cancellation and cleans up its own connection/toy on exit or error.

This is a lifecycle-aware adaptation, not a verbatim replacement of the entire Resonance script: release, off, mode changes, death, respawn and errors stop the render connection and restore captured rotation, seating and collision properties. RequiresNeck is restored only when a live enabled Neck exists (or its original value was false), to avoid killing a neckless character. Existing deliberate-seat, safe-zone and Gucci setup gates remain. Unsupported rigs or ownership-only signals retain the previous bounded fallback. Stop Anti Grab recovery turns the toggle off and releases it. Existing optional post-release movement recovery remains separate.

The adjacent Anti Blobman, Network Ownership, Sticky, Void, Explosion, Burn, Paint, Banana and Snowball protections were already present and are retained. No additional copy of those controllers is started. Gucci, its spawner/event handlers and Auto Reset remain unchanged.

Validation: full compilation; mocked all four modes, exact ragdoll arguments, extra-escape retry interval, intentional teleport forwarding, zero-facing fallback and release/respawn/error cleanup; existing shared teleport and Gucci controller parity/ownership tests. Live escape acceptance, movement feel and protection effectiveness require Roblox testing.
