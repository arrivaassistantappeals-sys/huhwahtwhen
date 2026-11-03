# Findings from the latest uploaded script

These changes are prepared against the user's pasted script, not automatically applied to the repository or production. The nearby runtime-stalls-fix.patch records the exact edits for review; storing or merging a patch file does not apply it.

## Reproduced failures

1. The Gucci adapter's wrapped RunService events intentionally disconnect when Player.Character changes. Three persistent Hub.connect heartbeat subscriptions inside the adapter incorrectly use that wrapper: low-FPS auto anti-lag, PCLD assignment tracking, and anti-kick appearance/rainbow. After respawn they stop updating and are not reconnected. Use originalRunService.Heartbeat for those three persistent subscriptions ONLY. Keep character-bound Gucci Heartbeat:Connect subscriptions on the wrapper so stale character workers still stop. Do not globally replace RunService across the script.
2. Whitelist acquire calls use toy and nil or record.char. In Lua this always evaluates to record.char when toy is truthy, because the middle result is nil. Both calls must use not toy and record.char or nil instead. Otherwise a friend's Head.PartOwner marker can be used while checking the helper shuriken when its own marker is unavailable.
3. The plot/slot coordinator and whitelist assistance each have a private movement lock, so their visits can overlap. A reproduced sequence moved the local root from 0 to a plot at 1000, then an assistance target at 200, and finally returned to 1000 instead of 0. The patch adds a shared Hub.interactionVisitLock token acquired before a visit, checked by the other system, and cleared by its owner on finish/cancel/respawn.

## Validation

The original uploaded file compiles; these are runtime/lifecycle defects rather than missing end statements. The staged fixed full file also compiles. Targeted reproductions verify persistent native callbacks survive respawn while character-bound callbacks still stop; assistance waits for an active plot visit and cancellation restores the original position; and missing helper-toy ownership does not inherit the friend's marker.

This does not establish that every reported in-game failure has been found. Use Performance -> Runtime diagnostics -> Show latest callback error and F9 errors to identify additional failures.

## Why Resonance's visits can look invisible

Its supplied tbl12.SNO helper repositions the local root but masks that movement locally: a render callback before camera processing restores the locally displayed root/head, while a Heartbeat callback uses the temporary position for the ownership interaction. Cleanup disconnects these callbacks and restores the saved transforms. It is render/physics timing, not evidence that the character never moved or that other clients cannot observe it. The current assistance adapter uses ordinary visible visits instead.
