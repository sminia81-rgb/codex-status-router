# Codex Status Router

Codex를 평소에는 `gpt-5.6-sol / xhigh`로 유지하고, 요청 난이도에 따라
간단한 작업만 Luna/low 또는 Terra/medium으로 내려 보내는 개인용 설정입니다.
Codex TUI 아래쪽에는 다음 상태값을 표시합니다.

```text
weekly 98% left · my-project · gpt-5.6-sol · xhigh · Context 0% used
```

선택적으로 Codex 작업이 끝날 때 프로젝트명, 세션 ID, 작업 폴더, 마지막 답변
요약을 Discord 웹훅으로 보냅니다.

설치 대상은 다음 네 가지입니다.

- `~/.codex/config.toml`: 기본 모델, 추론 강도, TUI 상태줄
- `~/.codex/AGENTS.md`: 매 요청에 라우터를 적용하는 마커 블록
- `~/.agents/skills/adaptive-model-router`: 난이도별 모델 선택 규칙
- `~/.codex/scripts/codex-discord-notify.ps1`: 선택형 Discord 완료 알림

인증 토큰, Discord 웹훅 URL, 대화 기록, 프로젝트 경로, MCP 설정은 저장소에
포함하지 않습니다.

## Windows 설치

Codex와 Git이 설치된 PC에서 저장소를 복제한 뒤 PowerShell로 실행합니다.

```powershell
git clone https://github.com/sminia81-rgb/codex-status-router.git
cd codex-status-router
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

설치가 끝나면 실행 중인 Codex를 완전히 종료하고 다시 시작하세요. 기존
설정은 유지되며, 변경 전 파일은 아래 폴더에 백업됩니다.

```text
~/.codex/backups/codex-status-router-YYYYMMDD-HHMMSSmmm/
```

다른 Windows 사용자 프로필에 시험 설치하려면 다음처럼 대상을 지정할 수
있습니다.

```powershell
.\scripts\install.ps1 -TargetUserProfile 'C:\Users\another-user'
```

## Discord 완료 알림

Discord 서버에서 웹훅 URL을 만든 뒤 현재 Windows 사용자에만 저장합니다. URL을
명령 기록에 직접 남기지 않도록 변수로 받은 다음 설치기에 전달하세요.

```powershell
$webhookUrl = Read-Host 'Discord webhook URL'
.\scripts\install.ps1 -DiscordWebhookUrl $webhookUrl
Remove-Variable webhookUrl
```

설치기는 URL 형식을 확인한 뒤 `CODEX_DISCORD_WEBHOOK_URL` 사용자 환경 변수에
저장합니다. URL은 Git 파일이나 `config.toml`에 기록하지 않습니다. Codex를 완전히
종료하고 다시 시작하면 이후 `agent-turn-complete` 이벤트가 Discord로 전송됩니다.
웹훅을 설정하지 않은 PC에서는 알림 스크립트가 조용히 종료되며 라우터와 상태줄은
그대로 동작합니다.

Codex 데스크톱이 설치한 기본 완료 알림 실행 파일은 런타임 폴더에서 동적으로 찾아
함께 호출합니다. 별도의 사용자 정의 `notify` 명령을 이미 쓰고 있다면 설치 전에
백업 폴더의 `config.toml`을 참고해 병합하세요. 설치기는 `notify`를 이 저장소의
알림 스크립트로 교체합니다.

Discord 메시지에는 마지막 답변 일부와 작업 폴더의 절대경로가 포함됩니다. 민감한
프로젝트에서는 별도의 비공개 채널과 제한된 웹훅을 사용하세요.

## 라우팅 기준

- Luna/low: 인사, 짧은 번역, 아주 작은 문장 수정, 도구가 필요 없는 단순 답변
- Terra/medium: 범위가 명확한 읽기·요약·검증 또는 좁고 위험이 낮은 수정
- Sol/xhigh: 구현, 디버깅, 설계, 보안, 게시, 외부 변경, 모호하거나 복합적인 작업

사용자의 명시적 선택이 항상 우선합니다. `/model`은 현재 대화의 모델을
지속적으로 바꾸며, `Sol 유지` 또는 `다운라우팅 금지`는 자동 절약을 끕니다.

## 설치 확인

새 Codex 세션에서 `모델 상태`라고 입력하거나, 간단한 요청과 복합 요청을
각각 보내 최종 답변의 `라우팅 결과:` 한 줄을 확인하세요. Discord 웹훅을
설정했다면 해당 답변이 끝난 뒤 알림도 도착해야 합니다. 상태줄 항목은
Codex가 제공하는 네이티브 `[tui].status_line` 기능이라 별도 백그라운드
프로세스를 실행하지 않습니다.

## 수동 설치

자동 설치기를 쓰지 않으려면 [config.example.toml](config.example.toml)의
키를 `~/.codex/config.toml`에 병합하고, [AGENTS.block.md](AGENTS.block.md)의
마커 블록을 `~/.codex/AGENTS.md`에 추가한 뒤
`skills/adaptive-model-router`를 `~/.agents/skills/` 아래로 복사하세요. Discord
알림은 `scripts/codex-discord-notify.ps1`을 `~/.codex/scripts/`에 복사하고 해당
PowerShell 명령 배열을 사용자 `config.toml`의 최상위 `notify`에 지정해야 합니다.

공식 문서: [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-reference),
[advanced notifications](https://learn.chatgpt.com/docs/config-file/config-advanced#notifications),
[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[skills](https://learn.chatgpt.com/docs/build-skills).

## 라이선스

MIT
