# Gucci verification and protection respawn fixes

This patch addresses the stuck Verifying/Retrying state and protections failing to restart after respawn. It does not add gameplay features.

## Verification compared with the original

The added monitor previously required Humanoid.SeatPart to be nil, Humanoid.Sit to stay false, and the remote vehicle's ReceiveAge to remain zero continuously. The original Gucci sequence accepts its own seat metadata and does not continuously re-check ReceiveAge after its initial ownership step. Those extra monitor requirements can reject a state in which the original controller remains active.

The original ownership gate, spawn request parameters, model identification, seat/character handlers and controller sequence are retained. Each of the seven existing BodyPosition attachment branches now records that the original ownership/controller checkpoint was reached. The monitor requires that checkpoint, a live BodyPosition for non-Train modes, the observed/released SeatWeld, released ragdoll/held state, the current character, and a stable valid setup. An enabled SeatWeld, missing controller, another vehicle's seat, another occupant, or an old character still blocks confirmation. A public proof pointer cleared by a status listener is republished if the actual record remains confirmed.

This is an observer correction, not a forced-success timeout or removal of actual setup checks. The original gameplay method can still fail for game/server reasons.

## Respawn lifecycle

- Generic source protection workers are stopped and cleaned up on CharacterRemoving. Their enabled UI choices are kept. A new-character waiter replays those enabled controls once the current root and humanoid are ready. Initial setup jobs are new tokens; old work cannot clear a replacement job.
- Gucci's old start task and controller worker are explicitly reset at the character boundary. Cleanup errors cannot leave the running flag set. A cleanup error during an intentional pause does not turn off the user's Gucci choice. Gucci is still queued after the other protection setup jobs.
- The shared spawn mutex is scoped to a character and an individual request. A stale request cannot block the new character or unlock a newer request. The actual game-facing spawn implementation and parameters are unchanged.
- Anti-kick has a separate enabled intent, per-character worker token, cancellation and restart. It waits for the live root/humanoid/hitbox and refreshes StickyPartEvent when restarting. Transient worker errors are logged and retried after one second instead of silently setting the internal protection off while the UI stays on. An explicit user off remains off across respawn.
- Anti-kick's initial attempt participates in the setup barrier. Waiting for a missing remote or an ineligible plot is reported separately. Active status requires a weld attached to the current hitbox.

## Diagnostics and retesting

Re-execute the updated script before testing; a running older copy does not update itself. Keep the protections you want enabled, respawn, and inspect `!status` in the Commands tab. It now includes pending setup keys, the current Gucci verification blocker, the anti-kick phase and its last error. Toggle choices are retained through the respawn lifecycle.

Automated tests reproduce the old false-verification state and verify the updated checkpoint logic. They also cover stale source-worker cancellation/replay, anti-kick retry and respawn restart, explicit user-off behavior, starting with no character, Gucci cleanup failures, cancellation of pending starts, and stale spawn-lock completion. The full resulting script compiles. Preservation checks compare all seven original event-handler pairs and the actual spawn implementation against the pre-patch version. Existing save, Anti Banana, plot/slot visit and command UI regression checks pass.

These checks simulate lifecycle and replication state; they do not demonstrate that a live Roblox server accepted Gucci or a shuriken weld. In-game respawn/setup verification is still required.
