# Cache pause and toy-retention fix

Full hub copy based on `resonance-blitz-explosions-tp-update.txt`; includes its Blitz menu and unanchored-surface Z teleport change.

Fixed three confirmed code paths: cache-preparation failure previously switched Explode off and deleted the cache, changing explosive type also switched the toggle off, and fired models were forcibly deleted two seconds later.

- A preparation/ownership failure now pauses with a reason while Explode stays selected. **Retry cache** resumes explicitly; a pause does not continually spawn replacements.
- Ownership confirmation has a longer bounded wait, with limited retries against the same nearby toy, rather than immediately discarding it.
- Type changes preserve the enabled state and refill with the newly selected type. Old toys are retained.
- Automatic deletion is removed from cancellation, failure, stopping, unloading and the post-fire timer. Local forces/reservations are still released. The game's own detonation/despawn behavior can still remove toys.
- **Stop, keep toys** and **Delete this tool's cached toys** are separate actions. The delete action validates that tracked models are still in your own spawned-toy folder. It does not delete arbitrary existing toys.

Keeping spent or stopped toys can fill the normal toy-point budget. Clear them explicitly when needed. A paused ownership operation can leave its spawned toy nearby; this is deliberate retention rather than an automatic delete/retry cycle.

Luau compilation, complete mocked UI initialization and targeted controller tests passed: type-change toggle preservation, no automatic deletion, bounded ownership failure, paused-spawn suppression, manual retry, explicit deletion and force cleanup. This is not live Roblox/executor proof. If it pauses again, the status text contains the reason to diagnose next.
