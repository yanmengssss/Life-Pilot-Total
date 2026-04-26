$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = "F:\Graduation Project"
$docxPath = (
    Get-ChildItem -LiteralPath $root -Filter "*.docx" |
    Where-Object { $_.Name -like "*Next.js*" -and $_.Name -notlike "*copy*" -and $_.Name -notlike "*.repaired*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
).FullName

if (-not $docxPath) {
    throw "Target DOCX not found."
}

$stageDir = Join-Path $root ".docx_format_stage_20260414"
$stageZip = Join-Path $root ".docx_format_stage_20260414.zip"
$backupPath = Join-Path $root "backup-before-format-only-20260414.docx"
$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
$AsciiFont = "Times New Roman"
$SongTi = [string]([char]0x5B8B) + [char]0x4F53
$HeiTi = [string]([char]0x9ED1) + [char]0x4F53
$TocTitle = [string]([char]0x76EE) + [char]0x5F55
$RefTitle = [string]([char]0x53C2) + [char]0x8003 + [char]0x6587 + [char]0x732E
$AckTitle = [string]([char]0x81F4) + [char]0x8C22
$CaptionPrefixRegex = '^(' + [char]0x56FE + '|' + [char]0x8868 + ')\d+-\d+'
$HeaderText = "XXX" + [char]0xFF1A + [System.IO.Path]::GetFileNameWithoutExtension($docxPath)

function Get-NsManager {
    param([xml]$Xml)
    $ns = New-Object System.Xml.XmlNamespaceManager($Xml.NameTable)
    $ns.AddNamespace("w", $WordNs)
    return ,$ns
}

function Get-OrCreateChild {
    param(
        [System.Xml.XmlNode]$Parent,
        [string]$Prefix,
        [string]$LocalName,
        [string]$NamespaceUri
    )

    foreach ($child in $Parent.ChildNodes) {
        if ($child.LocalName -eq $LocalName -and $child.NamespaceURI -eq $NamespaceUri) {
            return $child
        }
    }

    $node = $Parent.OwnerDocument.CreateElement($Prefix, $LocalName, $NamespaceUri)
    [void]$Parent.AppendChild($node)
    return $node
}

function Remove-ChildIfExists {
    param(
        [System.Xml.XmlNode]$Parent,
        [string]$LocalName
    )

    $targets = @()
    foreach ($child in $Parent.ChildNodes) {
        if ($child.LocalName -eq $LocalName -and $child.NamespaceURI -eq $WordNs) {
            $targets += $child
        }
    }

    foreach ($target in $targets) {
        [void]$Parent.RemoveChild($target)
    }
}

function Set-WAttr {
    param(
        [System.Xml.XmlElement]$Element,
        [string]$Name,
        [string]$Value
    )

    [void]$Element.SetAttribute($Name, $WordNs, $Value)
}

function Set-RunFormatting {
    param(
        [System.Xml.XmlNode]$Run,
        [string]$EastAsiaFont,
        [string]$AsciiFont,
        [string]$Size,
        [bool]$Bold
    )

    $rPr = Get-OrCreateChild -Parent $Run -Prefix "w" -LocalName "rPr" -NamespaceUri $WordNs
    $rFonts = Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "rFonts" -NamespaceUri $WordNs
    Set-WAttr -Element $rFonts -Name "ascii" -Value $AsciiFont
    Set-WAttr -Element $rFonts -Name "hAnsi" -Value $AsciiFont
    Set-WAttr -Element $rFonts -Name "eastAsia" -Value $EastAsiaFont

    $sz = Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "sz" -NamespaceUri $WordNs
    Set-WAttr -Element $sz -Name "val" -Value $Size

    $szCs = Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "szCs" -NamespaceUri $WordNs
    Set-WAttr -Element $szCs -Name "val" -Value $Size

    Remove-ChildIfExists -Parent $rPr -LocalName "b"
    Remove-ChildIfExists -Parent $rPr -LocalName "bCs"
    if ($Bold) {
        [void](Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "b" -NamespaceUri $WordNs)
        [void](Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "bCs" -NamespaceUri $WordNs)
    }
}

function Update-RunFormatting {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns,
        [string]$EastAsiaFont,
        [string]$AsciiFont,
        [string]$Size,
        [bool]$Bold
    )

    foreach ($run in $Paragraph.SelectNodes(".//w:r", $Ns)) {
        Set-RunFormatting -Run $run -EastAsiaFont $EastAsiaFont -AsciiFont $AsciiFont -Size $Size -Bold $Bold
    }
}

function Set-ParagraphFormatting {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [string]$Before,
        [string]$After,
        [string]$Line,
        [string]$LineRule,
        [string]$Alignment,
        [string]$Left = "",
        [string]$Hanging = "",
        [string]$FirstLineChars = "",
        [bool]$PageBreakBefore = $false
    )

    $pPr = Get-OrCreateChild -Parent $Paragraph -Prefix "w" -LocalName "pPr" -NamespaceUri $WordNs
    $spacing = Get-OrCreateChild -Parent $pPr -Prefix "w" -LocalName "spacing" -NamespaceUri $WordNs
    Set-WAttr -Element $spacing -Name "before" -Value $Before
    Set-WAttr -Element $spacing -Name "after" -Value $After
    Set-WAttr -Element $spacing -Name "line" -Value $Line
    Set-WAttr -Element $spacing -Name "lineRule" -Value $LineRule

    $jc = Get-OrCreateChild -Parent $pPr -Prefix "w" -LocalName "jc" -NamespaceUri $WordNs
    Set-WAttr -Element $jc -Name "val" -Value $Alignment

    if ($Left -ne "" -or $Hanging -ne "" -or $FirstLineChars -ne "") {
        $ind = Get-OrCreateChild -Parent $pPr -Prefix "w" -LocalName "ind" -NamespaceUri $WordNs
        if ($Left -ne "") { Set-WAttr -Element $ind -Name "left" -Value $Left }
        if ($Hanging -ne "") { Set-WAttr -Element $ind -Name "hanging" -Value $Hanging }
        if ($FirstLineChars -ne "") { Set-WAttr -Element $ind -Name "firstLineChars" -Value $FirstLineChars }
    }

    if ($PageBreakBefore) {
        [void](Get-OrCreateChild -Parent $pPr -Prefix "w" -LocalName "pageBreakBefore" -NamespaceUri $WordNs)
    } else {
        Remove-ChildIfExists -Parent $pPr -LocalName "pageBreakBefore"
    }
}

function Get-ParagraphText {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    return ((@($Paragraph.SelectNodes(".//w:t", $Ns) | ForEach-Object { $_.InnerText }) -join "")).Trim()
}

function Update-ChapterParagraph {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns,
        [bool]$PageBreakBefore
    )

    Set-ParagraphFormatting -Paragraph $Paragraph -Before "200" -After "600" -Line "400" -LineRule "exact" -Alignment "center" -PageBreakBefore $PageBreakBefore
    Update-RunFormatting -Paragraph $Paragraph -Ns $Ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "36" -Bold $true
}

function Update-CaptionParagraph {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    Set-ParagraphFormatting -Paragraph $Paragraph -Before "120" -After "60" -Line "240" -LineRule "auto" -Alignment "center"
    Update-RunFormatting -Paragraph $Paragraph -Ns $Ns -EastAsiaFont $HeiTi -AsciiFont $AsciiFont -Size "21" -Bold $true
}

function Update-ReferenceParagraph {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    Set-ParagraphFormatting -Paragraph $Paragraph -Before "0" -After "0" -Line "360" -LineRule "exact" -Alignment "left" -Left "480" -Hanging "480"
    Update-RunFormatting -Paragraph $Paragraph -Ns $Ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "21" -Bold $false
}

function Update-TocParagraph {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns,
        [int]$Level
    )

    switch ($Level) {
        1 {
            Set-ParagraphFormatting -Paragraph $Paragraph -Before "0" -After "0" -Line "240" -LineRule "auto" -Alignment "left" -Left "0"
            Update-RunFormatting -Paragraph $Paragraph -Ns $Ns -EastAsiaFont $HeiTi -AsciiFont $AsciiFont -Size "28" -Bold $true
        }
        2 {
            Set-ParagraphFormatting -Paragraph $Paragraph -Before "0" -After "100" -Line "276" -LineRule "auto" -Alignment "left" -Left "221"
            Update-RunFormatting -Paragraph $Paragraph -Ns $Ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true
        }
        3 {
            Set-ParagraphFormatting -Paragraph $Paragraph -Before "0" -After "100" -Line "276" -LineRule "auto" -Alignment "left" -Left "442"
            Update-RunFormatting -Paragraph $Paragraph -Ns $Ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true
        }
    }
}

function Update-StyleDefinition {
    param(
        [System.Xml.XmlNode]$Style,
        [string]$EastAsiaFont,
        [string]$AsciiFont,
        [string]$Size,
        [bool]$Bold,
        [string]$Before,
        [string]$After,
        [string]$Line,
        [string]$LineRule,
        [string]$Alignment = "",
        [string]$Left = ""
    )

    $rPr = Get-OrCreateChild -Parent $Style -Prefix "w" -LocalName "rPr" -NamespaceUri $WordNs
    $rFonts = Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "rFonts" -NamespaceUri $WordNs
    Set-WAttr -Element $rFonts -Name "ascii" -Value $AsciiFont
    Set-WAttr -Element $rFonts -Name "hAnsi" -Value $AsciiFont
    Set-WAttr -Element $rFonts -Name "eastAsia" -Value $EastAsiaFont

    $sz = Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "sz" -NamespaceUri $WordNs
    Set-WAttr -Element $sz -Name "val" -Value $Size

    $szCs = Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "szCs" -NamespaceUri $WordNs
    Set-WAttr -Element $szCs -Name "val" -Value $Size

    Remove-ChildIfExists -Parent $rPr -LocalName "b"
    Remove-ChildIfExists -Parent $rPr -LocalName "bCs"
    if ($Bold) {
        [void](Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "b" -NamespaceUri $WordNs)
        [void](Get-OrCreateChild -Parent $rPr -Prefix "w" -LocalName "bCs" -NamespaceUri $WordNs)
    }

    $pPr = Get-OrCreateChild -Parent $Style -Prefix "w" -LocalName "pPr" -NamespaceUri $WordNs
    $spacing = Get-OrCreateChild -Parent $pPr -Prefix "w" -LocalName "spacing" -NamespaceUri $WordNs
    Set-WAttr -Element $spacing -Name "before" -Value $Before
    Set-WAttr -Element $spacing -Name "after" -Value $After
    Set-WAttr -Element $spacing -Name "line" -Value $Line
    Set-WAttr -Element $spacing -Name "lineRule" -Value $LineRule

    if ($Alignment -ne "") {
        $jc = Get-OrCreateChild -Parent $pPr -Prefix "w" -LocalName "jc" -NamespaceUri $WordNs
        Set-WAttr -Element $jc -Name "val" -Value $Alignment
    }

    if ($Left -ne "") {
        $ind = Get-OrCreateChild -Parent $pPr -Prefix "w" -LocalName "ind" -NamespaceUri $WordNs
        Set-WAttr -Element $ind -Name "left" -Value $Left
    }
}

Copy-Item -LiteralPath $docxPath -Destination $backupPath -Force

if (Test-Path $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
}

if (Test-Path $stageZip) {
    Remove-Item -LiteralPath $stageZip -Force
}

Copy-Item -LiteralPath $docxPath -Destination $stageZip -Force
Expand-Archive -LiteralPath $stageZip -DestinationPath $stageDir -Force

$documentPath = Join-Path $stageDir "word\document.xml"
$stylesPath = Join-Path $stageDir "word\styles.xml"
$headerPath = Join-Path $stageDir "word\header1.xml"
$footerPath = Join-Path $stageDir "word\footer1.xml"

[xml]$document = Get-Content -LiteralPath $documentPath -Raw -Encoding UTF8
$ns = Get-NsManager -Xml $document

foreach ($para in $document.SelectNodes("//w:body/w:p", $ns)) {
    $text = Get-ParagraphText -Paragraph $para -Ns $ns
    if (-not $text) { continue }

    $styleId = ""
    $styleNode = $para.SelectSingleNode("./w:pPr/w:pStyle", $ns)
    if ($styleNode) {
        $styleId = $styleNode.GetAttribute("val", $WordNs)
    }

    if ($styleId -eq "3") {
        Update-ChapterParagraph -Paragraph $para -Ns $ns -PageBreakBefore $true
        continue
    }

    if ($styleId -eq "4") {
        Set-ParagraphFormatting -Paragraph $para -Before "200" -After "200" -Line "400" -LineRule "exact" -Alignment "left"
        Update-RunFormatting -Paragraph $para -Ns $ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true
        continue
    }

    if ($styleId -eq "5") {
        Set-ParagraphFormatting -Paragraph $para -Before "200" -After "200" -Line "400" -LineRule "exact" -Alignment "left"
        Update-RunFormatting -Paragraph $para -Ns $ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true
        continue
    }

    if ($text -match $CaptionPrefixRegex) {
        Update-CaptionParagraph -Paragraph $para -Ns $ns
        continue
    }

    if ($text -in @($RefTitle, $AckTitle)) {
        Update-ChapterParagraph -Paragraph $para -Ns $ns -PageBreakBefore $true
    }
}

$inReferences = $false
foreach ($para in $document.SelectNodes("//w:body/w:p", $ns)) {
    $text = Get-ParagraphText -Paragraph $para -Ns $ns
    if ($text -eq $RefTitle) {
        $inReferences = $true
        continue
    }

    if ($text -eq $AckTitle) {
        $inReferences = $false
        continue
    }

    if ($inReferences -and $text) {
        Update-ReferenceParagraph -Paragraph $para -Ns $ns
    }
}

foreach ($table in $document.SelectNodes("//w:body/w:tbl", $ns)) {
    $rowIndex = 0
    foreach ($row in $table.SelectNodes("./w:tr", $ns)) {
        foreach ($cellParagraph in $row.SelectNodes(".//w:tc//w:p", $ns)) {
            Set-ParagraphFormatting -Paragraph $cellParagraph -Before "0" -After "0" -Line "240" -LineRule "auto" -Alignment "center" -Left "0"
            Update-RunFormatting -Paragraph $cellParagraph -Ns $ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "18" -Bold ($rowIndex -eq 0)
        }
        $rowIndex++
    }
}

$tocContent = $document.SelectSingleNode("//w:sdt/w:sdtContent", $ns)
if ($tocContent) {
    foreach ($para in $tocContent.SelectNodes("./w:p", $ns)) {
        $text = Get-ParagraphText -Paragraph $para -Ns $ns
        if (-not $text) { continue }

        $styleId = ""
        $styleNode = $para.SelectSingleNode("./w:pPr/w:pStyle", $ns)
        if ($styleNode) {
            $styleId = $styleNode.GetAttribute("val", $WordNs)
        }

        switch ($styleId) {
            "27" { Update-TocParagraph -Paragraph $para -Ns $ns -Level 1; continue }
            "30" { Update-TocParagraph -Paragraph $para -Ns $ns -Level 2; continue }
            "24" { Update-TocParagraph -Paragraph $para -Ns $ns -Level 3; continue }
            default {
                if ($text -eq $TocTitle) {
                    Set-ParagraphFormatting -Paragraph $para -Before "0" -After "600" -Line "400" -LineRule "exact" -Alignment "center"
                    Update-RunFormatting -Paragraph $para -Ns $ns -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "36" -Bold $true
                }
            }
        }
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($documentPath, $document.OuterXml, $utf8NoBom)

[xml]$styles = Get-Content -LiteralPath $stylesPath -Raw -Encoding UTF8
$stylesNs = Get-NsManager -Xml $styles

$style3 = $styles.SelectSingleNode("//w:style[@w:styleId='3']", $stylesNs)
if ($style3) {
    Update-StyleDefinition -Style $style3 -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "36" -Bold $true -Before "200" -After "600" -Line "400" -LineRule "exact" -Alignment "center"
}

$style4 = $styles.SelectSingleNode("//w:style[@w:styleId='4']", $stylesNs)
if ($style4) {
    Update-StyleDefinition -Style $style4 -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true -Before "200" -After "200" -Line "400" -LineRule "exact"
}

$style5 = $styles.SelectSingleNode("//w:style[@w:styleId='5']", $stylesNs)
if ($style5) {
    Update-StyleDefinition -Style $style5 -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true -Before "200" -After "200" -Line "400" -LineRule "exact"
}

$toc1 = $styles.SelectSingleNode("//w:style[@w:styleId='27']", $stylesNs)
if ($toc1) {
    Update-StyleDefinition -Style $toc1 -EastAsiaFont $HeiTi -AsciiFont $AsciiFont -Size "28" -Bold $true -Before "0" -After "0" -Line "240" -LineRule "auto"
}

$toc2 = $styles.SelectSingleNode("//w:style[@w:styleId='30']", $stylesNs)
if ($toc2) {
    Update-StyleDefinition -Style $toc2 -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true -Before "0" -After "100" -Line "276" -LineRule "auto" -Left "221"
}

$toc3 = $styles.SelectSingleNode("//w:style[@w:styleId='24']", $stylesNs)
if ($toc3) {
    Update-StyleDefinition -Style $toc3 -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "24" -Bold $true -Before "0" -After "100" -Line "276" -LineRule "auto" -Left "442"
}

[System.IO.File]::WriteAllText($stylesPath, $styles.OuterXml, $utf8NoBom)

if (Test-Path $headerPath) {
    [xml]$header = Get-Content -LiteralPath $headerPath -Raw -Encoding UTF8
    $headerNs = Get-NsManager -Xml $header
    $paragraph = $header.SelectSingleNode("//w:p", $headerNs)
    if ($paragraph) {
        foreach ($run in @($paragraph.SelectNodes("./w:r", $headerNs))) {
            [void]$paragraph.RemoveChild($run)
        }

        $run = $header.CreateElement("w", "r", $WordNs)
        $rPr = $header.CreateElement("w", "rPr", $WordNs)
        $rFonts = $header.CreateElement("w", "rFonts", $WordNs)
        Set-WAttr -Element $rFonts -Name "ascii" -Value $AsciiFont
        Set-WAttr -Element $rFonts -Name "hAnsi" -Value $AsciiFont
        Set-WAttr -Element $rFonts -Name "eastAsia" -Value $SongTi
        [void]$rPr.AppendChild($rFonts)

        $sz = $header.CreateElement("w", "sz", $WordNs)
        Set-WAttr -Element $sz -Name "val" -Value "18"
        [void]$rPr.AppendChild($sz)

        $szCs = $header.CreateElement("w", "szCs", $WordNs)
        Set-WAttr -Element $szCs -Name "val" -Value "18"
        [void]$rPr.AppendChild($szCs)

        [void]$run.AppendChild($rPr)
        $t = $header.CreateElement("w", "t", $WordNs)
        $t.InnerText = $HeaderText
        [void]$run.AppendChild($t)
        [void]$paragraph.AppendChild($run)
    }
    [System.IO.File]::WriteAllText($headerPath, $header.OuterXml, $utf8NoBom)
}

if (Test-Path $footerPath) {
    [xml]$footer = Get-Content -LiteralPath $footerPath -Raw -Encoding UTF8
    $footerNs = Get-NsManager -Xml $footer
    foreach ($run in $footer.SelectNodes("//w:p/w:r", $footerNs)) {
        Set-RunFormatting -Run $run -EastAsiaFont $SongTi -AsciiFont $AsciiFont -Size "21" -Bold $false
    }
    [System.IO.File]::WriteAllText($footerPath, $footer.OuterXml, $utf8NoBom)
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $stageZip) {
    Remove-Item -LiteralPath $stageZip -Force
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $stageZip)
Copy-Item -LiteralPath $stageZip -Destination $docxPath -Force
Remove-Item -LiteralPath $stageDir -Recurse -Force
Remove-Item -LiteralPath $stageZip -Force

Write-Output "FORMAT_UPDATED"
