# Blitz-style explosion cache update

New complete copy based on the previous `resonance-missile-bomb-update.txt`. The original `resonance.txt`, prior copy and reload/auto-execute URLs remain unchanged.

## Matches the supplied Blitz flow

The simplified throw/explode loop menu is replaced by **Explosions Spam**, with these controls:

- Explode toggle.
- Explosion Type: Firework, Missile, Void, Ballon, Small Present, Big Present.
- Trigger Bombs hold shortcut, default F.
- Trigger Mode: Key or Automatic.
- Delay (Automatic Trigger Mode), 0–0.5 seconds.
- Amount to Explode, 1–20.
- Target: Spawn, Player or Mouse.
- Select Player and Predict Player Movement.
- FAQ explaining the target and trigger modes.

Explosives are prepared in a cache instead of spawning and detonating one immediately. The controller waits for the correct physical part and confirmed network ownership, stabilizes the toy and parks it at height 10000. At the configured amount, Automatic Spawn/Player mode drains the ready batch. Zero delay fires that ready batch together; a nonzero delay spaces its events. If toy points run out with a partial cache, it can fire that partial batch as the reference does.

Key mode uses the held trigger to fire cached toys. Mouse mode requires the held trigger even when Automatic is selected, matching Blitz. Player mode checks the selected player's current character, plot status and existing hub protection whitelist. Prediction uses velocity divided by 1.93. Mouse/prediction prepare an owned DiceSmall as the replicated aim-reference toy and use the reference's alternating BodyPosition pattern. Mouse targeting raycasts from CamPart when available, otherwise the camera.

The explosion request preserves the reference's minimal `{Hitbox, PositionPart}, position` arguments, with its toy-specific hitbox and physical-part mappings.

Original V/J/N one-shot actions remain. Throw Bomb retains the corrected counter-independent spawn/launch sequence. Existing tab icons, player selector behavior and other hub features remain.

## Intentional integration differences

This matches the reference's controls and cache/trigger behavior, not its entire code verbatim:

- One serialized preparation operation and a 50 ms scheduler replace five independent polling loops. New preparations are spaced at least 150 ms after completion; remote and ownership waits may take longer.
- No automatic toy purchase. Own the selected explosive and DiceSmall before using the modes that need them.
- New toys are reserved against the hub's object auras and build tools while cached.
- Stop, timeout, disable, respawn and unload disconnect workers and release forces. Cache cleanup deletes only models created for this cache. Fired models are cleaned up after two seconds if the game has not already removed them.
- Protected players and players in plots are skipped. Player choices refresh through the existing dropdown implementation.
- The default F may overlap the existing Free Mouse shortcut. The trigger is rebindable and is included in the hub's key-conflict report; existing keys were not silently changed.

## Verification

The full 10 KLOC script compiles with Luau. The complete mocked UI initializes without warnings and saves all new settings, with Explode off by default. Actual controller tests cover parked/reserved cache preparation, six toy mappings, minimal payload, automatic/key/mouse rules, focus release, protected/plot targets, prediction, delayed batches, ownership failure stopping without repeated spawns, original instant throw, respawn, disable and unload cleanup.

No live Roblox/executor validation was performed. Actual server validation, replicated toy structure, network ownership and game updates can still prevent the intended effect. This is not a claim that every mode is confirmed working in-game.
