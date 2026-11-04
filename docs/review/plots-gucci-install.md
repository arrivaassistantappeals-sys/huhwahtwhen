# Plot claims and slot spins with Gucci enabled

Gucci stays enabled. If enabled, these interactions wait for its verified successful setup, change your live character root's CFrame, perform the claim/spin/renewal, and return to the saved CFrame. The helper uses the root Gucci verified rather than a possible proxy HumanoidRootPart.

## Replace one block

Copy all of [plots-slots-replacement.lua](plots-slots-replacement.lua) using GitHub's Raw view.

In both `dist/resonance.lua` and `dist/resonance.txt`, replace starting **at and including**:

```lua
-- plot/slot utilities: coordinated self-only visits, requests and confirmation.
```

Stop **immediately before** this comment, keeping it:

```lua
-- Local presentation tools inspired by the supplied code’s Perspective settings.
```

Paste the replacement. No changes to the Gucci adapter, toggles or whitelist-assistance block are required.

The replacement uses ordinary visible visit-and-return movement. Camera masking is not added in this change. Existing guards still exclude dead, held, seated, anchored or flying characters and conflicting action loops. If Gucci loses confirmation during a visit, interaction requests stop; the helper avoids forcing a return against an active recovery controller.

The integrated uploaded script compiles. All 220 automated tests pass, including verified Gucci plot/slot visits, proxy-root selection and stopping requests after confirmation loss. Real server behavior needs testing.

These review files do not automatically change production. `plots-gucci.patch` is an alternative patch generated against the supplied upload for both runtime files; storing a patch in the repo does not apply it.
