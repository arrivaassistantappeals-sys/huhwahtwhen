# Reset recovery fix for the uploaded production source

This fixes three persistent callbacks being accidentally tied to the character present when the hub loaded, and a Gucci respawn readiness check that permanently returned after a five-second replication timeout.

## Option A: apply the patch

`respawn-recovery.patch` changes both `dist/resonance.lua` and `dist/resonance.txt`. It was generated against the uploaded 796,340-byte source. Check the patch against your actual files first; do not force it onto a different version. Merely uploading/merging a patch file does not apply it.

## Option B: paste the changes in GitHub's file editor

Make these changes to both runtime files, keeping their contents identical.

### 1. Keep three background callbacks alive after resets

Inside `-- Private adapter for the supplied Gucci state machine.`, locate these three anchors:

- `local lowFpsStarted=os.clock()`
- `Hub.connect(Workspace.DescendantRemoving,function(part)` immediately following `local function trackPCLD(part)`
- `local appearanceElapsed=0`

For each anchor, change the next occurrence of:

```lua
Hub.connect(RunService.Heartbeat,function(dt)
```

to:

```lua
Hub.connect(originalRunService.Heartbeat,function(dt)
```

Only those three registrations. Do not replace all Heartbeat uses: the imported per-character controller connections should still stop on reset. In particular, do not change any GUI library callbacks outside this adapter; `originalRunService` is local to the adapter.

### 2. Replace the Gucci CharacterAdded handler

Find the block beginning with:

```lua
Hub.connect(Player.CharacterAdded, function(char)
    local root = char:WaitForChild("HumanoidRootPart", 5)
```

It is immediately after the CharacterRemoving handler that sets `Hub.gucciRespawnReadyAt=math.huge`. Replace that entire CharacterAdded handler through its closing `end)`, stopping before `-- Local health alerts.`. Paste:

```lua
Hub.connect(Player.CharacterAdded, function(char)
    -- CharacterAdded may fire before either required part has replicated.
    -- Keep retrying this character; a later reset cancels this waiter.
    local readySince
    while Hub.alive and Player.Character == char do
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if char.Parent and root and root.Parent == char
            and hum and hum.Parent == char and hum.Health > 0 then
            readySince = readySince or os.clock()
            Hub.gucciRespawnReadyAt = readySince + 1.5
            if os.clock() >= Hub.gucciRespawnReadyAt then
                if Toggles.AutoGucciBlobToggle and Toggles.AutoGucciBlobToggle.Value then
                    if Hub.reportGucciStatus then Hub.reportGucciStatus("Starting") end
                    task.spawn(startAntiGucci)
                end
                if Toggles.AutoGucciTrainToggle and Toggles.AutoGucciTrainToggle.Value then
                    task.spawn(startAntiGucciTrain)
                end
                return
            end
        else
            readySince = nil
            Hub.gucciRespawnReadyAt = math.huge
        end
        task.wait(0.2)
    end
end)
```

## Verification

The resulting full uploaded source compiles with Luau. A regression harness using the actual wrapper and replacement handler checks that the native background callback survives a character replacement, delayed parts beyond five seconds recover, an obsolete character waiter exits, and a disabled Gucci control does not restart. These are simulated checks, not an in-game guarantee. Test several resets with each enabled protection and check the first F9 error if anything still stalls.

No spawn rates, remote permissions, targeting controls, or ownership checks were changed. This does not add a timeout to Roblox's InvokeServer; an independently stalled server invocation is still a separate possible failure.
