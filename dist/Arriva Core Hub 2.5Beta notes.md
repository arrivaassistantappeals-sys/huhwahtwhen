# Arriva Core Hub 2.5Beta

Experimental build on branch `2.5Beta`, based on stable commit `804cd70`.
The stable 2.5 script is unchanged.

The shared local presentation helper now samples the visible root only after a render.
This prevents successive Heartbeat callbacks without an intervening render from
replacing the visible frame with the action destination. Returning through the helper
also clears the swap using the requested return frame directly. Stale character
records no longer supply logical positions, and a different root starts a fresh record.
This is an adaptation of the shared helper, not a claim of one-to-one Resonance parity.

Beta labels and optional teleport reload point to the beta file/branch. Settings
continue to use the existing storage path. Auto Reset, Gucci spawner and event handlers,
and action-loop implementations are unchanged.

## Automated validation

- Full beta script compiled with luau-web.
- Regression: multiple Heartbeats before render fails against stable 2.5 and passes
  against beta. Repeated renders, helper return, disable and respawn cleanup also pass.
- Mocked settings, friendship requests, whitelist appearance, notification/profile UI,
  camera preferences and session tools checks passed.
- The regression is in `tests/teleport-mask-beta.mjs` and requires Node.js and the
  `luau-web` package. Run `node tests/teleport-mask-beta.mjs`.

## Runtime verification still required

No live Roblox/Xeno session was available. Test an ordinary temporary travel-and-return,
a permanent travel, masking off, Z travel, respawn, and camera movement at low FPS.
This build does not establish that every return path or in-game timing issue is fixed.

## Automatic Anti Lag follow-up

Low-FPS activation is independent of Force Anti Lag and line-burst activation.
It activates after two seconds continuously below the configured FPS threshold,
then releases after eight seconds of recovery. Disabling low-FPS Auto releases only
its own request. Automatic transitions do not change/save the manual checkbox.
An existing saved Force setting remains respected; switch it off once if the old
low-FPS behavior previously enabled it unintentionally.

`node tests/anti-lag-sources-beta.mjs` compiles the beta and mocks source overlap,
manual preservation, activation/recovery timing and automatic transitions without saves.

## Realistic Water loading follow-up

The generator waits for the ocean hierarchy and visible surfaces to load instead of
indexing a missing hierarchy once and stopping. If `QueryDescendants` is unavailable,
it filters `GetDescendants` for BaseParts. Each original surface remains visible until
its terrain replacement finishes. Failed generation attempts report an inline status,
record the error in runtime diagnostics, and attempt to restore surfaces/generated regions.
Toggle off/on to retry an actual generation failure. The 128-unit chunks and 4ms yield
budget remain unchanged; there is no repeated full-map conversion loop.

`node tests/realistic-water-beta.mjs` mocks delayed loading, unavailable query support,
failed terrain filling, retry, cancellation and yielding. Live generation/rendering and
performance in Roblox/Xeno remain unverified.

## Anti Input / Network Ownership protection

The hold/drop protection now waits up to two seconds for each required hold
component, following the supplied Resonance flow. Character/toggle checks after
each wait prevent stale work from issuing calls. Missing components and foreign
grip attachments still discard the toy.

Arriva retains one outstanding call per hold/drop remote, with a two-second local
worker timeout so a stalled call cannot block subsequent attempts indefinitely.
Disable, unload and toy replacement cancel tracked calls. Local cancellation does
not undo a request already received by the server. Original EndGrabEarly restoration
is retained. This is an adaptation, not verbatim Resonance parity; the shared SNO
ownership-acquisition helper is unchanged.

`node tests/anti-input-beta.mjs` (requires luau-web) compiles the complete beta and
mocks replication waits, pending-call timeout, disable/re-enable, repeated calls
and disabling during loading. These pass; live Roblox behavior is unverified.

## Spam Grab lifecycle

The acquisition-to-drag transition now requires an unanchored assembly with
ReceiveAge zero as well as the existing timer. Losing that local signal returns
to acquisition. ReceiveAge is local simulation evidence, not authoritative server
ownership or proof that a player disconnected.

Target humanoid Sit/PlatformStand snapshots and grab-line cleanup now follow
deselection, target/character replacement, disable and hub lifecycle cleanup.
Deselecting restores the local starting position immediately. Remote lookups
are bounded instead of waiting indefinitely. Existing target/whitelist checks
and target rotation remain.

`node tests/spam-grab-beta.mjs` (requires luau-web) compiles the full beta and
mocks timer-only rejection, ownership-signal loss, deselection, disable, target
respawn and original humanoid state restoration. Live Roblox verification remains
required.

### Spam Grab follow-up: brief grabs

The grab line is now released on the following Heartbeat instead of immediately
after creation. A missing local ownership sample pauses target movement for up
to 0.2 seconds before restarting acquisition; sustained loss still retries. This
avoids restarting on every isolated missing sample. Cleanup clears deferred
release state. The regression explicitly rejects same-Heartbeat release and
checks brief versus sustained ownership loss. These are source/mocked fixes,
not evidence of a successful server kick or full Resonance equivalence.

## Hold release / cleanup audit

Blobman's grab-loop cleanup now restores prior targets' Sit/PlatformStand values
on selection changes, deselection and character replacement instead of keeping
them until the complete toggle is disabled. Explicit cleanup releases the Blobman
handle and grab line, clears references and is idempotent. Returning the toy is
restricted to the original local character and the same active seat, preventing
a stale cleanup from repositioning a later toy/session. Grab-event lookup is
bounded so a missing folder cannot wait forever.

The Spam Grab lifecycle regression still passes. This pass changes release and
cleanup only; it does not port Target Kick, strengthen acquisition or establish
in-game hold stability.

`node tests/hold-cleanup-beta.mjs` requires luau-web and covers full compilation,
previous-target state restoration, explicit release, idempotency and stale
character/seat restoration rejection. Live Roblox verification remains required.
