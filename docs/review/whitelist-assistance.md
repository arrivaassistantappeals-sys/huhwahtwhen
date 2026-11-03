# Whitelist Assistance

This is a focused paste-in component, not a complete hub or an external loader. The production Lua/TXT files are unchanged.

1. Open `whitelist-assistance.lua` beside this document and copy the entire file.
2. In your full hub, find the exact comment `-- Register every saved control before loading settings.`
3. Paste the component immediately ABOVE that comment, outside any other function. Do not remove the comment or replace an existing section. Paste it only once.
4. Keep the same full updated source in your Lua and TXT copies.

The new controls appear under Protected Players → Whitelist Assistance. They start off and use existing manually whitelisted players plus confirmed, unexpired friend results when friend whitelisting is enabled. Pending/failed friend checks are excluded. Dead players and players inside plots are skipped.

- Anti-grab restores the last observed unheld position only after the helper's network ownership is confirmed.
- Anti-explosion uses the source's nearby `Part` heuristic and the same ownership-gated restoration. It is best effort and can also observe ordinary nearby part creation.
- Physical anti-kick spawns a separate managed NinjaShuriken for each eligible player, up to the configured limit. Active attachments are counted only after the actual sticky weld is observed.
- Enable Allow brief assist visits if you want distant ownership attempts to visit and return automatically. This is opt-in; it will not move you while seated, held, flying, in a safe-zone loop, or running conflicting action loops.

This does not prevent Roblox server/admin kicks, grant server-side immunity, or guarantee ownership requests are accepted. Live Roblox testing is still required.

Validation: the standalone component and a staged copy of the current full hub compile; 195 automated tests pass, including 10 targeted assistance regressions. Ordinary hub targeting/whitelist guards are not changed. Defensive network calls are scoped inside this component to currently trusted players' current roots and its own managed shurikens.
