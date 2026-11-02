# Private kick test build

Test file: `dist/resonance-private-kick-test.lua` on `codex/resonance-feature-port`.

The working `dist/resonance.lua` and `dist/resonance.txt` are unchanged. This is a full, separate copy of the current hub with an experimental **Private Kick Tests** panel in the Blobman tab.

## Starting a test

1. Join your private/reserved server and run the test file manually.
2. Open **Private Kick Tests**, refresh the player list if needed, and select a consenting Roblox friend.
3. Choose **Grab-Drop**, **Grab-Release**, **Ownership**, or **Void**, and a duration from 1 to 10 seconds for the looped methods. Void is a single action.
4. Stand within 30 studs. For the two Blobman methods, sit in your own Blobman and empty its right hand. Your friend must be alive, unseated, outside a plot, and not protected by the hub's whitelist.
5. Press **Run selected kick test**. Use **Stop kick test** to cancel early.

No test starts from a saved setting. The target is not saved. Existing player protections take precedence; the test never automatically disables the friends whitelist or manual protection.

## Private-server verification

As requested, there is no manual override. The file requires a readable, nonempty `game.PrivateServerId` before starting the hub, and checks it again during each test. Public servers, missing metadata and read errors are rejected before the current hub is unloaded.

Roblox may not expose this server-only information to the client/executor. In that case this build refuses to start even when you know the server is private. It prints: `Private server could not be verified. Test build was not started.` It does not guess or fall back to a public-server mode.

Friendship is checked with Roblox at the start of every attempt; failed or timed-out checks send no test actions.

## Experimental behavior

These are bounded adaptations of the supplied targeted physics methods, rather than server-authorized `Player:Kick` moderation commands. They cannot guarantee a disconnect on the current game server. The completion message means the attempt ended and cleanup ran, not that a kick was confirmed.

- **Grab-Drop:** Blobman grab followed by the drop remote.
- **Grab-Release:** Blobman grab followed by the release remote.
- **Ownership:** bounded ownership/drop cycles with the supplied position/orientation approach.
- **Void:** the upload’s `Void` and direct `Kick → Void` use the same helper. After confirming ownership, it moves the target’s character/root to `(0, 9e9, 0)`, applies upward velocity `(0, 9e9, 0)`, then releases ownership after 0.35 seconds. It needs no Blobman.

Attempts stop on timeout, respawn, target departure, selection change, lost ownership, missing parts or protection changes. Test-created forces and edited attachments, joints, collision values and humanoid properties are cleaned up/restored. A completed Void intentionally leaves the target displaced; immediately returning it would undo the test. Cancelling during its 0.35-second delay attempts to restore the original character while ownership remains available. A respawn or server disconnect cannot be undone by cleanup. They do not remove anti-kick toys, import hidden-property improvements, or include server-wide line/packet flooding.

## Separate storage

Test configuration writes use `ArrivaCoreHub/PrivateKickTestConfigs`; test whitelist writes use `ArrivaCoreHub/PrivateKickTestWhitelist.json`. Normal hub configuration files are not replaced. The build can read legacy whitelist entries for compatibility, but does not load the normal hub's feature configuration.

## Validation

The bundle compiles with Luau. Regression coverage exercises all four dispatch paths, the Void release timing and cancellation, private-server rejection, friendship failures, absent/foreign Blobman parts, ownership failures, cancellation, protection changes, respawn, lookup timeout and restoration. Live Roblox behavior still needs testing with your friend.
