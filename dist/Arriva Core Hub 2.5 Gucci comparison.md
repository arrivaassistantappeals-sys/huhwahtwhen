# Gucci comparison and correction

Compared against the uploaded Resonance v2.9 source, not an earlier Arriva revision.

| Area | Finding | Result |
| --- | --- | --- |
| Activation state machine (`fn24`) | Original branches and seven synchronous seat/character handler pairs were already present; Arriva added retry counters and an early confirmation worker. | Removed those additions. Normalized line-by-line comparison now matches the complete original after excluding only passive proof/seat hooks and the own-toy ownership adapter name. |
| Ownership acquisition | Shared Arriva SNO sent one request from the root position and waited for ReceiveAge. Original SNO used repeated heartbeat requests, the 1.593 grab offset and the game's PartOwner marker; distant targets used a temporary server approach with render restoration. | Gucci now uses a dedicated adapter implementing those original behaviors, with a 0.65-second acquisition window, original 31-stud distance threshold, 22-stud lower approach, predicted target position and cleanup. The adapter is restricted to your spawned-toy folder. Other tools retain their shared SNO implementation. |
| Completion reporting | Added worker began before ownership/body-position setup and imposed additional stability conditions. | Passive observer runs only at the original successful hold loops. Non-train runs require the actual BP on the vehicle root; train runs use the original successful weld checkpoint. The original validity predicate and observed weld event are required. No additional activation worker or stability delay. |
| Retry notifications | Alternating states and reminder toasts filled notification history. | Repeated states emit no reminders. Active/retry transitions have a 30-second per-state notification cooldown. Actual acquisition failure reports the missing PartOwner confirmation. |
| Unwanted seat protection | Only exempted CreatureBlobman by name, missing renamed vehicles, tractors, sleighs and trains. | Exempts the exact seat in the current-character Gucci record. Other unwanted seats remain covered. |
| Spawner, respawn and startup | Shared spawner and cancellation fixes are required by other protections. | Shared sourceSpawnImpl is unchanged. Retains worker cleanup, respawn handling, and the rule that only Anti Banana leg removal gates Gucci. Acquisition render/heartbeat hooks are cleaned on disable and respawn. |

## Validation

Automated: full Luau compilation; original state-machine comparison; mocked repeated ownership requests, PartOwner confirmation, ReceiveAge-only rejection, timeout/error cleanup, original completion publication, train proof; existing respawn, leg-only ordering, cancelled spawn lock, saving, Anti Banana and plot-visit regressions. Owner-command and aura checks also pass.

In-game: not performed. These checks establish source parity and mocked behavior, not server acceptance or successful gameplay protection. The previous added stability-verification regression is superseded by the original-completion tests.


## Follow-up: interference after the first successful activation

Found a concrete conflict between distant ownership acquisition and Arriva Anti Void: acquisition temporarily approaches the vehicle at high altitude, while Anti Void independently teleports the character to origin at Y >= 10,000. A mocked regression reproduces that conflict.

Added a current-character setup/acquisition marker. Anti Void, grab freezing/recovery, extreme-velocity recovery, character flight, Loop TP, explosion anchoring, movement-correction Auto Reset and the legacy TeleportPlayer helper yield during that window. Their enabled settings are preserved. The marker clears at original completion, cleanup, cancellation and respawn; ordinary safety behavior resumes afterward. Flight does not recreate its controllers during setup.

A previously confirmed non-train run now marks its vehicle for a fresh rebuild when invalidated. The next original loop discards that record through its existing cleanup and spawns a replacement, instead of repeatedly reusing a disturbed seat/controller. Shared map trains are never deleted through this rebuild flag. All seven original synchronous handler pairs are unchanged. This is one intentional additional retry condition beyond the original state-machine comparison above.

Gucci's current vehicle is reserved against the creative toy manager's move/delete operations, creative shapes and object attraction. Anti Invis avoids repairing welds on the reserved Gucci seat. Legacy teleporting preserves the exact Gucci seat even after the vehicle is renamed.

`!status` includes the last observed interruption: character changed/died, vehicle/seat missing, held, ragdolled, another seat/occupant, or an unspecified original validity change/stop. These describe observed state, not attribution to an attacker.

Validation: full-script compilation and mocked interference/guard-resumption, disturbance/rebuild, fresh completion, shared-train exclusion, reservation and stale-character tests passed. Original controller comparison (excluding documented integration hooks and rebuild condition), ownership helper, respawn, leg-only ordering, save/Anti Banana/plot visit, owner-command and aura regressions also passed. No live Roblox verification was performed.
