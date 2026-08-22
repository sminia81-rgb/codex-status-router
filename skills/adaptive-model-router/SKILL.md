---
name: adaptive-model-router
description: Keep Codex on GPT-5.6 Sol/xhigh for substantive work and automatically down-route only clearly simple requests to cheaper GPT-5.6 models. Honor explicit model choices and report every routing decision. Use before every user request unless the user disables routing.
---

# Adaptive Model Router

Default to `gpt-5.6-sol` with `xhigh` reasoning. Down-route only when the request is unmistakably simple enough that quality and proof will not suffer. The user's explicit model or routing choice always wins. Routing authorizes only model delegation; it never expands permission to edit, publish, delete, pay, message, or access external systems.

## Manual control

- `/model`: native control for changing the current chat's model and reasoning effort. Recommend this for persistent switching; never simulate a persistent switch by spawning a child every turn.
- `이번만 <Luna|Terra|Sol> [effort]`: use that route for this request only. If it differs from the active model, delegate one bounded task to that model.
- `<model> 고정` or `<model>로 계속`: explain that `/model` performs the actual persistent switch. If the message also contains work, honor the requested model once for that work.
- `자동 모델` or `자동 라우팅`: resume the policy below. Keep Sol/xhigh as the persistent parent and down-route eligible requests.
- `모델 상태`: report active model/effort when known, routing mode, and any one-turn override. Do not delegate.
- `다운라우팅 금지` or `Sol 유지`: do not delegate to a cheaper model for this request. Treat `계속 다운라우팅 금지` as a thread-level preference until the user says `자동 모델`.

## Automatic routes

- **L0 — Luna/low:** Use only for clearly simple conversation: greetings, short factual answers with stable facts, direct translation, tiny rewrites, brief status/meta checks, or a one-step mechanical response that needs no tools or verification. Delegate exactly one bounded response to `gpt-5.6-luna` with `low` effort when available.
- **L1 — Terra/medium:** Use for bounded read-only work, modest comparison or summarization, straightforward verification, or a narrow low-risk edit whose requirements are already complete. Delegate exactly one bounded task to `gpt-5.6-terra` with `medium` effort when available.
- **L2 — Sol/xhigh:** Keep the parent on `gpt-5.6-sol` with `xhigh` effort for all substantive work: multi-step implementation, ambiguous requests, architecture, debugging, security, external side effects, publishing, destructive operations, cross-system work, high-stakes analysis, or anything whose proof bar is uncertain.

When uncertain between routes, choose the higher route. The presence of tools alone does not force Sol, but edits plus verification, live external actions, or consequential decisions normally do. Never automatically use `max`, `ultra`, parallel agents, or more than one child per user turn.

For down-routing, use an explicit model and reasoning effort, prefer `fork_turns="none"`, pass only the minimum task context, forbid the child from spawning agents, and require a self-contained result. The Sol parent checks and integrates the result. If spawning is unavailable or rejected, complete the request on Sol/xhigh and disclose that automatic savings did not run; never fake down-routing or launch a separate CLI session.

## Routing receipt

Before delegated work, show one compact commentary line:

```text
[자동 절약] 요청 · gpt-5.6-sol/xhigh → <target model/effort> · <short reason>
```

After the child returns, show `완료`; on rejection or failure, show `실패`. Mark completion only after a successful child result. For every final response, include exactly one concise line before any result-file section:

```text
라우팅 결과: 유지 · gpt-5.6-sol/xhigh · <reason>
라우팅 결과: 자동 절약 완료 · gpt-5.6-sol/xhigh → <target> · <reason>
라우팅 결과: 수동 지정 · <model/effort> · <scope>
라우팅 결과: 자동 절약 실패 · <target> · Sol/xhigh에서 직접 처리 · <reason>
```
