$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-status-router-test-' + [guid]::NewGuid().ToString('N'))
$codexHome = Join-Path $testRoot '.codex'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

try {
    [System.IO.Directory]::CreateDirectory($codexHome) | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $codexHome 'config.toml'),
        @'
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"
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

    & (Join-Path $repoRoot 'scripts\install.ps1') -TargetUserProfile $testRoot -TargetCodexHome $codexHome
    & (Join-Path $repoRoot 'scripts\install.ps1') -TargetUserProfile $testRoot -TargetCodexHome $codexHome

    $config = [System.IO.File]::ReadAllText((Join-Path $codexHome 'config.toml'))
    $agents = [System.IO.File]::ReadAllText((Join-Path $codexHome 'AGENTS.md'))
    Assert-True ($config -match '(?m)^model = "gpt-5\.6-sol"$') 'Sol must be the default model.'
    Assert-True ($config -match '(?m)^model_reasoning_effort = "xhigh"$') 'xhigh must be the default effort.'
    Assert-True ($config -match 'weekly-limit') 'The weekly status item must be present.'
    Assert-True ($config -match '(?m)^custom_key = true$') 'Existing top-level config must be preserved.'
    Assert-True ($config -match '(?m)^theme = "dark"$') 'Existing TUI config must be preserved.'
    Assert-True (([regex]::Matches($agents, '<!-- codex-status-router:start -->')).Count -eq 1) 'Install must be idempotent.'
    Assert-True ($agents -match '# Existing instructions') 'Existing AGENTS.md content must be preserved.'
    Assert-True (Test-Path -LiteralPath (Join-Path $testRoot '.agents\skills\adaptive-model-router\SKILL.md')) 'Router skill must be installed.'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $codexHome 'backups') -Directory).Count -ge 2) 'Each run must create a backup.'

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
