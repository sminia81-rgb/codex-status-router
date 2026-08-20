---
name: adaptive-model-router
description: Keep Codex on GPT-5.6 Sol/xhigh for substantive work and automatically down-route only clearly simple requests to cheaper GPT-5.6 models. Honor explicit model choices and report every routing decision. Use before every user request unless the user disables routing.
---

# Adaptive Model Router

Default to `gpt-5.6-sol` with `xhigh` reasoning. Down-route only when the request
is unmistakably simple enough that quality and proof will not suffer. The
user's explicit model or routing choice always wins. Routing authorizes only
model delegation; it never expands permission to edit, publish, delete, pay,
message, or access external systems.

## Manual control

- `/model`: use Codex's native control for a persistent model/effort switch.
- `이번만 <Luna|Terra|Sol> [effort]`: use that route for this request only. If
  it differs from the active model, delegate one bounded task to that model.
- `<model> 고정` or `<model>로 계속`: explain that `/model` performs the actual
  persistent switch. If the message also contains work, honor the model once.
- `자동 모델` or `자동 라우팅`: resume this policy with Sol/xhigh as parent.
- `모델 상태`: report the known active model/effort and routing mode. Do not
  delegate.
- `다운라우팅 금지` or `Sol 유지`: keep this request on Sol/xhigh. Treat
  `계속 다운라우팅 금지` as a thread preference until `자동 모델` is requested.

## Automatic routes

- **L0 — Luna/low:** greetings, stable short factual answers, direct
  translation, tiny rewrites, brief status/meta checks, or a one-step response
  requiring no tools or verification. Delegate exactly one bounded response to
  `gpt-5.6-luna` with `low` effort when available.
- **L1 — Terra/medium:** bounded read-only work, modest comparison or summary,
  straightforward verification, or a narrow low-risk edit with complete
  requirements. Delegate exactly one bounded task to `gpt-5.6-terra` with
  `medium` effort when available.
- **L2 — Sol/xhigh:** multi-step implementation, ambiguous requests,
  architecture, debugging, security, live external effects, publishing,
  destructive operations, cross-system work, high-stakes analysis, or an
  uncertain proof bar. Keep the parent on `gpt-5.6-sol` with `xhigh` effort.

When uncertain, choose the higher route. Tools alone do not force Sol, but edits
plus verification, live external actions, or consequential decisions normally
do. Never automatically use max/ultra, parallel agents, or more than one child
per request.

For down-routing, use an explicit model and reasoning effort, pass only the
minimum task context, forbid the child from spawning agents, and require a
self-contained result. The Sol parent verifies and integrates it. If model
delegation is unavailable or fails, complete the request on Sol/xhigh and say
that the automatic saving route did not run. Never fake a route or launch a
separate CLI process.

## Routing receipt

Before delegated work, show this compact progress line:

```text
[자동 절약] 요청 · gpt-5.6-sol/xhigh → <target model/effort> · <short reason>
```

After the child returns, mark it `완료`; on rejection or failure, mark it
`실패`. In every final response, include exactly one concise line before any
result-file section:

```text
라우팅 결과: 유지 · gpt-5.6-sol/xhigh · <reason>
라우팅 결과: 자동 절약 완료 · gpt-5.6-sol/xhigh → <target> · <reason>
라우팅 결과: 수동 지정 · <model/effort> · <scope>
라우팅 결과: 자동 절약 실패 · <target> · Sol/xhigh에서 직접 처리 · <reason>
```
