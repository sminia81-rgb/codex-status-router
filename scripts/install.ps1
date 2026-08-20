[CmdletBinding()]
param(
    [string] $TargetUserProfile = $env:USERPROFILE,
    [string] $TargetCodexHome = $env:CODEX_HOME
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($TargetUserProfile)) {
    throw 'TargetUserProfile is required.'
}

$TargetUserProfile = [System.IO.Path]::GetFullPath($TargetUserProfile)
if (-not [System.IO.Path]::IsPathRooted($TargetUserProfile)) {
    throw 'TargetUserProfile must be an absolute path.'
}

if ([string]::IsNullOrWhiteSpace($TargetCodexHome)) {
    $TargetCodexHome = Join-Path $TargetUserProfile '.codex'
} else {
    $TargetCodexHome = [System.IO.Path]::GetFullPath($TargetCodexHome)
}

$sourceRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$targetAgentsHome = Join-Path $TargetUserProfile '.agents'
$targetSkill = Join-Path $targetAgentsHome 'skills\adaptive-model-router'
$targetConfig = Join-Path $TargetCodexHome 'config.toml'
$targetAgentsFile = Join-Path $TargetCodexHome 'AGENTS.md'
$backupRoot = Join-Path $TargetCodexHome ('backups\codex-status-router-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-TextFile {
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    return [System.IO.File]::ReadAllText($Path)
}

function Write-TextFile {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Text
    )
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Backup-Target {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Name
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
    $destination = Join-Path $backupRoot $Name
    if (Test-Path -LiteralPath $Path -PathType Container) {
        Copy-Item -LiteralPath $Path -Destination $destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $Path -Destination $destination -Force
    }
}

function Set-TopLevelTomlValue {
    param(
        [Parameter(Mandatory)][string] $Text,
        [Parameter(Mandatory)][string] $Key,
        [Parameter(Mandatory)][string] $TomlValue
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -replace "`r`n", "`n" -split "`n")) { $lines.Add($line) }
    $firstSection = $lines.Count
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*\[') { $firstSection = $index; break }
    }

    $escapedKey = [regex]::Escape($Key)
    for ($index = 0; $index -lt $firstSection; $index++) {
        if ($lines[$index] -match "^\s*$escapedKey\s*=") {
            $lines[$index] = "$Key = $TomlValue"
            return [string]::Join("`n", $lines)
        }
    }

    $lines.Insert(0, "$Key = $TomlValue")
    return [string]::Join("`n", $lines)
}

function Set-TuiStatusLine {
    param([Parameter(Mandatory)][string] $Text)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -replace "`r`n", "`n" -split "`n")) { $lines.Add($line) }
    $statusLines = @(
        'status_line = [',
        '    "weekly-limit",',
        '    "project-name",',
        '    "model",',
        '    "reasoning",',
        '    "context-used",',
        ']'
    )

    $tuiStart = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*\[tui\]\s*(?:#.*)?$') { $tuiStart = $index; break }
    }

    if ($tuiStart -lt 0) {
        while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
            $lines.RemoveAt($lines.Count - 1)
        }
        if ($lines.Count -gt 0) { $lines.Add('') }
        $lines.Add('[tui]')
        foreach ($statusLine in $statusLines) { $lines.Add($statusLine) }
        $lines.Add('')
        return [string]::Join("`n", $lines)
    }

    $tuiEnd = $lines.Count
    for ($index = $tuiStart + 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*\[') { $tuiEnd = $index; break }
    }

    $statusStart = -1
    for ($index = $tuiStart + 1; $index -lt $tuiEnd; $index++) {
        if ($lines[$index] -match '^\s*status_line\s*=') { $statusStart = $index; break }
    }

    if ($statusStart -ge 0) {
        $statusEnd = $statusStart
        if ($lines[$statusStart] -notmatch '\]') {
            for ($index = $statusStart + 1; $index -lt $tuiEnd; $index++) {
                $statusEnd = $index
                if ($lines[$index] -match '\]') { break }
            }
        }
        $lines.RemoveRange($statusStart, $statusEnd - $statusStart + 1)
        for ($index = $statusLines.Count - 1; $index -ge 0; $index--) {
            $lines.Insert($statusStart, $statusLines[$index])
        }
    } else {
        for ($index = $statusLines.Count - 1; $index -ge 0; $index--) {
            $lines.Insert($tuiStart + 1, $statusLines[$index])
        }
    }

    return [string]::Join("`n", $lines)
}

function Set-RoutingInstructions {
    param(
        [Parameter(Mandatory)][string] $Existing,
        [Parameter(Mandatory)][string] $Block
    )
    $withoutExistingBlock = [regex]::Replace(
        ($Existing -replace "`r`n", "`n"),
        '(?ms)^\s*<!-- codex-status-router:start -->.*?<!-- codex-status-router:end -->\s*',
        ''
    ).TrimEnd()
    $cleanBlock = ($Block -replace "`r`n", "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($withoutExistingBlock)) { return "$cleanBlock`n" }
    return "$withoutExistingBlock`n`n$cleanBlock`n"
}

Backup-Target -Path $targetConfig -Name 'config.toml'
Backup-Target -Path $targetAgentsFile -Name 'AGENTS.md'
Backup-Target -Path $targetSkill -Name 'adaptive-model-router'

$configText = Read-TextFile -Path $targetConfig
$configText = Set-TopLevelTomlValue -Text $configText -Key 'model' -TomlValue '"gpt-5.6-sol"'
$configText = Set-TopLevelTomlValue -Text $configText -Key 'model_reasoning_effort' -TomlValue '"xhigh"'
$configText = Set-TuiStatusLine -Text $configText
Write-TextFile -Path $targetConfig -Text $configText

$routingBlock = Read-TextFile -Path (Join-Path $sourceRoot 'AGENTS.block.md')
$agentsText = Set-RoutingInstructions -Existing (Read-TextFile -Path $targetAgentsFile) -Block $routingBlock
Write-TextFile -Path $targetAgentsFile -Text $agentsText

$sourceSkill = Join-Path $sourceRoot 'skills\adaptive-model-router'
[System.IO.Directory]::CreateDirectory((Join-Path $targetSkill 'agents')) | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceSkill 'SKILL.md') -Destination (Join-Path $targetSkill 'SKILL.md') -Force
Copy-Item -LiteralPath (Join-Path $sourceSkill 'agents\openai.yaml') -Destination (Join-Path $targetSkill 'agents\openai.yaml') -Force

$verification = @(
    (Select-String -LiteralPath $targetConfig -Pattern '^model = "gpt-5\.6-sol"$' -Quiet),
    (Select-String -LiteralPath $targetConfig -Pattern '^model_reasoning_effort = "xhigh"$' -Quiet),
    (Select-String -LiteralPath $targetConfig -Pattern '^\s*"weekly-limit",\s*$' -Quiet),
    (Select-String -LiteralPath $targetAgentsFile -Pattern '<!-- codex-status-router:start -->' -Quiet),
    (Test-Path -LiteralPath (Join-Path $targetSkill 'SKILL.md') -PathType Leaf)
)
if ($verification -contains $false) { throw 'Installation verification failed.' }

Write-Host 'Codex Status Router installed successfully.'
Write-Host "Config: $targetConfig"
Write-Host "Instructions: $targetAgentsFile"
Write-Host "Skill: $targetSkill"
if (Test-Path -LiteralPath $backupRoot) { Write-Host "Backup: $backupRoot" }
Write-Host 'Restart Codex to load the new configuration.'
