$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-status-router-test-' + [guid]::NewGuid().ToString('N'))
$testUserProfile = Join-Path $testRoot 'User Profile'
$codexHome = Join-Path $testUserProfile '.codex'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

try {
    $invalidProfile = Join-Path $testRoot 'Invalid Webhook Profile'
    $invalidCodexHome = Join-Path $invalidProfile '.codex'
    $invalidWebhookRejected = $false
    try {
        & (Join-Path $repoRoot 'scripts\install.ps1') `
            -TargetUserProfile $invalidProfile `
            -TargetCodexHome $invalidCodexHome `
            -DiscordWebhookUrl 'http://example.com/not-discord'
    }
    catch {
        $invalidWebhookRejected = $true
    }
    Assert-True $invalidWebhookRejected 'Invalid Discord webhook URLs must be rejected.'
    Assert-True (-not (Test-Path -LiteralPath $invalidCodexHome)) 'Rejected webhook input must not make partial changes.'

    [System.IO.Directory]::CreateDirectory($codexHome) | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $codexHome 'config.toml'),
        @'
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"
notify = ["legacy-notifier.exe"]
custom_key = true

[tui]
status_line = ["cwd"]
theme = "dark"

[features]
hooks = true
'@,
        $utf8NoBom
    )
    [System.IO.File]::WriteAllText((Join-Path $codexHome 'AGENTS.md'), "# Existing instructions`n", $utf8NoBom)

    & (Join-Path $repoRoot 'scripts\install.ps1') -TargetUserProfile $testUserProfile -TargetCodexHome $codexHome
    & (Join-Path $repoRoot 'scripts\install.ps1') -TargetUserProfile $testUserProfile -TargetCodexHome $codexHome

    $config = [System.IO.File]::ReadAllText((Join-Path $codexHome 'config.toml'))
    $agents = [System.IO.File]::ReadAllText((Join-Path $codexHome 'AGENTS.md'))
    $notifier = Join-Path $codexHome 'scripts\codex-discord-notify.ps1'
    Assert-True ($config -match '(?m)^model = "gpt-5\.6-sol"$') 'Sol must be the default model.'
    Assert-True ($config -match '(?m)^model_reasoning_effort = "xhigh"$') 'xhigh must be the default effort.'
    Assert-True (([regex]::Matches($config, '(?m)^notify\s*=')).Count -eq 1) 'Notify config must be idempotent.'
    Assert-True ($config.Contains((ConvertTo-Json -InputObject $notifier -Compress))) 'Notify must use the target profile path.'
    Assert-True ($config -match 'weekly-limit') 'The weekly status item must be present.'
    Assert-True ($config -match '(?m)^custom_key = true$') 'Existing top-level config must be preserved.'
    Assert-True ($config -match '(?m)^theme = "dark"$') 'Existing TUI config must be preserved.'
    Assert-True (([regex]::Matches($agents, '<!-- codex-status-router:start -->')).Count -eq 1) 'Install must be idempotent.'
    Assert-True ($agents -match '# Existing instructions') 'Existing AGENTS.md content must be preserved.'
    Assert-True (Test-Path -LiteralPath (Join-Path $testUserProfile '.agents\skills\adaptive-model-router\SKILL.md')) 'Router skill must be installed.'
    Assert-True (Test-Path -LiteralPath $notifier -PathType Leaf) 'Discord notifier must be installed.'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $codexHome 'backups') -Directory).Count -ge 2) 'Each run must create a backup.'

    $previousWebhook = [Environment]::GetEnvironmentVariable('CODEX_DISCORD_WEBHOOK_URL', 'Process')
    $previousSkipLegacy = [Environment]::GetEnvironmentVariable('CODEX_NOTIFY_SKIP_LEGACY', 'Process')
    try {
        $env:CODEX_DISCORD_WEBHOOK_URL = 'invalid://no-network'
        $env:CODEX_NOTIFY_SKIP_LEGACY = '1'
        $powershell = (Get-Command 'powershell.exe' -ErrorAction Stop).Source
        $testNotification = '{"type":"agent-turn-complete","thread-id":"test-thread","cwd":"C:\\work","last-assistant-message":"Done"}'
        & $powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $notifier $testNotification
        Assert-True ($LASTEXITCODE -eq 0) 'Notifier must fail open for an invalid webhook in normal mode.'
    }
    finally {
        [Environment]::SetEnvironmentVariable('CODEX_DISCORD_WEBHOOK_URL', $previousWebhook, 'Process')
        [Environment]::SetEnvironmentVariable('CODEX_NOTIFY_SKIP_LEGACY', $previousSkipLegacy, 'Process')
    }

    $codexCommand = Get-Command codex -ErrorAction SilentlyContinue
    if ($null -ne $codexCommand) {
        $previousCodexHome = $env:CODEX_HOME
        $previousErrorPreference = $ErrorActionPreference
        try {
            $env:CODEX_HOME = $codexHome
            $ErrorActionPreference = 'Continue'
            & $codexCommand.Source features list 2> $null | Out-Null
            $codexExitCode = $LASTEXITCODE
            $ErrorActionPreference = $previousErrorPreference
            Assert-True ($codexExitCode -eq 0) 'Codex must accept the merged config.toml.'
        }
        finally {
            $env:CODEX_HOME = $previousCodexHome
            $ErrorActionPreference = $previousErrorPreference
        }
    }

    Write-Host 'All installer tests passed.'
}
finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    $resolvedTest = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolvedTest.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
        [System.IO.Path]::GetFileName($resolvedTest).StartsWith('codex-status-router-test-')) {
        Remove-Item -LiteralPath $resolvedTest -Recurse -Force -ErrorAction SilentlyContinue
    }
}
