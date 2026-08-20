<!-- codex-status-router:start -->
## Adaptive model routing (global)

Before substantive work on every user request, use `$adaptive-model-router`.
The user's explicit model choice, reasoning choice, or routing opt-out wins.
The persistent default is `gpt-5.6-sol` with `xhigh` reasoning. Down-route only
clearly simple requests to one Luna/low child, or bounded moderate work to one
Terra/medium child. Keep substantive, ambiguous, multi-step, external-action,
architectural, debugging, security, and high-risk work on Sol/xhigh. If the skill
cannot be loaded or delegation is unavailable, continue on Sol/xhigh. Never
auto-use max/ultra or parallel children.

Always show exactly one `라우팅 결과:` line in every final response. Use `/model`
for a persistent manual switch.
<!-- codex-status-router:end -->
