# Resonance v4.0 — English menu fix

Use the included `dist/resonance.lua`: open it and run its contents.
It bundles all 275 feature modules and all 40 translated settings locally.

The upstream GitHub installer fetches the original version, so it does not run this English copy.

This revision fixes menu initialization order and Obsidian control definitions.
Feature implementations are unchanged. Menu registration was checked with mocks;
live gameplay behavior has not been tested.

Right Shift opens/closes the menu. Obsidian remains the external UI dependency.

License: MIT. Original project: https://github.com/a32435629-collab/resonance