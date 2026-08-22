[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $NotificationJson
)

$ErrorActionPreference = 'Stop'

function Get-OptionalEnvironmentVariable {
    param([Parameter(Mandatory)][string] $Name)

    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, 'User')
    }
    return $value
}

function Find-CodexDesktopNotifier {
    $override = Get-OptionalEnvironmentVariable -Name 'CODEX_LEGACY_NOTIFIER'
    if (-not [string]::IsNullOrWhiteSpace($override) -and
        (Test-Path -LiteralPath $override -PathType Leaf)) {
        return $override
    }

    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { return $null }
    $runtimeRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\runtimes\cua_node'
    if (-not (Test-Path -LiteralPath $runtimeRoot -PathType Container)) { return $null }

    $relativeNotifier = 'bin\node_modules\@oai\sky\bin\windows\codex-computer-use.exe'
    $candidates = foreach ($runtime in (Get-ChildItem -LiteralPath $runtimeRoot -Directory -ErrorAction SilentlyContinue)) {
        $candidate = Join-Path $runtime.FullName $relativeNotifier
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Get-Item -LiteralPath $candidate
        }
    }

    return $candidates |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Test-DiscordWebhookUrl {
    param([Parameter(Mandatory)][string] $Value)

    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref] $uri)) { return $false }
    if ($uri.Scheme -ne 'https') { return $false }
    if ($uri.Host -notin @('discord.com', 'canary.discord.com', 'ptb.discord.com', 'discordapp.com')) {
        return $false
    }
    return $uri.AbsolutePath -match '^/api(?:/v\d+)?/webhooks/\d+/[^/]+/?$'
}

if ($env:CODEX_NOTIFY_SKIP_LEGACY -ne '1') {
    $legacyNotifier = Find-CodexDesktopNotifier
    if (-not [string]::IsNullOrWhiteSpace($legacyNotifier)) {
        try {
            & $legacyNotifier 'turn-ended' $NotificationJson | Out-Null
        }
        catch {
            # Desktop notification failure must not block the Discord notification.
        }
    }
}

try {
    $notification = $NotificationJson | ConvertFrom-Json
}
catch {
    if ($env:CODEX_NOTIFY_STRICT -eq '1') { throw }
    exit 0
}

if ($notification.type -ne 'agent-turn-complete') { exit 0 }

$webhookUrl = Get-OptionalEnvironmentVariable -Name 'CODEX_DISCORD_WEBHOOK_URL'
if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
    if ($env:CODEX_NOTIFY_STRICT -eq '1') {
        throw 'CODEX_DISCORD_WEBHOOK_URL is not configured.'
    }
    exit 0
}
if (-not (Test-DiscordWebhookUrl -Value $webhookUrl)) {
    if ($env:CODEX_NOTIFY_STRICT -eq '1') {
        throw 'CODEX_DISCORD_WEBHOOK_URL must be an HTTPS Discord webhook URL.'
    }
    exit 0
}

$workingDirectory = [string] $notification.cwd
$trimmedDirectory = $workingDirectory.TrimEnd([char[]] @(92, 47))
$projectName = Split-Path -Leaf $trimmedDirectory
if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = 'unknown' }

$threadId = [string] $notification.'thread-id'
if ($threadId.Length -gt 12) { $threadId = $threadId.Substring(0, 12) }

$summary = [string] $notification.'last-assistant-message'
if ([string]::IsNullOrWhiteSpace($summary)) { $summary = 'Task completed.' }
if ($summary.Length -gt 1200) { $summary = $summary.Substring(0, 1200) + '...' }
if ($workingDirectory.Length -gt 900) {
    $workingDirectory = $workingDirectory.Substring(0, 900) + '...'
}

$payload = @{
    username = 'Codex'
    allowed_mentions = @{ parse = @() }
    embeds = @(
        @{
            title = 'Codex task complete'
            description = $summary
            color = 5763719
            fields = @(
                @{ name = 'Project'; value = $projectName; inline = $true },
                @{ name = 'Session'; value = $threadId; inline = $true },
                @{ name = 'Path'; value = $workingDirectory; inline = $false }
            )
            timestamp = [DateTime]::UtcNow.ToString('o')
        }
    )
} | ConvertTo-Json -Depth 8 -Compress

try {
    $separator = if ($webhookUrl.Contains('?')) { '&' } else { '?' }
    $requestUri = $webhookUrl + $separator + 'wait=true'
    $body = [Text.Encoding]::UTF8.GetBytes($payload)
    $response = Invoke-RestMethod -Method Post -Uri $requestUri -ContentType 'application/json; charset=utf-8' -Body $body
    if ($env:CODEX_NOTIFY_TEST -eq '1') {
        Write-Output ('sent:' + [string] $response.id)
    }
}
catch {
    try {
        $logDirectory = Join-Path $env:USERPROFILE '.codex\log'
        [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null
        $logPath = Join-Path $logDirectory 'codex-discord-notify.log'
        $logLine = (Get-Date -Format 'o') + ' Discord notification failed: ' + $_.Exception.GetType().Name
        Add-Content -LiteralPath $logPath -Value $logLine
    }
    catch {
        # Logging is best-effort only.
    }

    if ($env:CODEX_NOTIFY_STRICT -eq '1') { throw }
}

exit 0
