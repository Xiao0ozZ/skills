param(
    [string]$SkillRoot = (Split-Path -Parent $PSScriptRoot)
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$Utf8 = [System.Text.Encoding]::UTF8

$SkillRoot = (Resolve-Path -LiteralPath $SkillRoot).Path

$results = New-Object System.Collections.Generic.List[object]
$usageTerm = -join ([int[]](0x4F7F, 0x7528, 0x65B9, 0x5F0F) | ForEach-Object { [char]$_ })
$explicitTerm = -join ([int[]](0x660E, 0x786E) | ForEach-Object { [char]$_ })
$noPublishTerm = -join ([int[]](0x4E0D, 0x53D1, 0x5E03) | ForEach-Object { [char]$_ })
$noExecuteTerm = -join ([int[]](0x4E0D, 0x6267, 0x884C) | ForEach-Object { [char]$_ })
$workFileTerm = -join ([int[]](0x5DE5, 0x4F5C, 0x6587, 0x4EF6) | ForEach-Object { [char]$_ })

function Add-Result {
    param([string]$Check, [string]$Status, [string]$Detail)
    $script:results.Add([pscustomobject]@{
        Check = $Check
        Status = $Status
        Detail = $Detail
    }) | Out-Null
}

function Get-RelativePath {
    param([string]$Path)
    $root = $SkillRoot.TrimEnd('\', '/')
    if ($Path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($root.Length).TrimStart('\', '/')
    }
    return $Path
}

function Read-Utf8Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, $Utf8)
}

function Read-Utf8Lines {
    param([string]$Path)
    return [System.IO.File]::ReadAllLines($Path, $Utf8)
}

function Get-FilesByRelativePattern {
    param([string]$Pattern, [string]$Root = $SkillRoot)
    $normalized = $Pattern -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $dirPart = Split-Path $normalized -Parent
    $leaf = Split-Path $normalized -Leaf
    if ([string]::IsNullOrWhiteSpace($dirPart)) {
        $dir = $Root
    } else {
        $dir = Join-Path $Root $dirPart
    }
    if (-not (Test-Path -LiteralPath $dir)) {
        return @()
    }
    if ($leaf -like '*[*?]*') {
        return @(Get-ChildItem -LiteralPath $dir -Filter $leaf -File)
    }
    $target = Join-Path $dir $leaf
    if (Test-Path -LiteralPath $target) {
        return @(Get-Item -LiteralPath $target)
    }
    return @()
}

function Get-MarkdownHeadings {
    param([System.IO.FileInfo[]]$Files)
    $headings = New-Object System.Collections.Generic.HashSet[string]
    foreach ($file in $Files) {
        foreach ($line in (Read-Utf8Lines $file.FullName)) {
            if ($line -match '^(#{1,6})\s+(.+?)\s*$') {
                $headings.Add("$($Matches[1]) $($Matches[2])") | Out-Null
            }
        }
    }
    return $headings
}

$skillMd = Join-Path $SkillRoot 'SKILL.md'
$openaiYaml = Join-Path $SkillRoot 'agents/openai.yaml'
$referencesRoot = Join-Path $SkillRoot 'references'
$scriptsRoot = Join-Path $SkillRoot 'scripts'
$healthScript = $MyInvocation.MyCommand.Path

$requiredPatterns = @(
    'SKILL.md',
    'agents/openai.yaml',
    'evals/trigger-evals.json',
    'references/00-*.md',
    'references/10-*.md',
    'references/20-*.md',
    'references/30-*.md',
    'references/31-*.md',
    'references/32-*.md',
    'references/33-*.md',
    'references/34-*.md',
    'references/35-*.md',
    'references/90-*.md',
    'scripts/publish_personal_workflow_skill.ps1'
)

$missingRequired = New-Object System.Collections.Generic.List[string]
foreach ($pattern in $requiredPatterns) {
    $matches = Get-FilesByRelativePattern $pattern
    if ($matches.Count -eq 0) {
        $missingRequired.Add($pattern) | Out-Null
    }
}

if ($missingRequired.Count -eq 0) {
    Add-Result 'Required files' 'OK' "$($requiredPatterns.Count) required patterns resolve"
} else {
    Add-Result 'Required files' 'FAIL' ("Missing: " + ($missingRequired -join ', '))
}

$triggerEvalsPath = Join-Path $SkillRoot 'evals/trigger-evals.json'
try {
    $triggerEvals = (Read-Utf8Text $triggerEvalsPath) | ConvertFrom-Json
    $cases = @($triggerEvals.cases)
    $badCases = @($cases | Where-Object {
        [string]::IsNullOrWhiteSpace($_.id) -or
        [string]::IsNullOrWhiteSpace($_.prompt) -or
        [string]::IsNullOrWhiteSpace($_.expected_mode) -or
        [string]::IsNullOrWhiteSpace($_.expected_reference)
    })

    if ($cases.Count -ge 8 -and $badCases.Count -eq 0) {
        Add-Result 'Trigger eval fixture' 'OK' "$($cases.Count) trigger cases parse with required fields"
    } else {
        Add-Result 'Trigger eval fixture' 'FAIL' "cases=$($cases.Count); bad_cases=$($badCases.Count)"
    }
} catch {
    Add-Result 'Trigger eval fixture' 'FAIL' $_.Exception.Message
}

$sourceFiles = @(Get-ChildItem -LiteralPath $SkillRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.md', '.yaml', '.yml', '.ps1', '.json') })

$absolutePathPattern = '[A-Za-z]:[\\/](?![sSdDwWbBAZ])|' +
    [regex]::Escape('/Use' + 'rs/') + '|' +
    [regex]::Escape('/ho' + 'me/') + '|' +
    [regex]::Escape('iCloud' + 'Drive') + '|' +
    [regex]::Escape('Obsidian ' + 'Vault') + '|' +
    [regex]::Escape($workFileTerm)

$pathHits = New-Object System.Collections.Generic.List[string]
foreach ($file in $sourceFiles) {
    $lines = Read-Utf8Lines $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $absolutePathPattern) {
            $pathHits.Add("$(Get-RelativePath $file.FullName):$($i + 1)") | Out-Null
        }
    }
}

if ($pathHits.Count -eq 0) {
    Add-Result 'No local path residue' 'OK' 'No drive paths, local machine dirs or vault-specific path strings found'
} else {
    Add-Result 'No local path residue' 'FAIL' ($pathHits -join '; ')
}

$referenceFiles = @(Get-ChildItem -LiteralPath $referencesRoot -Filter '*.md' -File)
$missingUsage = New-Object System.Collections.Generic.List[string]
foreach ($file in $referenceFiles) {
    $top = ((Read-Utf8Lines $file.FullName) | Select-Object -First 45) -join "`n"
    if (($top -notmatch [regex]::Escape($usageTerm)) -and
        ($top -notmatch 'Use this file|This file is|Do not load all|Read only')) {
        $missingUsage.Add((Get-RelativePath $file.FullName)) | Out-Null
    }
}

if ($missingUsage.Count -eq 0) {
    Add-Result 'Reference usage guides' 'OK' "$($referenceFiles.Count) reference files expose usage/navigation near the top"
} else {
    Add-Result 'Reference usage guides' 'FAIL' ("Missing usage guide: " + ($missingUsage -join ', '))
}

$longReferencesMissingToc = New-Object System.Collections.Generic.List[string]
foreach ($file in $referenceFiles) {
    $lines = Read-Utf8Lines $file.FullName
    if ($lines.Count -gt 100) {
        $top = ($lines | Select-Object -First 45) -join "`n"
        if ($top -notmatch '(?m)^##\s+(目录|Contents)\s*$') {
            $longReferencesMissingToc.Add((Get-RelativePath $file.FullName)) | Out-Null
        }
    }
}

if ($longReferencesMissingToc.Count -eq 0) {
    Add-Result 'Long reference navigation' 'OK' 'All reference files over 100 lines expose a top-level table of contents'
} else {
    Add-Result 'Long reference navigation' 'FAIL' ("Missing table of contents: " + ($longReferencesMissingToc -join ', '))
}

$skillLines = (Read-Utf8Lines $skillMd).Count
$skillText = Read-Utf8Text $skillMd
$description = ''
if ($skillText -match "(?m)^description:\s*[""']?(.*?)[""']?\s*$") {
    $description = $Matches[1]
}
$descriptionWordCount = ([regex]::Matches($description, '[A-Za-z0-9_/-]+')).Count

if ($skillLines -le 120 -and $descriptionWordCount -le 100) {
    Add-Result 'Lightweight entry' 'OK' "SKILL.md lines=$skillLines; description words=$descriptionWordCount"
} else {
    Add-Result 'Lightweight entry' 'FAIL' "SKILL.md lines=$skillLines; description words=$descriptionWordCount"
}

$yamlText = Read-Utf8Text $openaiYaml
$shortDescription = ''
$defaultPrompt = ''
if ($yamlText -match "(?m)^\s*short_description:\s*[""']?(.*?)[""']?\s*$") {
    $shortDescription = $Matches[1]
}
if ($yamlText -match "(?m)^\s*default_prompt:\s*[""']?(.*?)[""']?\s*$") {
    $defaultPrompt = $Matches[1]
}
$defaultPromptWords = ([regex]::Matches($defaultPrompt, '[A-Za-z0-9_/-]+')).Count
if ($shortDescription.Length -le 80 -and $defaultPromptWords -le 80) {
    Add-Result 'UI metadata weight' 'OK' "short_description chars=$($shortDescription.Length); default_prompt words=$defaultPromptWords"
} else {
    Add-Result 'UI metadata weight' 'FAIL' "short_description chars=$($shortDescription.Length); default_prompt words=$defaultPromptWords"
}

$linkTargets = New-Object System.Collections.Generic.HashSet[string]
foreach ($file in $sourceFiles) {
    $text = Read-Utf8Text $file.FullName
    foreach ($match in [regex]::Matches($text, '`((references|scripts|assets)/[^`]+?\.(md|ps1|pptx|xlsx|docx|pdf|png|jpg|jpeg|webp|svg|html))`')) {
        $linkTargets.Add($match.Groups[1].Value) | Out-Null
    }
}

$missingLinks = New-Object System.Collections.Generic.List[string]
foreach ($target in $linkTargets) {
    $local = Join-Path $SkillRoot ($target -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $local)) {
        $missingLinks.Add($target) | Out-Null
    }
}

if ($missingLinks.Count -eq 0) {
    Add-Result 'Referenced bundled files' 'OK' "$($linkTargets.Count) bundled file links resolve"
} else {
    Add-Result 'Referenced bundled files' 'FAIL' ("Missing links: " + ($missingLinks -join ', '))
}

$publishScript = Join-Path $scriptsRoot 'publish_personal_workflow_skill.ps1'
$publishMentions = New-Object System.Collections.Generic.List[object]
foreach ($file in $sourceFiles) {
    if ($file.FullName -eq $publishScript) { continue }
    if ($file.FullName -eq $healthScript) { continue }
    $lines = Read-Utf8Lines $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'publish_personal_workflow_skill\.ps1') {
            $publishMentions.Add([pscustomobject]@{
                Location = "$(Get-RelativePath $file.FullName):$($i + 1)"
                Line = $lines[$i].Trim()
            }) | Out-Null
        }
    }
}

$unguardedPublishMentions = @($publishMentions | Where-Object {
    ($_.Line -notmatch [regex]::Escape($explicitTerm)) -and
    ($_.Line -notmatch [regex]::Escape($noPublishTerm)) -and
    ($_.Line -notmatch [regex]::Escape($noExecuteTerm)) -and
    ($_.Line -notmatch 'explicitly|only when|unless|Do not publish|publish script')
})

if ((Test-Path -LiteralPath $publishScript) -and $unguardedPublishMentions.Count -eq 0) {
    Add-Result 'No auto publish path' 'OK' "Publish script exists and $($publishMentions.Count) source mentions are guarded"
} elseif (-not (Test-Path -LiteralPath $publishScript)) {
    Add-Result 'No auto publish path' 'FAIL' 'Publish script is missing'
} else {
    Add-Result 'No auto publish path' 'FAIL' (($unguardedPublishMentions | ForEach-Object { $_.Location }) -join '; ')
}

$genericResidueTerms = @(
    '项目',
    'RIMO',
    '平顶山',
    '瞰车大',
    'PROJECT_AGENT',
    '资料索引',
    '项目索引',
    '项目路由',
    '项目规则',
    '项目接入',
    '项目知识库',
    '项目资料',
    '项目专属',
    '项目路径',
    '接项',
    '10-任务路由与项目索引.md',
    '20-项目接入.md',
    '34-同步交接与迁移复用.md',
    'project-management',
    'work-management',
    '$project-management',
    '$work-management',
    'Project Management',
    'Work Management',
    '我的项目管理',
    '我的工作管理'
)
$genericResidueRegex = ($genericResidueTerms | ForEach-Object { [regex]::Escape($_) }) -join '|'
$genericResidueHits = New-Object System.Collections.Generic.List[string]
foreach ($file in $sourceFiles) {
    if ($file.FullName -eq $healthScript) { continue }
    $lines = Read-Utf8Lines $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $genericResidueRegex) {
            $genericResidueHits.Add("$(Get-RelativePath $file.FullName):$($i + 1)") | Out-Null
        }
    }
}

if ($genericResidueHits.Count -eq 0) {
    Add-Result 'Generic management scope' 'OK' 'No old routing or source-specific residue remains in skill sources'
} else {
    Add-Result 'Generic management scope' 'FAIL' ($genericResidueHits -join '; ')
}

$results | Format-Table -AutoSize

if (($results | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0) {
    exit 1
}
