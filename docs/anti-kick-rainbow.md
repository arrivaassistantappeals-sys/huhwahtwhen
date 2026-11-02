# Anti Kick shuriken rainbow

The shuriken's visible appearance is updated independently of the Anti Kick ownership/sticking worker. A worker waiting for a detector, weld or ownership can no longer freeze the highlight's color.

The four duplicated worker styling blocks call the same appearance updater as the 20 Hz heartbeat. It targets only the current shuriken, reuses its Highlight, follows replacement models/highlights and disables the old highlight when the active model changes.

Fill and outline rainbow remain independent. Enabling either makes that rainbow highlight visible while Anti Kick is active without changing the saved manual Highlight checkbox. Turning rainbow off restores its latest static hex color and the manual Highlight preference. Transparency and static colors apply immediately.

The existing saved control IDs are unchanged. Saved Anti Kick highlight/rainbow toggles restore without the gameplay startup delay; gameplay features keep their configured delay. Animation does not request a settings write every frame. Cleanup stops appearance updates and disables the rendered highlight.

The ownership/sticking gameplay and Gucci confirmation logic are unchanged. Both production distribution files match. The full bundle compiles with Luau and 126 regression tests pass, including actual Highlight updates while the gameplay worker is idle, independent channels, model/highlight replacement, visibility, static-color restoration, alpha controls, saved restoration and cleanup. Live Roblox rendering still needs an in-game check.
