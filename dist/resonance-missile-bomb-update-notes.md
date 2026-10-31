# Missile and bomb update

New copy based on `dist/resonance.txt` at blob `af126799c8624dcfede4787609401667463d32ec`, branch `codex/script-download`. The original file and its reload/auto-execute URLs are unchanged.

## Changed

- Throw Bomb no longer depends on the moving `ToyNumber - 1` comparison. It subscribes before spawning, prefers a returned own-folder model when the server exposes one, and otherwise observes a newly added matching model. Existing missiles are excluded.
- Waits for the actual unanchored physics part rather than assuming it arrives with the model. Applies launch velocity immediately when that part is ready and keeps the existing 500 studs/sec default.
- Reserves the new model and its assemblies before launch so creative/object-attraction/build tools do not take it over during replication. Reservations and forces expire and clear on cancel, disable, respawn and unload.
- Six-second operation deadline, one pending spawn at a time, clean timeout/rejection handling. A failed operation stops the loop; it does not start a spawn-retry flood.
- Restoring or rebinding missile shortcut strings no longer fires the action. V/J/N shortcuts and their existing option IDs remain available.
- Added **Missiles & Explosions** tab: missile/firework selection, Throw/Explode action, one-shot button, loop toggle, delay, action-count limit, camera/mouse throw direction, speed and force duration. Loop defaults off, delay defaults one second, count defaults ten. It stops on toy limits or unavailable spawning. Explosion actions use the normal-size reference payload on the newly spawned own toy and request its destruction.
- Supplied Blobman, Objects & Toys and World & Travel icon choices are applied: bot, boxes and compass. Existing tab names/layout and other features are retained.

This ports a bounded missile/firework action loop. It does not copy Blitz's zero-delay mass-spawn path, arbitrary explosion variants or player-prediction controls.

## Validation

- Complete 10 KLOC source compiled with Luau.
- Full mocked GitHub-version hub UI initialized without warnings. Existing missile shortcuts, new controls and save serialization checked. Loop remains off by default.
- Executed actual controller in a mock: changing toy counter, immediate and late parts, nil-return ChildAdded fallback, duplicate suppression, normal explosion payload, interval/cycle bounds, hung/rejected spawn, toy limits, key-string restoration, respawn/disable/unload and force/reservation cleanup.

No live Roblox/executor test was performed. Client replication, network ownership, toy availability and server validation still determine in-game behavior; “immediate” means immediately after the required physics part becomes ready. Simultaneous spawning of the same toy by another independent script can be ambiguous when the server returns no model.

References were read as source only. No supplied external script, Orion loader, webhook or key system was executed or added.
