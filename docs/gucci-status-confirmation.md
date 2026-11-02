# Gucci status confirmation

Production files: `dist/resonance.lua` and `dist/resonance.txt` on `codex/resonance-feature-port`.

The previous Active notification was emitted immediately after the controller observed a seat-weld event. The controller could still fail ownership or seat release and retry afterward. Those seven early notifications are replaced by a per-attempt confirmation monitor.

## Active / setup complete

The current attempt must observe its seat-weld event and hold all required checks continuously for one second:

- The current character, live humanoid and root still match the attempt.
- The vehicle and its seat still exist and belong together.
- The humanoid has released the seat, is not sitting, held or ragdolled, and the controller's ragdoll-release stage has ended.
- No enabled seat weld remains and another occupant has not taken the seat.
- Non-Train methods retain vehicle-root ownership and the controller's required position force.

Train confirmation uses the same release checks without requiring a non-Train vehicle force.

Until then the label reports Verifying or Retrying. Success is announced once for the confirmed state, not once per frame. An Active status request without a matching current-character confirmation is downgraded to Verifying.

## Losing confirmation

Ownership loss, reseating, a held/ragdolled state or missing controller resources withdraws Active and resets the one-second window. Cleanup invalidates and cancels its monitor. Old attempts and old characters cannot later announce success for a replacement attempt.

This confirms client-observable setup state; it cannot prove server-side immunity or guarantee that a later grab/physics event will not break the setup. If a confirmed setup later fails, Retrying is the accurate status.

The gameplay seat/weld sequence is unchanged. Private builds are not changed. The full production bundle compiles, and 115 regression tests pass, including confirmation timing, transient release, ownership loss, cleanup, respawn, replacement attempts, Train handling and notification guards.
