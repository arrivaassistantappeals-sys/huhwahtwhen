# Commands and protection startup

This revision starts from the uploaded Arriva Core Hub 2.5 rollback file. It restores that file's synchronous Gucci callback pairs; the later deferred-callback patch is not included. The working spawner and seven seat/character event-handler pairs are unchanged from the upload. The uploaded Shutdown flood button is removed.

Gucci waits only for Anti Banana leg removal when that toggle is enabled. It checks both remaining R6 legs and the active leg-removal pass, then starts as soon as that pass finishes. It does not wait for anti-kick, unrelated protection jobs, unrelated saved callbacks, or a general settling timer. Toggling anti-kick does not pause or restart Gucci. Anti-kick runs independently of Gucci.

Gucci still needs a live current character and its previous controller worker to finish exiting; its actual weld/controller verification is retained. Disabling Gucci cancels pending startup. Selecting a different Gucci vehicle intentionally restarts that controller. The older respawn listener uses the same narrow start request.

A shared spawn request is still serialized while its caller is alive. If anti-kick or another caller is cancelled during a spawn, the dead caller's lock can now be reclaimed on the same character. The original request parameters and model-identification implementation are unchanged.

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
| `!stop` | Stop player action loops, character/vehicle flight, follow, NPC control and ownership recovery. Keep protection choices. |
| `!select name`, `!add name`, `!remove name`, `!clear` | Manage selected players. |
| `!to name` | Teleport near a player while your character is free. |
| `!fly on`, `!fly off`, `!unfly` | Control character flight. |
| `!flyspeed 50` | Set character flight speed (5–1000). |
| `!view name`, `!unview` | Spectate or restore your camera. |
| `!menu on`, `!menu off` | Show or hide the menu. |
| `!save` | Explicit manual save. |
| `!load` | Load AutoSave; Gucci waits only for requested leg removal. |
| `!camhere` | Move to stable ground below the camera. |
| `!npcreturn` | Exit NPC viewing and steering. |
| `!recoverbuild` | Recover nearby ownership for the selected own-toy group. |

Automated checks compile the full script and exercise callback ordering, yielding setup, source-worker first passes and failures, old-worker exit, cancellation, respawn, stale restore records, command parsing, the command UI, player matching, save flags and preserved protection choices. Preservation checks compare the spawner and all seven callback pairs with the uploaded rollback base. Previous save/Anti Banana/plot-visit, notification, whitelist and session-tool regressions are also checked.

In-game verification is still required for actual Gucci setup, ownership and replication, interaction with the game's other character scripts, GUI layout and respawn behavior. The original parenting-warning behavior may remain because the uploaded event timing was restored. A passing mocked test does not establish that a Roblox server accepted the setup.
