param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Text {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $value = $Text -replace '\r', ''
    $value = $value -replace '[ \t]+', ' '
    return $value.Trim()
}

function Get-ParagraphStyle {
    param(
        [System.Xml.XmlNode]$Paragraph
    )

    $styleNode = $Paragraph.SelectSingleNode('./*[local-name()="pPr"]/*[local-name()="pStyle"]')
    if ($null -eq $styleNode) {
        return ''
    }

    $styleValue = $styleNode.Attributes.GetNamedItem('w:val')
    if ($null -eq $styleValue) {
        return ''
    }

    return [string]$styleValue.Value
}

function Get-ParagraphText {
    param(
        [System.Xml.XmlNode]$Paragraph
    )

    $builder = New-Object System.Text.StringBuilder
    foreach ($node in $Paragraph.SelectNodes('.//*[local-name()="t" or local-name()="tab" or local-name()="br" or local-name()="cr" or local-name()="noBreakHyphen" or local-name()="sym"]')) {
        switch ($node.Name) {
            'w:t' {
                [void]$builder.Append($node.InnerText)
            }
            'w:tab' {
                [void]$builder.Append("`t")
            }
            'w:br' {
                [void]$builder.Append("`n")
            }
            'w:cr' {
                [void]$builder.Append("`n")
            }
            'w:noBreakHyphen' {
                [void]$builder.Append('-')
            }
            'w:sym' {
                [void]$builder.Append(' ')
            }
        }
    }

    return Normalize-Text -Text $builder.ToString()
}

function Get-CellText {
    param(
        [System.Xml.XmlNode]$Cell
    )

    $parts = @()
    foreach ($paragraph in $Cell.SelectNodes('./*[local-name()="p"]')) {
        $text = Get-ParagraphText -Paragraph $paragraph
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $parts += $text
        }
    }

    return (($parts -join '<br>') -replace '\|', '\|').Trim()
}

function Convert-ParagraphToMarkdown {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [bool]$TreatAsDocumentTitle = $false
    )

    $style = Get-ParagraphStyle -Paragraph $Paragraph
    $text = Get-ParagraphText -Paragraph $Paragraph
    $hasDrawing = $Paragraph.SelectNodes('.//*[local-name()="drawing"]').Count -gt 0

    if ([string]::IsNullOrWhiteSpace($text)) {
        if ($hasDrawing) {
            return '[image]'
        }
        return ''
    }

    if ($TreatAsDocumentTitle) {
        return "# $text"
    }

    switch -Regex ($style) {
        '^Heading1$' { return "# $text" }
        '^Heading2$' { return "## $text" }
        '^Heading3$' { return "### $text" }
        '^Title$' { return "# $text" }
        default {
            if ($text -match '^第[0-9一二三四五六七八九十]+章\s+') {
                return "# $text"
            }
            if ($text -match '^\d+\.\d+\.\d+\s+') {
                return "### $text"
            }
            if ($text -match '^\d+\.\d+\s+') {
                return "## $text"
            }

            $numNode = $Paragraph.SelectSingleNode('./*[local-name()="pPr"]/*[local-name()="numPr"]')
            if ($null -ne $numNode) {
                return "- $text"
            }

            return $text
        }
    }
}

function Convert-TableToMarkdown {
    param(
        [System.Xml.XmlNode]$Table
    )

    $rows = @()
    foreach ($row in $Table.SelectNodes('./*[local-name()="tr"]')) {
        $cells = @()
        foreach ($cell in $row.SelectNodes('./*[local-name()="tc"]')) {
            $cells += (Get-CellText -Cell $cell)
        }
        if ($cells.Count -gt 0) {
            $rows += ,$cells
        }
    }

    if ($rows.Count -eq 0) {
        return @()
    }

    $columnCount = ($rows | Measure-Object -Maximum Length).Maximum
    $normalizedRows = @()
    foreach ($row in $rows) {
        $current = @($row)
        while ($current.Count -lt $columnCount) {
            $current += ''
        }
        $normalizedRows += ,$current
    }

    $lines = @()
    $header = $normalizedRows[0]
    $lines += '| ' + ($header -join ' | ') + ' |'
    $lines += '| ' + ((1..$columnCount | ForEach-Object { '---' }) -join ' | ') + ' |'

    if ($normalizedRows.Count -gt 1) {
        foreach ($row in $normalizedRows[1..($normalizedRows.Count - 1)]) {
            $lines += '| ' + ($row -join ' | ') + ' |'
        }
    }

    return $lines
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$outputDirectory = Split-Path -Parent $outputFullPath

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('docx-md-' + [guid]::NewGuid().ToString('N'))

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedInput, $tempRoot)

    $documentXmlPath = Join-Path $tempRoot 'word\document.xml'
    [xml]$documentXml = Get-Content -LiteralPath $documentXmlPath -Raw -Encoding UTF8
    $root = [System.Xml.XmlNode]$documentXml.DocumentElement
    $body = $root.SelectSingleNode('./*[local-name()="body"]')
    if ($null -eq $body) {
        throw 'Missing body node in document.xml.'
    }

    $lines = New-Object System.Collections.Generic.List[string]

    $seenContent = $false
    foreach ($child in $body.ChildNodes) {
        switch ($child.Name) {
            'w:p' {
                $line = Convert-ParagraphToMarkdown -Paragraph $child -TreatAsDocumentTitle (-not $seenContent)
                if ($line -eq '') {
                    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') {
                        $lines.Add('')
                    }
                }
                else {
                    $lines.Add($line)
                    $lines.Add('')
                    $seenContent = $true
                }
            }
            'w:tbl' {
                $tableLines = Convert-TableToMarkdown -Table $child
                foreach ($tableLine in $tableLines) {
                    $lines.Add($tableLine)
                }
                $lines.Add('')
                $seenContent = $true
            }
        }
    }

    while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
        $lines.RemoveAt($lines.Count - 1)
    }

    $content = [string]::Join([Environment]::NewLine, $lines)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outputFullPath, $content, $utf8NoBom)
    Write-Output "Converted to $outputFullPath"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
