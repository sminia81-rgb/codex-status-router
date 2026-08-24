# Portable Codex launchers for isolated primary and secondary accounts.
# Dot-source this file from your PowerShell profile.

$script:CodexHomePrimary = if ($env:CODEX_PRIMARY_HOME) {
  $env:CODEX_PRIMARY_HOME
} else {
  Join-Path $HOME '.codex'
}

$script:CodexHomeSecondary = if ($env:CODEX_SECONDARY_HOME) {
  $env:CODEX_SECONDARY_HOME
} else {
  Join-Path $HOME '.codex-accounts\secondary'
}

function Invoke-CodexAccount {
  param(
    [Parameter(Mandatory = $true)][string]$CodexHome,
    [ValidateSet('new', 'resume-last', 'resume-picker')][string]$Mode = 'new',
    [object[]]$CodexArgs = @()
  )

  $previousCodexHome = $env:CODEX_HOME
  try {
    $env:CODEX_HOME = $CodexHome

    # Resumed threads can retain a previous Fast selection, so force the
    # standard service at launch as well as in config.toml.
    $standardTierArgs = @('-c', 'service_tier="default"', '--disable', 'fast_mode')
    switch ($Mode) {
      'resume-last' {
        codex resume --last --dangerously-bypass-approvals-and-sandbox @standardTierArgs @CodexArgs
      }
      'resume-picker' {
        codex resume --dangerously-bypass-approvals-and-sandbox @standardTierArgs @CodexArgs
      }
      default {
        codex --dangerously-bypass-approvals-and-sandbox @standardTierArgs @CodexArgs
      }
    }
  }
  finally {
    if ($null -eq $previousCodexHome) {
      Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
    } else {
      $env:CODEX_HOME = $previousCodexHome
    }
  }
}

# Each invocation starts an independent new session under the primary account.
function cx  { Invoke-CodexAccount -CodexHome $script:CodexHomePrimary -Mode new -CodexArgs $args }
function cx2 { Invoke-CodexAccount -CodexHome $script:CodexHomePrimary -Mode new -CodexArgs $args }
function cx3 { Invoke-CodexAccount -CodexHome $script:CodexHomePrimary -Mode new -CodexArgs $args }
function cx4 { Invoke-CodexAccount -CodexHome $script:CodexHomePrimary -Mode new -CodexArgs $args }

# Separate launchers for a secondary account with its own CODEX_HOME.
function cx81  { Invoke-CodexAccount -CodexHome $script:CodexHomeSecondary -Mode new -CodexArgs $args }
function cx812 { Invoke-CodexAccount -CodexHome $script:CodexHomeSecondary -Mode new -CodexArgs $args }
