# Private build: regular kick methods

File: `dist/resonance-private.lua`, branch `codex/resonance-feature-port`.

This is a separate full hub build. The working `dist/resonance.lua` and `dist/resonance.txt`, and the earlier `dist/resonance-private-kick-test.lua`, are not replaced.

## Regular controls

Run the private build manually. Select your consenting friends using the existing Target selector, then open **Target → Private Kick**.

- **Kick method:** Grab-Drop, Grab-Release, Ownership or Void.
- **Apply kick to selected:** process the selected eligible players once, in order.
- **Loop kick selected:** repeat for the current selection until disabled.
- **Stop private kicks:** cancel the current action and loop, and release/restore its resources.

The test-only player picker and duration slider are gone. Non-Void methods perform bounded three-second attempts; Loop Selected repeats those attempts. Void performs the supplied one-shot far-coordinate move/upward velocity and releases ownership after 0.35 seconds. A completed Void intentionally leaves the target displaced. Cancellation attempts to restore the original character while it remains owned; cleanup cannot undo a respawn or disconnect.

Grab-Drop and Grab-Release require you to be seated in your own Blobman with an empty right hand. Ownership and Void do not need a Blobman. Start within 30 studs of the target; protected players and players inside a plot remain excluded. Existing whitelist settings are respected and are not automatically disabled.

## Original-style method settings

**Target → Kick Settings** controls the ownership method:

- **Kick Height:** default 15, range 0–28. Ownership uses the upload's world-space ring with radius 10 studs at this height.
- **Delay Mode:** Normal releases ownership on the next frame; Faster but worse schedules the release after 0.2 seconds. Delayed callbacks are cancelled/guarded when an action stops.
- **Loop Ragdoll:** enabled by default. Uses the supplied `PalletLightBrown`/SoundPart approach, with at most one helper worker per action. It requires the toy to be available and ownership confirmed; temporary forces and the helper toy are cleaned up.

**Blobman → Kick Settings** controls Grab-Drop and Grab-Release:

- **X Offset:** default 0, range −5 to 5.
- **Y Offset:** default 25, range 10–40.
- **Z Offset:** default 0, range −5 to 5.
- **Net Owner Spam (Grab-Drop):** disabled by default; adds grab/drop ownership requests at the bounded action cadence. Grab-Release includes its own ownership/ragdoll step.

Height and offsets update the active hold position when changed. These method settings are saved in the private build's configuration. They do not change the Void destination or its 0.35-second release timing. This restores the listed controls; hidden-property improvements, anti-kick-removal controls and server-wide flooding are not imported.

## Callable functions

The hub uses the same functions as its UI. They are available as `Hub.privateKick` internally and `getgenv().ArrivaPrivateKick` externally while this build is running:

```lua
local kick = getgenv().ArrivaPrivateKick
local friend = game:GetService("Players"):FindFirstChild("FriendName")

kick.GrabDrop(friend)
kick.GrabRelease(friend)
kick.Ownership(friend)
kick.Void(friend)
kick.Kick(friend, "Void") -- explicit method, or omit to use the current menu choice

kick.ApplySelected()
kick.LoopSelected()
kick.Stop()
kick.IsBusy()
kick.IsPrivateServer()
```

The example lists available calls; run only one action at a time. A `true` result means an action was accepted for processing, not that a disconnect occurred. Direct function calls cannot compete with an existing selected-player batch or loop. The API is removed when the build unloads.

## Private-server and friend checks

The entire build refuses to start unless a readable, nonempty `game.PrivateServerId` verifies a private/reserved server. It checks again before and during each kick. Missing or inaccessible client metadata is rejected, even if you know the server is private; there is no manual override. The existing running hub is left alone if verification fails.

Every action checks Roblox friendship before sending target actions. Repeated loop attempts recheck friendship. Protected players remain excluded; failed friendship checks, respawn, target departure and protection changes stop the relevant attempt. Respawn stops the loop.

No server-wide flooding, hidden-property improvements, remote self-loader, server browser or auto-rejoin is added. These are the supplied targeted physics approaches, not server-authorized moderation commands; the live game's physics/validation determines whether they cause a disconnect.

## Settings

Normal private-build settings use `ArrivaCoreHub/PrivateKickConfigs`; whitelist writes use `ArrivaCoreHub/PrivateKickWhitelist.json`. They do not replace the working hub's files or the test build's settings. The selected method is saved. The new kick loop is excluded from saved settings and requires manual activation each session.

## Checks

The full build compiles with Luau. Tests cover callable methods, one-shot Apply, repeated Loop Selected, Stop, no automatic startup, private-server rejection, friendship checks, concurrent-call rejection, selection changes, respawn and cleanup. The previous test build and normal hub regression checks also run. Live Roblox kicks are not confirmed by these mocks.
