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

See [Commands and protection startup](Arriva%20Core%20Hub%202.5%20commands.md) for the new ! prefix, Commands panel and Gucci-last startup/reapplication order.

Manual and automatic slot spins now show a Slot winnings notification and a last-result label under Plots & Slots. Like the original, the amount comes from the selected machine’s Screen → SlotGui → CoinsFrame → CoinAmount display. The reader waits about a second and allows animated text to settle, parses the complete amount (including thousands separators), and does not block the return visit. Missing results are marked unavailable rather than guessed.
