# Commands and protection startup

This revision starts from the uploaded Arriva Core Hub 2.5 rollback file. It restores that file's synchronous Gucci callback pairs; the later deferred-callback patch is not included. The working spawner and seven seat/character event-handler pairs are unchanged from the upload. The uploaded Shutdown flood button is removed.

Gucci starts last:

1. Saved passive values and other enabled-protection callbacks are applied first.
2. The loader waits for callback completion, not merely for tasks to be launched.
3. Gucci waits for tracked initial protection-worker passes, settings restore, a 0.75-second settling period, and any older Gucci worker to exit.
4. Changing a protection pauses the current Gucci setup while keeping the user's toggle enabled. It queues one restart after the change settles. Disabling Gucci cancels that request.
5. After respawn, the coordinator waits for a live current character, a short respawn grace period, and protection setup before requesting Gucci again.

Anti Banana's cleanup and the older respawn listener now request Gucci through the same coordinator. Repeated requests do not reset an already active confirmation. Changing the Gucci vehicle and enabling Train mode also follow this ordering. The original Gucci success checks remain in place; queueing a start is not a claim of successful setup. An asynchronous game or server operation can still fail or wait. Use `!status` to inspect the current state.

The empty Follow Player dropdown selection is handled without calling `FindFirstChild(nil)`. The single-result `select` fix and failed-config overwrite protection are retained.

## Commands panel

Open **Commands** in the sidebar or type **`!cmds`** / **`!help`**. Search the browser, select a command to read its description and populate the command field, replace example arguments, then click **Run command**. Output and errors appear in the panel rather than notification popups. The last ten output messages are retained in this panel. Search and command input are not stored in config profiles and never run during config loading.

All local chat commands now use `!`; the old `:` prefix is ignored. Matching supports display names, partial names and `@username`. Ambiguous player matches are rejected.

| Command | Action |
| --- | --- |
| `!cmds`, `!help` | Open the Commands tab. |
| `!protect name` | Immediately add a resolved player to the whitelist and queue saving. |
| `!unprotect name` | Remove manual protection. Automatic friend protection can still apply. |
| `!whitelist` | List manual whitelist entries. |
| `!gucci on`, `!gucci off`, `!gucci restart` | Enable, disable, or cleanly queue Gucci again. |
| `!status` | Show Gucci phase, setup-job count, settings restore and action-loop count. |
| `!protections` | List enabled protection toggles and their control IDs. |
| `!protection Anti Banana on` | Change a uniquely matched protection label or control ID. Use `off` to disable. |
| `!stop` | Stop player action loops, character/vehicle flight and follow. Keep protection choices. |
| `!select name`, `!add name`, `!remove name`, `!clear` | Manage selected players. |
| `!to name` | Teleport near a player while your character is free. |
| `!fly on`, `!fly off`, `!unfly` | Control character flight. |
| `!flyspeed 50` | Set character flight speed (5–1000). |
| `!view name`, `!unview` | Spectate or restore your camera. |
| `!menu on`, `!menu off` | Show or hide the menu. |
| `!save` | Explicit manual save. |
| `!load` | Load AutoSave with Gucci ordered last. |

Automated checks compile the full script and exercise callback ordering, yielding setup, source-worker first passes and failures, old-worker exit, cancellation, respawn, stale restore records, command parsing, the command UI, player matching, save flags and preserved protection choices. Preservation checks compare the spawner and all seven callback pairs with the uploaded rollback base. Previous save/Anti Banana/plot-visit, notification, whitelist and session-tool regressions are also checked.

In-game verification is still required for actual Gucci setup, ownership and replication, interaction with the game's other character scripts, GUI layout and respawn behavior. The original parenting-warning behavior may remain because the uploaded event timing was restored. A passing mocked test does not establish that a Roblox server accepted the setup.
