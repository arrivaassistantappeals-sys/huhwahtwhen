# Production missile ownership retries

Files: `dist/resonance.lua` and `dist/resonance.txt`, branch `codex/resonance-feature-port`. Private kick builds are not changed.

- Unconfirmed ownership keeps the current toy reserved and automatically retries the claim. It does not pause the explosion cache or spawn another missile for the same ownership wait.
- Retry requests back off from 0.5 seconds to at most one per 2 seconds and stay within ownership range. Missing/erroring ownership-check functions can become available later.
- Previously ready explosives continue firing during preparation. A failed preparation releases only that operation, preserving unrelated ready entries.
- Other temporary preparation failures retry after 0.5 seconds, increasing to at most 8 seconds. Existing failed own models are reused before spending more toy points, including when the toy cap is full.
- Manual Retry does not clear a still-running preparation. Callback tokens prevent stale results from populating a newer cache request. Late spawn replies cannot replace the model already being prepared.
- Failed explosion sends keep the entry queued and retry; a temporarily missing BombExplode remote leaves the cache enabled.
- Mouse aiming uses the ray endpoint when aimed at the sky.
- Cancel, Stop, disabling missile actions, respawn and unload end the relevant work and release forces. Auto-retry does not turn a stopped toggle back on.

The uploaded Shutdown button was excluded: it sent a multi-megabyte payload and up to a million remote calls rather than performing an authorized server shutdown. The GitHub production base already omitted that routine.

Validation: the complete bundle compiles with Luau. The regression suite passes 104 tests, including delayed ownership, request backoff, retained ready cache, full-budget model reuse, typing, mouse aiming, retry-button behavior, failed sends, cancellation and respawn. These are deterministic client mocks, not live Roblox tests.
