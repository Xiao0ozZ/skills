param(
    [string]$SourcePath,
    [string]$SkillHome,
    [string]$BackupHome,
    [switch]$DryRun,
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

if (-not $SourcePath) {
    $SourcePath = Split-Path -Parent $PSScriptRoot
}

$resolvedSource = (Resolve-Path -LiteralPath $SourcePath).Path
$skillName = Split-Path -Leaf $resolvedSource

$skillMd = Join-Path $resolvedSource "SKILL.md"
$agentYaml = Join-Path $resolvedSource "agents\openai.yaml"

if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
    throw "Source skill is missing SKILL.md: $skillMd"
}

if (-not (Test-Path -LiteralPath $agentYaml -PathType Leaf)) {
    throw "Source skill is missing agents/openai.yaml: $agentYaml"
}

if (-not $SkillHome) {
    if ($env:CODEX_HOME) {
        $SkillHome = Join-Path $env:CODEX_HOME "skills"
    } else {
        $SkillHome = Join-Path $HOME ".codex\skills"
    }
}

if (-not (Test-Path -LiteralPath $SkillHome)) {
    New-Item -ItemType Directory -Path $SkillHome | Out-Null
}

$resolvedSkillHome = (Resolve-Path -LiteralPath $SkillHome).Path
$destination = Join-Path $resolvedSkillHome $skillName
$backupPath = $null
$destinationExists = Test-Path -LiteralPath $destination

if ($destinationExists -and -not $NoBackup) {
    if (-not $BackupHome) {
        $BackupHome = Join-Path (Split-Path -Parent $resolvedSkillHome) 'skill-backups'
    }
    $resolvedBackupHome = [System.IO.Path]::GetFullPath($BackupHome)
    $skillHomePrefix = $resolvedSkillHome.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedBackupHome.Equals($resolvedSkillHome, [System.StringComparison]::OrdinalIgnoreCase) -or
        $resolvedBackupHome.StartsWith($skillHomePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'BackupHome must be outside the Skills directory so Codex does not load backups as skills.'
    }
    if (-not $DryRun -and -not (Test-Path -LiteralPath $resolvedBackupHome)) {
        New-Item -ItemType Directory -Path $resolvedBackupHome | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $resolvedBackupHome "$skillName.backup.$timestamp"
    $suffix = 1
    while (Test-Path -LiteralPath $backupPath) {
        $backupPath = Join-Path $resolvedBackupHome "$skillName.backup.$timestamp-$suffix"
        $suffix++
    }
}

if (-not $DryRun) {
    if ($destinationExists -and -not $NoBackup) {
        Copy-Item -LiteralPath $destination -Destination $backupPath -Recurse
    }

    if ($destinationExists) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }

    Copy-Item -LiteralPath $resolvedSource -Destination $destination -Recurse
}

[PSCustomObject]@{
    SkillName = $skillName
    SourcePath = $resolvedSource
    InstalledPath = $destination
    BackupPath = $backupPath
    DryRun = [bool]$DryRun
    WouldReplaceExisting = $destinationExists
    RestartCodex = -not $DryRun
}
