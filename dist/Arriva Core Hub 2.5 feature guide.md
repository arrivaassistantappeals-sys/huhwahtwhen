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

**World & Travel → Teleport display → Mask teleports (except Z)** is enabled by default, as requested. Script-owned teleport writes, including temporary action visits, protections, travel commands/bookmarks and Loop TP, use one Heartbeat/render-step split. The simulation applies the requested destination while root/head render at the visible position. Feature distance checks use the logical destination. Ordinary walking is preserved separately. Returning to the original position releases the mask; one-way travel remains hidden until Z, disabling the option, or **Show actual position**. This does not prevent server-side movement or mask server-originated teleports outside the hub.

Z cancels active plot/slot and private assist masks, clears shared masking, and uses its existing visible teleport/smooth-click handler. Gucci's existing ownership mask retains its own frame sequence and yields when cancelled. Stale callbacks and respawn/unload cleanup cannot clear a newer character's mask.

**Visuals → Water Appearance → Realistic Water** now performs the conversion seen in Resonance, rather than merely adjusting the existing surface: ocean part bounds, shifted down four studs by default, are filled with local Terrain water in 128-stud chunks; original ocean surfaces are hidden. Water height offset is adjustable. Each chunk is backed up before filling, and turning it off, cancelling a build, or unloading restores previous terrain and transparency instead of clearing existing terrain to Air. Terrain coordinates and total chunk count are bounded. Appearance sliders and Non-Swimmable Water remain separate settings. Terrain changes are local to your client.

Automated validation: full-script Luau compilation; mocked display/physics split, logical positions, walking, return-to-origin, model pivots, stale callbacks, visible Z, disabling and respawn; Terrain conversion/offset, exact restoration and partial-build cancellation. Existing save/Anti Banana/plot visit, selector, command, Gucci, respawn, train, paint, whitelist, build/recovery, formation and QOL regressions pass. Rendering, replication, actual swimming and gameplay interactions have not been verified in Roblox.
