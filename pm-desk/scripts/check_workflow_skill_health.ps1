param(
    [string]$SkillRoot = (Split-Path -Parent $PSScriptRoot)
)

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$Utf8 = [System.Text.Encoding]::UTF8
$SkillRoot = (Resolve-Path -LiteralPath $SkillRoot).Path
$results = New-Object System.Collections.Generic.List[object]

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

function Read-ZipEntryText {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)
    $stream = $Entry.Open()
    $reader = [System.IO.StreamReader]::new($stream, $Utf8, $true)
    try {
        return $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Is-TemporaryPath {
    param([string]$Path)
    $relative = Get-RelativePath $Path
    return $relative -match '(^|[\\/])\.tmp-[^\\/]+'
}

$skillMd = Join-Path $SkillRoot 'SKILL.md'
$openaiYaml = Join-Path $SkillRoot 'agents/openai.yaml'
$triggerEvalsPath = Join-Path $SkillRoot 'evals/trigger-evals.json'
$behaviorEvalsPath = Join-Path $SkillRoot 'evals/behavior-evals.json'
$prototypeRoot = Join-Path $SkillRoot 'assets'
$prototypePath = Join-Path $prototypeRoot 'html-prototype-page.html'
$pptExamplePath = Join-Path $SkillRoot 'assets/pm-desk-business-deck-example.pptx'
$publishScript = Join-Path $SkillRoot 'scripts/publish_personal_workflow_skill.ps1'
$healthScript = $MyInvocation.MyCommand.Path

$requiredPaths = @(
    $skillMd,
    $openaiYaml,
    $triggerEvalsPath,
    $behaviorEvalsPath,
    $prototypePath,
    $pptExamplePath,
    $publishScript
)
$missingRequired = @($requiredPaths | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missingRequired.Count -eq 0) {
    Add-Result 'Required files' 'OK' "$($requiredPaths.Count) core files exist"
} else {
    Add-Result 'Required files' 'FAIL' (($missingRequired | ForEach-Object { Get-RelativePath $_ }) -join '; ')
}

$allFiles = @(Get-ChildItem -LiteralPath $SkillRoot -Recurse -File | Where-Object { -not (Is-TemporaryPath $_.FullName) })
$markdownFiles = @($allFiles | Where-Object { $_.Extension -eq '.md' })
if ($markdownFiles.Count -eq 1 -and $markdownFiles[0].FullName -eq $skillMd) {
    Add-Result 'Single Markdown source' 'OK' 'SKILL.md is the only Markdown file'
} else {
    Add-Result 'Single Markdown source' 'FAIL' (($markdownFiles | ForEach-Object { Get-RelativePath $_.FullName }) -join '; ')
}

$skillText = Read-Utf8Text $skillMd
$skillLines = (Read-Utf8Lines $skillMd).Count
$description = ''
if ($skillText -match '(?m)^description:\s*["'']?(.*?)["'']?\s*$') {
    $description = $Matches[1]
}
$descriptionWordCount = ([regex]::Matches($description, '[A-Za-z0-9_/-]+')).Count
if ($skillLines -le 340 -and $descriptionWordCount -le 100) {
    Add-Result 'Compact skill entry' 'OK' "SKILL.md lines=$skillLines; description words=$descriptionWordCount"
} else {
    Add-Result 'Compact skill entry' 'FAIL' "SKILL.md lines=$skillLines; description words=$descriptionWordCount"
}

$requiredHeadings = @(
    '## Core Idea',
    '## Freedom And Guardrails',
    '## Work Modes',
    '## Evidence Gate',
    '## Output Standard',
    '## PRD And Business Documents',
    '## HTML Prototype',
    '## PPT',
    '## Production Gate',
    '## Skill Maintenance'
)
$missingHeadings = @($requiredHeadings | Where-Object { $skillText -notmatch "(?m)^$([regex]::Escape($_))\s*$" })
if ($missingHeadings.Count -eq 0) {
    Add-Result 'Core operating sections' 'OK' "$($requiredHeadings.Count) core sections resolve in one file"
} else {
    Add-Result 'Core operating sections' 'FAIL' ($missingHeadings -join '; ')
}

try {
    $triggerEvals = (Read-Utf8Text $triggerEvalsPath) | ConvertFrom-Json
    $triggerCases = @($triggerEvals.cases)
    $badTriggerCases = @($triggerCases | Where-Object {
        [string]::IsNullOrWhiteSpace($_.id) -or
        [string]::IsNullOrWhiteSpace($_.prompt) -or
        [string]::IsNullOrWhiteSpace($_.expected_mode) -or
        [string]::IsNullOrWhiteSpace($_.expected_section)
    })
    if ($triggerCases.Count -ge 12 -and $badTriggerCases.Count -eq 0) {
        Add-Result 'Trigger eval fixture' 'OK' "$($triggerCases.Count) trigger cases use single-file sections"
    } else {
        Add-Result 'Trigger eval fixture' 'FAIL' "cases=$($triggerCases.Count); bad_cases=$($badTriggerCases.Count)"
    }
} catch {
    Add-Result 'Trigger eval fixture' 'FAIL' $_.Exception.Message
}

try {
    $behaviorEvals = (Read-Utf8Text $behaviorEvalsPath) | ConvertFrom-Json
    $behaviorCases = @($behaviorEvals.cases)
    $badBehaviorCases = @($behaviorCases | Where-Object {
        [string]::IsNullOrWhiteSpace($_.id) -or
        [string]::IsNullOrWhiteSpace($_.prompt) -or
        [string]::IsNullOrWhiteSpace($_.expected_gate) -or
        @($_.must_do).Count -eq 0 -or
        @($_.must_not).Count -eq 0
    })
    $requiredBehaviorGates = @('challenge_then_ask', 'ask_first', 'provisional_only', 'formal_delivery', 'creative_exploration')
    $presentBehaviorGates = @($behaviorCases | ForEach-Object { $_.expected_gate } | Sort-Object -Unique)
    $missingBehaviorGates = @($requiredBehaviorGates | Where-Object { $_ -notin $presentBehaviorGates })
    if ($behaviorCases.Count -ge 10 -and $badBehaviorCases.Count -eq 0 -and $missingBehaviorGates.Count -eq 0) {
        Add-Result 'Behavior eval fixture' 'OK' "$($behaviorCases.Count) cases cover evidence, brevity, creativity and delivery"
    } else {
        Add-Result 'Behavior eval fixture' 'FAIL' "cases=$($behaviorCases.Count); bad_cases=$($badBehaviorCases.Count); missing_gates=$($missingBehaviorGates -join ',')"
    }
} catch {
    Add-Result 'Behavior eval fixture' 'FAIL' $_.Exception.Message
}

$yamlText = Read-Utf8Text $openaiYaml
$displayName = ''
$shortDescription = ''
$defaultPrompt = ''
if ($yamlText -match '(?m)^\s*display_name:\s*["'']?(.*?)["'']?\s*$') {
    $displayName = $Matches[1]
}
if ($yamlText -match '(?m)^\s*short_description:\s*["'']?(.*?)["'']?\s*$') {
    $shortDescription = $Matches[1]
}
if ($yamlText -match '(?m)^\s*default_prompt:\s*["'']?(.*?)["'']?\s*$') {
    $defaultPrompt = $Matches[1]
}
$defaultPromptWords = ([regex]::Matches($defaultPrompt, '[A-Za-z0-9_/-]+')).Count
if ($displayName -eq 'PM Desk｜产品工作台' -and
    $shortDescription.Length -ge 25 -and $shortDescription.Length -le 64 -and
    $defaultPromptWords -le 100 -and $defaultPrompt -match 'creative freedom') {
    Add-Result 'UI metadata' 'OK' "display_name=$displayName; short_description chars=$($shortDescription.Length); default_prompt words=$defaultPromptWords"
} else {
    Add-Result 'UI metadata' 'FAIL' "display_name=$displayName; short_description chars=$($shortDescription.Length); default_prompt words=$defaultPromptWords"
}

$sourceFiles = @($allFiles | Where-Object {
    $_.Extension -in @('.md', '.yaml', '.yml', '.ps1', '.json') -and $_.FullName -ne $healthScript
})
$absolutePathPattern = '[A-Za-z]:[\\/]|/Users/|/home/|iCloudDrive|Obsidian Vault'
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
    Add-Result 'No local path residue' 'OK' 'No local machine or vault paths found in reusable sources'
} else {
    Add-Result 'No local path residue' 'FAIL' ($pathHits -join '; ')
}

$staleReferencePattern = 'references/|00-工作模式与个人方法|10-任务路由与上下文边界|20-事项接入与资料整理|30-交付总览|31-需求分析与PRD|32-方案PPT与模板|33-会议总结与知识沉淀|34-同步交接与复用|35-HTML原型与页面规范|90-工作流维护与自检'
$staleReferenceHits = New-Object System.Collections.Generic.List[string]
foreach ($file in $sourceFiles) {
    $lines = Read-Utf8Lines $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $staleReferencePattern) {
            $staleReferenceHits.Add("$(Get-RelativePath $file.FullName):$($i + 1)") | Out-Null
        }
    }
}
if ($staleReferenceHits.Count -eq 0) {
    Add-Result 'No stale reference routing' 'OK' 'No deleted reference paths remain'
} else {
    Add-Result 'No stale reference routing' 'FAIL' ($staleReferenceHits -join '; ')
}

$linkTargets = New-Object System.Collections.Generic.HashSet[string]
foreach ($match in [regex]::Matches($skillText, '`((scripts|assets)/[^`]+?\.(ps1|png|jpg|jpeg|webp|svg|html|pptx))`')) {
    $linkTargets.Add($match.Groups[1].Value) | Out-Null
}
$missingLinks = @($linkTargets | Where-Object {
    $local = Join-Path $SkillRoot ($_ -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    -not (Test-Path -LiteralPath $local -PathType Leaf)
})
if ($missingLinks.Count -eq 0) {
    Add-Result 'Bundled links' 'OK' "$($linkTargets.Count) linked assets/scripts resolve"
} else {
    Add-Result 'Bundled links' 'FAIL' ($missingLinks -join '; ')
}

$prototypeFiles = @(Get-ChildItem -LiteralPath $prototypeRoot -Filter '*.html' -File)
if ($prototypeFiles.Count -eq 1 -and $prototypeFiles[0].Name -eq 'html-prototype-page.html') {
    Add-Result 'Prototype template set' 'OK' 'The sole HTML master exists'
} else {
    Add-Result 'Prototype template set' 'FAIL' (($prototypeFiles | ForEach-Object { $_.Name }) -join '; ')
}

$prototypeText = Read-Utf8Text $prototypePath
$prototypeLines = Read-Utf8Lines $prototypePath
$selfClosingHits = New-Object System.Collections.Generic.List[string]
$tableLayoutHits = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $prototypeLines.Count; $i++) {
    if (($prototypeLines[$i] -match '<el-[A-Za-z0-9-]+\b[^>]*?/\s*>') -or
        ($prototypeLines[$i] -cmatch '<[A-Z][A-Za-z0-9-]*\b[^>]*?/\s*>')) {
        $selfClosingHits.Add("assets/html-prototype-page.html:$($i + 1)") | Out-Null
    }
    if ($prototypeLines[$i] -match 'overflow-x-auto|table-layout\s*=\s*[\"'']auto[\"'']') {
        $tableLayoutHits.Add("assets/html-prototype-page.html:$($i + 1)") | Out-Null
    }
}
if ($selfClosingHits.Count -eq 0) {
    Add-Result 'DOM component closing' 'OK' 'No self-closing custom components found'
} else {
    Add-Result 'DOM component closing' 'FAIL' ($selfClosingHits -join '; ')
}
if ($tableLayoutHits.Count -eq 0) {
    Add-Result 'Prototype table layout' 'OK' 'No competing overflow wrapper or table-layout=auto residue found'
} else {
    Add-Result 'Prototype table layout' 'FAIL' ($tableLayoutHits -join '; ')
}

$prototypeThemeIssues = New-Object System.Collections.Generic.List[string]
if ($prototypeText -notmatch '(?m)^\s*--app-color-primary:\s*#2563eb;\s*$') {
    $prototypeThemeIssues.Add('Missing #2563eb primary token') | Out-Null
}
if ($prototypeText -notmatch '(?s)\.prototype-sidebar\s*\{[^}]*background:\s*var\(--app-color-primary\);') {
    $prototypeThemeIssues.Add('Sidebar does not use the primary token') | Out-Null
}
if ($prototypeText -match '(?i)#086d9f') {
    $prototypeThemeIssues.Add('Legacy #086d9f remains') | Out-Null
}
if ($prototypeThemeIssues.Count -eq 0) {
    Add-Result 'Prototype primary theme' 'OK' 'Sidebar and controls share #2563eb'
} else {
    Add-Result 'Prototype primary theme' 'FAIL' ($prototypeThemeIssues -join '; ')
}

if (($prototypeText -match '>Admin<') -and ($prototypeText -match [regex]::Escape('退出登录'))) {
    Add-Result 'Prototype account header' 'OK' 'Avatar account label and logout entry exist'
} else {
    Add-Result 'Prototype account header' 'FAIL' 'Admin or logout entry is missing'
}

$textWithoutComments = [regex]::Replace($prototypeText, '<!--[\s\S]*?-->', '')
$prohibitedVisibleCopy = @('用一句话说明', '示例资料', '根据你刚才', '我们讨论', '页面设计思路', '待确认问题', '对话记录')
$visibleCopyHits = @($prohibitedVisibleCopy | Where-Object { $textWithoutComments -match [regex]::Escape($_) })
if ($visibleCopyHits.Count -eq 0) {
    Add-Result 'Prototype content boundary' 'OK' 'No analysis or production-note copy is visible'
} else {
    Add-Result 'Prototype content boundary' 'FAIL' ($visibleCopyHits -join '; ')
}

$pptxAssets = @($allFiles | Where-Object { $_.Extension -eq '.pptx' })
$pptPalette = @('#24364B', '#1F5AA6', '#0D2742', '#0F8B7C', '#E98A15', '#EEF4FA')
$missingPptTokens = @($pptPalette | Where-Object { $skillText -notmatch [regex]::Escape($_) })
$pptStructureIssues = New-Object System.Collections.Generic.List[string]
if ($pptxAssets.Count -ne 1 -or $pptxAssets[0].Name -ne 'pm-desk-business-deck-example.pptx') {
    $pptStructureIssues.Add("Expected exactly assets/pm-desk-business-deck-example.pptx; found $($pptxAssets.Count) PPTX files") | Out-Null
} elseif (Test-Path -LiteralPath $pptExamplePath -PathType Leaf) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($pptExamplePath)
    try {
        $slideEntries = @($archive.Entries | Where-Object { $_.FullName -match '^ppt/slides/slide\d+\.xml$' })
        $masterEntries = @($archive.Entries | Where-Object { $_.FullName -match '^ppt/slideMasters/slideMaster\d+\.xml$' })
        $layoutEntries = @($archive.Entries | Where-Object { $_.FullName -match '^ppt/slideLayouts/slideLayout\d+\.xml$' })
        if ($slideEntries.Count -ne 1) { $pptStructureIssues.Add("Expected one authored slide; found $($slideEntries.Count)") | Out-Null }
        if ($masterEntries.Count -ne 1) { $pptStructureIssues.Add("Expected one native master; found $($masterEntries.Count)") | Out-Null }
        if ($layoutEntries.Count -ne 1) { $pptStructureIssues.Add("Expected one native layout; found $($layoutEntries.Count)") | Out-Null }

        $masterXml = ($masterEntries | ForEach-Object { Read-ZipEntryText $_ }) -join "`n"
        $slideXml = ($slideEntries | ForEach-Object { Read-ZipEntryText $_ }) -join "`n"
        foreach ($fixedName in @('master-title-band', 'master-title-underline')) {
            if ($masterXml -notmatch [regex]::Escape($fixedName)) {
                $pptStructureIssues.Add("Missing $fixedName in native master") | Out-Null
            }
            if ($slideXml -match [regex]::Escape($fixedName)) {
                $pptStructureIssues.Add("$fixedName is duplicated on the authored slide") | Out-Null
            }
        }
        foreach ($masterColor in @('FFFFFF', '1F5AA6', '0F8B7C')) {
            if ($masterXml -notmatch $masterColor) {
                $pptStructureIssues.Add("Missing master color $masterColor") | Out-Null
            }
        }
        if ($slideXml -match '<p:bg(?:\s|>)') {
            $pptStructureIssues.Add('Authored slide contains a slide-local background') | Out-Null
        }
    } catch {
        $pptStructureIssues.Add($_.Exception.Message) | Out-Null
    } finally {
        $archive.Dispose()
    }
}

if ($pptStructureIssues.Count -eq 0 -and
    $missingPptTokens.Count -eq 0 -and
    $skillText -match 'one-slide visual anchor' -and
    $skillText -match 'native PowerPoint Slide Master or Layout') {
    Add-Result 'PPT visual baseline' 'OK' 'One-slide visual anchor uses one native Master/Layout; fixed backgrounds are not slide-local'
} else {
    Add-Result 'PPT visual baseline' 'FAIL' "issues=$($pptStructureIssues -join '; '); missing_tokens=$($missingPptTokens -join ',')"
}

$requiredContracts = @(
    'preserve room for invention',
    'title/cover -> version record -> table of contents when needed -> body',
    'Never write Obsidian automatically',
    'Do not publish, install or sync this Skill unless the user explicitly says to do so',
    'native PowerPoint Slide Master or Layout',
    'Render and inspect every final slide',
    'open it in a real browser'
)
$missingContracts = @($requiredContracts | Where-Object { $skillText -notmatch [regex]::Escape($_) })
if ($missingContracts.Count -eq 0) {
    Add-Result 'Core contracts' 'OK' "$($requiredContracts.Count) safety and production contracts resolve"
} else {
    Add-Result 'Core contracts' 'FAIL' ($missingContracts -join '; ')
}

$sourceResidueTerms = @('workdesk', 'RIMO', '平顶山', 'project-management', 'work-management', 'Project Management', '我的项目管理')
$sourceResidueRegex = ($sourceResidueTerms | ForEach-Object { [regex]::Escape($_) }) -join '|'
$sourceResidueHits = New-Object System.Collections.Generic.List[string]
foreach ($file in $sourceFiles) {
    $lines = Read-Utf8Lines $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sourceResidueRegex) {
            $sourceResidueHits.Add("$(Get-RelativePath $file.FullName):$($i + 1)") | Out-Null
        }
    }
}
if ($sourceResidueHits.Count -eq 0) {
    Add-Result 'No source-specific residue' 'OK' 'No old skill name or source-specific topic remains'
} else {
    Add-Result 'No source-specific residue' 'FAIL' ($sourceResidueHits -join '; ')
}

$publishMentions = New-Object System.Collections.Generic.List[string]
foreach ($file in $sourceFiles) {
    if ($file.FullName -eq $publishScript) { continue }
    $lines = Read-Utf8Lines $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'publish_personal_workflow_skill\.ps1') {
            $publishMentions.Add("$(Get-RelativePath $file.FullName):$($i + 1)") | Out-Null
        }
    }
}
if ((Test-Path -LiteralPath $publishScript) -and $publishMentions.Count -eq 0) {
    Add-Result 'No automatic publish path' 'OK' 'Publish script exists but is not routed from reusable instructions'
} elseif (-not (Test-Path -LiteralPath $publishScript)) {
    Add-Result 'No automatic publish path' 'FAIL' 'Publish script is missing'
} else {
    Add-Result 'No automatic publish path' 'FAIL' ($publishMentions -join '; ')
}

$publishText = Read-Utf8Text $publishScript
if ($publishText -match [regex]::Escape("Join-Path (Split-Path -Parent `$resolvedSkillHome) 'skill-backups'") -and
    $publishText -match 'BackupHome must be outside the Skills directory') {
    Add-Result 'Backup isolation' 'OK' 'Installed-skill backups are kept outside the Skills scan directory'
} else {
    Add-Result 'Backup isolation' 'FAIL' 'Publish script can leave backups inside the Skills scan directory'
}

$results | Format-Table -AutoSize
if (($results | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0) {
    exit 1
}
