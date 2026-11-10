# Protection audit against supplied Resonance v2.9

Scope: static comparison of the beta protection modules against the uploaded
Resonance source, plus mocked lifecycle tests. No live Roblox/executor session
was available. This is not certification of server acceptance or complete parity.

| Protection | Finding / disposition |
| --- | --- |
| Anti Blobman | Uses Resonance's RootAttachment substitution and mass repair. Fixed original Massless value persisting after disable by moving it into this protection's cleanup state. Character changes restore the old root before capturing the new one. |
| Anti Snowball | Activation checks and ragdoll/jump/collision operations follow the supplied flow. Fixed cleanup calling the unrelated movement noclip restoration function. Now snapshots/restores AutoRotate, jumping permission, body/ragdoll collision and physical properties, including originally nil physical properties. |
| Anti Banana | Retains leg-breaking behavior, ownership prerequisite, Gucci pause and bounded hip-height handling. Arriva restores hip height and manages Gucci suspension explicitly. No new change in this audit; destroyed limbs still require respawn. |
| Anti Sticky | Connected StickyPart filtering and grab behavior match the supplied approach, with own-toy/plot exclusions and Arriva remote safety checks. No new change. |
| Anti Void | Same high/low Y thresholds and origin recovery. Arriva exempts Gucci setup; Resonance additionally exempts its own Safe Platform radius. Those platform systems are not interchangeable. No new change. |
| Anti Burn | Arriva polls for the fire emitter/extinguisher, hides the overlay, and restores saved effects. Resonance uses character/emitter events and its extinguisher. Functional adaptation, not literal parity; no live extinguishing verification. |
| Anti Explosion | Same nearby-Part trigger, brief anchoring and momentum reset. Arriva preserves original anchoring and guards Gucci setup. No new change. |
| Paint / poison touch | Arriva maintains and restores local CanTouch state, handles added/removed descendants and periodically reconciles streaming. No new change. |
| Anti Object Fling / plot barriers | Local collision-group and barrier collision changes have dedicated restoration paths. No new change. |
| Anti Invis | Foreign-root mass/seat-weld repair has saved-state restoration and excludes the reserved Gucci seat. No new change. |
| Anti Lag | Arriva separates manual and automatic sources; intentionally differs from Resonance's automatic manual-toggle activation. Existing source-overlap regressions pass. |
| Anti Input / Network Ownership | Previous local changes retain the supplied hold/drop approach with replication waits, bounded calls and cleanup. See beta notes and anti-input-beta.mjs. |

## Remaining limits and follow-up

- Shared SNO is still an adaptation: one request, ReceiveAge confirmation, fixed
  timeout, and no caller timeout/cancellation argument. Resonance retries and
  checks IsPartOwner. This audit does not claim ownership parity.
- Correction-event Auto Reset binds its remote once at initialization. Late
  replication/replacement may leave it unbound; requires a dedicated binding
  lifecycle regression before changing it.
- Simultaneous protections can write the same character properties. Individual
  cleanup tests do not establish every combination of noclip, Anti Grab and
  Snowball is conflict-free.
- Shuriken Anti Kick and Break PCLD have complex server/respawn transactions.
  Their effectiveness is not established by this source audit.
- Anti Sticky removes touch transmitters; disabling cannot reconstruct deleted
  instances reliably. Anti Banana intentionally destroys limbs. These inherited
  destructive local operations differ from reversible property changes.

## Validation

Passed full beta Luau compilation; new mocked Blobman and Snowball cleanup
regressions; Anti Input delayed-component/call-lifecycle checks; existing
Anti Lag source-overlap, teleport-mask, and realistic-water suites.

New test: `node tests/protection-cleanup-beta.mjs` with `luau-web` installed.
