param(
    [Parameter(Mandatory = $true)]
    [string]$TemplateDocx,

    [Parameter(Mandatory = $true)]
    [string]$OutputDocx,

    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,

    [string]$RenderedFigureDir = ".rendered_figures\current"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Escape-XmlText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

function Normalize-CaptionText {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $value = $Text.Trim()
    $value = $value -replace '<[^>]+>', ''
    return $value.Trim()
}

function Test-IsFigureCaption {
    param([string]$Text)
    $value = Normalize-CaptionText -Text $Text
    return $value -match '^\u56FE\s*\d+\s*-\s*\d+'
}

function Test-IsChapterLine {
    param([string]$Text)
    return $Text.Trim() -match '^\u7B2C\s*\d+\u7AE0\s+'
}

function New-RunXml {
    param(
        [string]$Text,
        [string]$AsciiFont = "Times New Roman",
        [string]$EastAsiaFont = "SimSun",
        [int]$Size = 24,
        [bool]$Bold = $false
    )

    $boldXml = ""
    if ($Bold) { $boldXml = "<w:b/><w:bCs/>" }

    $escaped = Escape-XmlText $Text
    return '<w:r><w:rPr><w:rFonts w:ascii="{0}" w:hAnsi="{0}" w:eastAsia="{1}"/><w:sz w:val="{2}"/><w:szCs w:val="{2}"/>{3}</w:rPr><w:t xml:space="preserve">{4}</w:t></w:r>' -f $AsciiFont, $EastAsiaFont, $Size, $boldXml, $escaped
}

function New-ParagraphXml {
    param(
        [string]$Text,
        [ValidateSet("title", "chapter", "section", "subsection", "body", "label", "code", "caption")]
        [string]$Kind
    )

    switch ($Kind) {
        "title" {
            $pPr = '<w:pPr><w:jc w:val="center"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 32 -Bold $true
        }
        "chapter" {
            $pPr = '<w:pPr><w:pageBreakBefore/><w:jc w:val="center"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 32 -Bold $true
        }
        "section" {
            $pPr = '<w:pPr><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 28 -Bold $true
        }
        "subsection" {
            $pPr = '<w:pPr><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 24 -Bold $true
        }
        "body" {
            $pPr = '<w:pPr><w:ind w:firstLineChars="200"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 24
        }
        "label" {
            $pPr = '<w:pPr><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 24 -Bold $true
        }
        "code" {
            $pPr = '<w:pPr><w:spacing w:line="320" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
            $run = New-RunXml -Text $Text -AsciiFont "Courier New" -EastAsiaFont "SimSun" -Size 20
        }
        "caption" {
            $pPr = '<w:pPr><w:jc w:val="center"/><w:spacing w:line="320" w:lineRule="exact" w:before="120" w:after="60"/></w:pPr>'
            $run = New-RunXml -Text $Text -Size 22 -Bold $true
        }
    }

    return "<w:p>$pPr$run</w:p>"
}

function New-TableCellXml {
    param(
        [string]$Text,
        [int]$Width,
        [bool]$Bold = $false
    )

    $paragraphStyle = '<w:pPr><w:jc w:val="center"/><w:spacing w:line="400" w:lineRule="exact" w:before="0" w:after="0"/></w:pPr>'
    $run = New-RunXml -Text $Text -Size 22 -Bold $Bold
    return '<w:tc><w:tcPr><w:tcW w:w="{0}" w:type="dxa"/></w:tcPr><w:p>{1}{2}</w:p></w:tc>' -f $Width, $paragraphStyle, $run
}

function New-TableXml {
    param([object[]]$Rows)

    if ($Rows.Count -lt 2) { return "" }

    $columnCount = $Rows[0].Count
    $baseWidth = [int][math]::Floor(9070 / $columnCount)
    $widths = @()
    for ($i = 0; $i -lt $columnCount; $i++) { $widths += $baseWidth }
    $widths[$columnCount - 1] += 9070 - ($baseWidth * $columnCount)

    $grid = ($widths | ForEach-Object { '<w:gridCol w:w="{0}"/>' -f $_ }) -join ""
    $tableBuilder = New-Object System.Text.StringBuilder
    [void]$tableBuilder.Append('<w:tbl>')
    [void]$tableBuilder.Append('<w:tblPr><w:tblW w:w="9070" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="12" w:space="0" w:color="000000"/><w:left w:val="nil"/><w:bottom w:val="single" w:sz="12" w:space="0" w:color="000000"/><w:right w:val="nil"/><w:insideH w:val="single" w:sz="6" w:space="0" w:color="000000"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr>')
    [void]$tableBuilder.Append('<w:tblGrid>')
    [void]$tableBuilder.Append($grid)
    [void]$tableBuilder.Append('</w:tblGrid>')

    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        $row = $Rows[$rowIndex]
        [void]$tableBuilder.Append('<w:tr>')
        for ($colIndex = 0; $colIndex -lt $columnCount; $colIndex++) {
            $cellText = if ($colIndex -lt $row.Count) { [string]$row[$colIndex] } else { "" }
            [void]$tableBuilder.Append((New-TableCellXml -Text $cellText -Width $widths[$colIndex] -Bold ($rowIndex -eq 0)))
        }
        [void]$tableBuilder.Append('</w:tr>')
    }

    [void]$tableBuilder.Append('</w:tbl>')
    return $tableBuilder.ToString()
}

function Convert-TableLinesToXml {
    param([string[]]$TableLines)

    $rows = @()
    foreach ($line in $TableLines) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        $cells = @($trimmed.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $isSeparator = $true
        foreach ($cell in $cells) {
            if ($cell -notmatch '^:?-{3,}:?$') {
                $isSeparator = $false
                break
            }
        }
        if ($isSeparator) { continue }
        $rows += ,$cells
    }

    return New-TableXml -Rows $rows
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Ensure-PngContentType {
    param([xml]$ContentTypesXml)
    $exists = $ContentTypesXml.Types.Default | Where-Object { $_.Extension -eq "png" }
    if (-not $exists) {
        $node = $ContentTypesXml.CreateElement("Default", $ContentTypesXml.Types.NamespaceURI)
        [void]$node.SetAttribute("Extension", "png")
        [void]$node.SetAttribute("ContentType", "image/png")
        [void]$ContentTypesXml.Types.AppendChild($node)
    }
}

function Get-NextRelationshipId {
    param([xml]$RelationshipsXml)
    $max = 0
    foreach ($rel in $RelationshipsXml.Relationships.Relationship) {
        if ($rel.Id -match '^rId(\d+)$') {
            $value = [int]$matches[1]
            if ($value -gt $max) { $max = $value }
        }
    }
    return "rId{0}" -f ($max + 1)
}

function Add-ImageRelationship {
    param(
        [xml]$RelationshipsXml,
        [string]$Target
    )

    $relId = Get-NextRelationshipId -RelationshipsXml $RelationshipsXml
    $node = $RelationshipsXml.CreateElement("Relationship", $RelationshipsXml.Relationships.NamespaceURI)
    [void]$node.SetAttribute("Id", $relId)
    [void]$node.SetAttribute("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image")
    [void]$node.SetAttribute("Target", $Target)
    [void]$RelationshipsXml.Relationships.AppendChild($node)
    return $relId
}

function Get-ImageSizeEmu {
    param([string]$Path)

    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Image]::FromFile((Resolve-Path $Path))
    try {
        $widthPx = [double]$image.Width
        $heightPx = [double]$image.Height
        $maxWidthEmu = 5486400
        $emuPerPixel = 9525
        $widthEmu = [int]($widthPx * $emuPerPixel)
        $heightEmu = [int]($heightPx * $emuPerPixel)
        if ($widthEmu -gt $maxWidthEmu) {
            $scale = $maxWidthEmu / $widthEmu
            $widthEmu = [int]($widthEmu * $scale)
            $heightEmu = [int]($heightEmu * $scale)
        }
        return @{ Width = $widthEmu; Height = $heightEmu }
    }
    finally {
        $image.Dispose()
    }
}

function New-ImageParagraphXml {
    param(
        [string]$RelId,
        [int]$WidthEmu,
        [int]$HeightEmu,
        [int]$DocPrId
    )

    $name = "Figure $DocPrId"
    return @"
<w:p>
  <w:pPr>
    <w:jc w:val="center"/>
    <w:spacing w:line="240" w:lineRule="auto" w:before="120" w:after="60"/>
  </w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="$WidthEmu" cy="$HeightEmu"/>
        <wp:docPr id="$DocPrId" name="$name"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="$name"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$RelId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="$WidthEmu" cy="$HeightEmu"/>
                </a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"@
}

function Ensure-RenderedFigure {
    param(
        [string]$Caption,
        [string[]]$MermaidLines,
        [string]$FigureDir
    )

    Ensure-Directory -Path $FigureDir
    $safeName = ($Caption -replace '[\\/:*?"<>|]', '_')
    $mmdPath = Join-Path $FigureDir ($safeName + ".mmd")
    $pngPath = Join-Path $FigureDir ($safeName + ".png")

    [System.IO.File]::WriteAllText($mmdPath, ($MermaidLines -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
    & mmdc -i $mmdPath -o $pngPath | Out-Null
    if (-not (Test-Path $pngPath)) {
        throw "Mermaid 渲染失败: $Caption"
    }
    return $pngPath
}

function Convert-MarkdownToWordXml {
    param(
        [string]$MarkdownPath,
        [string]$WorkDir,
        [xml]$RelationshipsXml,
        [xml]$ContentTypesXml,
        [ref]$DocPrCounter,
        [string]$FigureDir
    )

    $lines = Get-Content -Path $MarkdownPath -Encoding UTF8
    $builder = New-Object System.Text.StringBuilder
    $mediaDir = Join-Path $WorkDir "word\media"
    Ensure-Directory -Path $mediaDir

    $inCodeBlock = $false
    $codeLang = ""
    $codeLines = @()
    $seenFirstH1 = $false
    $pendingMermaid = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^```(.*)$') {
            if (-not $inCodeBlock) {
                $inCodeBlock = $true
                $codeLang = $matches[1].Trim()
                $codeLines = @()
                continue
            }

            $inCodeBlock = $false
            if ($codeLang -eq "mermaid") {
                $captionLine = ""
                $j = $i + 1
                while ($j -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$j])) { $j++ }
                if ($j -lt $lines.Count) {
                    $normalizedCaption = Normalize-CaptionText -Text $lines[$j]
                    if (Test-IsFigureCaption -Text $normalizedCaption) {
                        $captionLine = $normalizedCaption
                        $i = $j
                    }
                }

                if (-not $captionLine) {
                    foreach ($codeLine in $codeLines) {
                        [void]$builder.Append((New-ParagraphXml -Text $codeLine -Kind "code"))
                    }
                    continue
                }

                $rendered = Ensure-RenderedFigure -Caption $captionLine -MermaidLines $codeLines -FigureDir $FigureDir
                Ensure-PngContentType -ContentTypesXml $ContentTypesXml

                $extension = [System.IO.Path]::GetExtension($rendered)
                $mediaName = "figure_{0:D3}{1}" -f $DocPrCounter.Value, $extension
                $targetMediaPath = Join-Path $mediaDir $mediaName
                Copy-Item -LiteralPath $rendered -Destination $targetMediaPath -Force

                $relId = Add-ImageRelationship -RelationshipsXml $RelationshipsXml -Target ("media/" + $mediaName)
                $size = Get-ImageSizeEmu -Path $targetMediaPath
                [void]$builder.Append((New-ImageParagraphXml -RelId $relId -WidthEmu $size.Width -HeightEmu $size.Height -DocPrId $DocPrCounter.Value))
                [void]$builder.Append((New-ParagraphXml -Text $captionLine -Kind "caption"))
                $DocPrCounter.Value++
            }
            else {
                foreach ($codeLine in $codeLines) {
                    [void]$builder.Append((New-ParagraphXml -Text $codeLine -Kind "code"))
                }
            }

            $codeLang = ""
            $codeLines = @()
            continue
        }

        if ($inCodeBlock) {
            $codeLines += $line
            continue
        }

        if ($line -match '^\|') {
            $tableLines = @()
            while ($i -lt $lines.Count -and $lines[$i] -match '^\|') {
                $tableLines += $lines[$i]
                $i++
            }
            $i--
            [void]$builder.Append((Convert-TableLinesToXml -TableLines $tableLines))
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line) -or $line -eq '---') { continue }

        $normalizedLine = Normalize-CaptionText -Text $line
        if (Test-IsFigureCaption -Text $normalizedLine) {
            continue
        }

        if (Test-IsChapterLine -Text $line) {
            if (-not $seenFirstH1) {
                [void]$builder.Append((New-ParagraphXml -Text $line.Trim() -Kind "title"))
            }
            else {
                [void]$builder.Append((New-ParagraphXml -Text $line.Trim() -Kind "chapter"))
            }
            $seenFirstH1 = $true
            continue
        }

        if ($line -match '^# (.+)$') {
            $heading = $matches[1]
            if (-not $seenFirstH1 -and -not $heading.StartsWith([string][char]0x7B2C)) {
                [void]$builder.Append((New-ParagraphXml -Text $heading -Kind "title"))
            }
            else {
                [void]$builder.Append((New-ParagraphXml -Text $heading -Kind "chapter"))
            }
            $seenFirstH1 = $true
            continue
        }

        if ($line -match '^## (.+)$') {
            [void]$builder.Append((New-ParagraphXml -Text $matches[1] -Kind "section"))
            continue
        }

        if ($line -match '^### (.+)$') {
            [void]$builder.Append((New-ParagraphXml -Text $matches[1] -Kind "subsection"))
            continue
        }

        if ($line -match '^\*\*(.+)\*\*$') {
            [void]$builder.Append((New-ParagraphXml -Text $matches[1] -Kind "label"))
            continue
        }

        [void]$builder.Append((New-ParagraphXml -Text $line -Kind "body"))
    }

    return $builder.ToString()
}

if (-not (Test-Path $TemplateDocx)) { throw "Template docx not found: $TemplateDocx" }
if (-not (Test-Path $MarkdownPath)) { throw "Markdown file not found: $MarkdownPath" }

$workZip = ".docx_write_full.zip"
$workDir = ".docx_write_full"
$xmlPath = Join-Path $workDir "word\document.xml"
$relsPath = Join-Path $workDir "word\_rels\document.xml.rels"
$contentTypesPath = Join-Path $workDir "[Content_Types].xml"

if (Test-Path $workDir) { Remove-Item -Recurse -Force $workDir }
if (Test-Path $workZip) { Remove-Item -Force $workZip }
if (Test-Path $OutputDocx) { Remove-Item -Force $OutputDocx }

Copy-Item -LiteralPath $TemplateDocx -Destination $workZip -Force
Expand-Archive -LiteralPath $workZip -DestinationPath $workDir -Force

[xml]$relsXml = [System.IO.File]::ReadAllText((Resolve-Path $relsPath), [System.Text.Encoding]::UTF8)
[xml]$contentTypesXml = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $contentTypesPath), [System.Text.Encoding]::UTF8)
$docPrCounter = [ref]1

$contentXml = Convert-MarkdownToWordXml -MarkdownPath $MarkdownPath -WorkDir $workDir -RelationshipsXml $relsXml -ContentTypesXml $contentTypesXml -DocPrCounter $docPrCounter -FigureDir $RenderedFigureDir

$docXml = [System.IO.File]::ReadAllText((Resolve-Path $xmlPath), [System.Text.Encoding]::UTF8)
$bodyStart = $docXml.IndexOf('<w:body>')
$bodyEnd = $docXml.IndexOf('</w:body>')
if ($bodyStart -lt 0 -or $bodyEnd -lt 0) { throw "document.xml body not found" }

$sectMatches = [regex]::Matches($docXml, '<w:sectPr\b[^>]*>.*?</w:sectPr>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($sectMatches.Count -eq 0) { throw "sectPr not found" }
$sectPr = $sectMatches[$sectMatches.Count - 1].Value

$prefix = $docXml.Substring(0, $bodyStart + 8)
$suffix = $docXml.Substring($bodyEnd)
$newXml = $prefix + $contentXml + $sectPr + $suffix

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($xmlPath, $newXml, $utf8NoBom)
$relsXml.Save($relsPath)
$contentTypesXml.Save($contentTypesPath)

if (Test-Path $workZip) { Remove-Item -Force $workZip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $workZip)
Move-Item -LiteralPath $workZip -Destination $OutputDocx
Remove-Item -Recurse -Force $workDir

Write-Output ("output-docx: " + (Resolve-Path $OutputDocx))
Write-Output ("markdown: " + (Resolve-Path $MarkdownPath))
Write-Output ("figures-dir: " + $RenderedFigureDir)
