param(
    [Parameter(Mandatory = $true)]
    [string]$BaseDocx,

    [Parameter(Mandatory = $true)]
    [string]$ReplacementDocx,

    [Parameter(Mandatory = $true)]
    [string]$OutputDocx,

    [string]$StartRegex = '^第\s*3章',
    [string]$EndRegex = '^第\s*7章',
    [string]$BackupDocx
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

function Get-ParagraphText {
    param(
        [System.Xml.XmlNode]$Paragraph
    )

    $parts = @($Paragraph.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText })
    return ($parts -join '').Trim()
}

function Find-ParagraphNodeByRegex {
    param(
        [System.Xml.XmlNode]$Body,
        [string]$Regex
    )

    foreach ($child in $Body.ChildNodes) {
        if ($child.LocalName -ne 'p' -or $child.NamespaceURI -ne $WordNs) {
            continue
        }

        $text = Get-ParagraphText -Paragraph $child
        if ($text -match $Regex) {
            return $child
        }
    }

    return $null
}

if (-not (Test-Path -LiteralPath $BaseDocx)) {
    throw "Base docx not found: $BaseDocx"
}
if (-not (Test-Path -LiteralPath $ReplacementDocx)) {
    throw "Replacement docx not found: $ReplacementDocx"
}

$resolvedBase = (Resolve-Path -LiteralPath $BaseDocx).Path
$resolvedReplacement = (Resolve-Path -LiteralPath $ReplacementDocx).Path
$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDocx))

if ($BackupDocx) {
    $resolvedBackup = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $BackupDocx))
    Copy-Item -LiteralPath $resolvedBase -Destination $resolvedBackup -Force
}

$guid = [Guid]::NewGuid().ToString('N')
$baseDir = Join-Path (Get-Location) (".tmp\\merge_base_" + $guid)
$replaceDir = Join-Path (Get-Location) (".tmp\\merge_replace_" + $guid)
$outZip = Join-Path (Get-Location) (".tmp\\merge_out_" + $guid + '.zip')
$baseZip = Join-Path (Get-Location) (".tmp\\merge_base_" + $guid + '.zip')
$replaceZip = Join-Path (Get-Location) (".tmp\\merge_replace_" + $guid + '.zip')

try {
    if (Test-Path -LiteralPath $baseDir) { Remove-Item -LiteralPath $baseDir -Recurse -Force }
    if (Test-Path -LiteralPath $replaceDir) { Remove-Item -LiteralPath $replaceDir -Recurse -Force }
    if (Test-Path -LiteralPath $outZip) { Remove-Item -LiteralPath $outZip -Force }
    if (Test-Path -LiteralPath $baseZip) { Remove-Item -LiteralPath $baseZip -Force }
    if (Test-Path -LiteralPath $replaceZip) { Remove-Item -LiteralPath $replaceZip -Force }

    Copy-Item -LiteralPath $resolvedBase -Destination $baseZip -Force
    Copy-Item -LiteralPath $resolvedReplacement -Destination $replaceZip -Force
    Expand-Archive -LiteralPath $baseZip -DestinationPath $baseDir -Force
    Expand-Archive -LiteralPath $replaceZip -DestinationPath $replaceDir -Force

    $baseDocXmlPath = Join-Path $baseDir 'word\\document.xml'
    $replaceDocXmlPath = Join-Path $replaceDir 'word\\document.xml'

    [xml]$baseDoc = Get-Content -LiteralPath $baseDocXmlPath -Raw -Encoding UTF8
    [xml]$replaceDoc = Get-Content -LiteralPath $replaceDocXmlPath -Raw -Encoding UTF8

    $baseBody = $baseDoc.DocumentElement.SelectSingleNode('//*[local-name()="body"]')
    $replaceBody = $replaceDoc.DocumentElement.SelectSingleNode('//*[local-name()="body"]')

    if ($null -eq $baseBody -or $null -eq $replaceBody) {
        throw 'Missing w:body node in one of documents.'
    }

    $startNode = Find-ParagraphNodeByRegex -Body $baseBody -Regex $StartRegex
    if ($null -eq $startNode) {
        throw "Start chapter not found by regex: $StartRegex"
    }

    $endNode = Find-ParagraphNodeByRegex -Body $baseBody -Regex $EndRegex
    if ($null -eq $endNode) {
        throw "End chapter not found by regex: $EndRegex"
    }

    $current = $startNode
    while ($null -ne $current -and $current -ne $endNode) {
        $next = $current.NextSibling
        [void]$baseBody.RemoveChild($current)
        $current = $next
    }

    if ($null -eq $current) {
        throw 'Chapter range removal failed: end node not reachable after start node.'
    }

    foreach ($node in $replaceBody.ChildNodes) {
        if ($node.LocalName -eq 'sectPr' -and $node.NamespaceURI -eq $WordNs) {
            continue
        }
        $imported = $baseDoc.ImportNode($node, $true)
        [void]$baseBody.InsertBefore($imported, $endNode)
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($baseDocXmlPath, $baseDoc.OuterXml, $utf8NoBom)

    $replaceRelsPath = Join-Path $replaceDir 'word\\_rels\\document.xml.rels'
    $baseRelsPath = Join-Path $baseDir 'word\\_rels\\document.xml.rels'
    Copy-Item -LiteralPath $replaceRelsPath -Destination $baseRelsPath -Force

    $replaceContentTypesPath = Join-Path $replaceDir '[Content_Types].xml'
    $baseContentTypesPath = Join-Path $baseDir '[Content_Types].xml'
    Copy-Item -LiteralPath $replaceContentTypesPath -Destination $baseContentTypesPath -Force

    $replaceMediaDir = Join-Path $replaceDir 'word\\media'
    $baseMediaDir = Join-Path $baseDir 'word\\media'
    if (Test-Path -LiteralPath $replaceMediaDir) {
        if (-not (Test-Path -LiteralPath $baseMediaDir)) {
            New-Item -ItemType Directory -Path $baseMediaDir | Out-Null
        }
        Copy-Item -Path (Join-Path $replaceMediaDir '*') -Destination $baseMediaDir -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($baseDir, $outZip)

    if (Test-Path -LiteralPath $resolvedOutput) {
        Remove-Item -LiteralPath $resolvedOutput -Force
    }
    Move-Item -LiteralPath $outZip -Destination $resolvedOutput -Force

    Write-Output ("merged-docx: " + $resolvedOutput)
    if ($BackupDocx) {
        Write-Output ("backup-docx: " + $resolvedBackup)
    }
}
finally {
    if (Test-Path -LiteralPath $baseDir) { Remove-Item -LiteralPath $baseDir -Recurse -Force }
    if (Test-Path -LiteralPath $replaceDir) { Remove-Item -LiteralPath $replaceDir -Recurse -Force }
    if (Test-Path -LiteralPath $outZip) { Remove-Item -LiteralPath $outZip -Force }
    if (Test-Path -LiteralPath $baseZip) { Remove-Item -LiteralPath $baseZip -Force }
    if (Test-Path -LiteralPath $replaceZip) { Remove-Item -LiteralPath $replaceZip -Force }
}
