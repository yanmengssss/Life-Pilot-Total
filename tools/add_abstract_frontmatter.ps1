$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = "F:\Graduation Project"
$docxPath = (
    Get-ChildItem -LiteralPath $root -Filter "*.docx" |
    Where-Object { $_.Name -like "*Next.js*" -and $_.Name -notlike "*copy*" -and $_.Name -notlike "*.repaired*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
).FullName
$backupPath = Join-Path $root "backup-before-abstract-insert-20260414.docx"
$stageDir = Join-Path $root ".docx_abstract_stage_20260414"
$stageZip = Join-Path $root ".docx_abstract_stage_20260414.zip"
$WordNs = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

if (-not $docxPath) {
    throw "Target DOCX not found."
}

function Decode-Utf8Base64 {
    param([string]$Value)
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function Escape-XmlText {
    param([string]$Text)
    return [System.Security.SecurityElement]::Escape($Text)
}

function New-TempFragmentRoot {
    return "<root xmlns:w='$WordNs'>__CONTENT__</root>"
}

function Import-FragmentChildren {
    param(
        [xml]$Document,
        [string]$InnerXml
    )

    $temp = New-Object System.Xml.XmlDocument
    $temp.LoadXml((New-TempFragmentRoot).Replace("__CONTENT__", $InnerXml))
    $result = @()
    foreach ($child in $temp.DocumentElement.ChildNodes) {
        $result += $Document.ImportNode($child, $true)
    }
    return ,$result
}

function Insert-FragmentBeforeNode {
    param(
        [xml]$Document,
        [System.Xml.XmlNode]$Parent,
        [System.Xml.XmlNode]$BeforeNode,
        [string]$InnerXml
    )

    foreach ($node in (Import-FragmentChildren -Document $Document -InnerXml $InnerXml)) {
        [void]$Parent.InsertBefore($node, $BeforeNode)
    }
}

function Get-NodeText {
    param(
        [System.Xml.XmlNode]$Node,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    if ($Node.LocalName -eq "p" -or $Node.LocalName -eq "sdt") {
        return ((@($Node.SelectNodes(".//w:t", $Ns) | ForEach-Object { $_.InnerText }) -join "")).Trim()
    }
    return ""
}

function New-RunXml {
    param(
        [string]$Text,
        [string]$Size = "24",
        [bool]$Bold = $false,
        [string]$AsciiFont = "Times New Roman",
        [string]$EastAsiaFont = "SimSun"
    )

    $rPr = "<w:rPr><w:rFonts w:ascii=""$AsciiFont"" w:hAnsi=""$AsciiFont"" w:eastAsia=""$EastAsiaFont""/><w:sz w:val=""$Size""/><w:szCs w:val=""$Size""/>"
    if ($Bold) {
        $rPr += "<w:b/><w:bCs/>"
    }
    $rPr += "</w:rPr>"
    return "<w:r>$rPr<w:t xml:space=""preserve"">$(Escape-XmlText $Text)</w:t></w:r>"
}

function New-ParagraphXml {
    param(
        [string[]]$Runs,
        [string]$Line = "480",
        [string]$LineRule = "exact",
        [string]$Before = "0",
        [string]$After = "0",
        [string]$Alignment = "left",
        [string]$FirstLineChars = "",
        [bool]$PageBreakBefore = $false
    )

    $pPr = "<w:pPr>"
    if ($PageBreakBefore) {
        $pPr += "<w:pageBreakBefore/>"
    }
    $pPr += "<w:spacing w:before=""$Before"" w:after=""$After"" w:line=""$Line"" w:lineRule=""$LineRule""/>"
    if ($FirstLineChars -ne "") {
        $pPr += "<w:ind w:firstLineChars=""$FirstLineChars""/>"
    }
    $pPr += "<w:jc w:val=""$Alignment""/></w:pPr>"
    return "<w:p>$pPr$($Runs -join '')</w:p>"
}

function New-PageBreakParagraphXml {
    return "<w:p><w:r><w:br w:type=""page""/></w:r></w:p>"
}

$zhTitle = Decode-Utf8Base64 "5pGYICDopoE="
$zhAbstract = Decode-Utf8Base64 "6Z2i5ZCR5Liq5Lq65LqL5Yqh566h55CG44CB6LWE5paZ5qOA57Si5ZKM5aSa5qih5oCB5Lqk5LqS5bm25a2Y55qE5L2/55So5Zy65pmv77yM5pys5paH6K6+6K6h5bm25a6e546w5LqG5Z+65LqOIE5leHQuanMg55qE5pm66IO955Sf5rS7566h5a6257O757ufIExpZmVQaWxvdOOAgumSiOWvueS8oOe7n+W+heWKnuW3peWFt+mavuS7peWkhOeQhuiHqueEtuivreiogOi+k+WFpeOAgei3qOi1hOaWmeiBlOWKqOiDveWKm+S4jei2s++8jOS7peWPiuWkp+ivreiogOaooeWei+ebtOaOpei/m+WFpeS4muWKoemTvui3r+WQjuWuueaYk+W4puadpee7k+aenOS4jeeos+WSjOiuv+mXrui+ueeVjOS4jea4heeahOmXrumimO+8jOezu+e7n+mHh+eUqOWJjeWQjuerr+WIhuemu+S4juWkmuacjeWKoeWNj+S9nOaetuaehO+8jOWcqOWJjeerr+aehOW7uuS7u+WKoeeuoeeQhuOAgeWvueivneS6pOS6kuOAgeefpeivhuW6k+WSjOiusOW9leafpeeci+etieWKn+iDve+8jOWcqOWQjuerr+W8leWFpSBMYW5nR3JhcGgg5bel5L2c5rWB44CBTUNQIOW3peWFt+iwg+eUqOS4juajgOe0ouWinuW8uueUn+aIkOacuuWItu+8jOWwhuiHqueEtuivreiogOeQhuino+OAgeS4muWKoeehruiupOOAgeefpeivhuajgOe0ouWSjOaPkOmGkuiwg+W6puaUtui/m+WQjOS4gOadoeWPl+aOp+mTvui3r+OAgua1i+ivlee7k+aenOihqOaYju+8jOezu+e7n+W3suiDveWkn+eos+WumuWujOaIkOS7u+WKoeWIm+W7uuOAgeefpeivhumXruetlOOAgeaPkOmGkuinpuWPkeWSjOWkmuerr+iuv+mXruetieS4u+imgea1geeoi++8m+WcqOefpeivhuW6k+a1i+ivleS4re+8jDYwIOasoeS4iuS8oOOAgTYwIOasoeafpeivouS4jiA2MCDmrKHlj6zlm57pqozor4HlnYfmiJDlip/lrozmiJDvvIzlubPlnYflk43lupTml7bpl7TkuLogMjg1IG1z77yM5pW05L2T5YeG56Gu5bqm5Li6IDg3LjIl77yM5p+l5YWo546H5ZKM5p+l5YeG546H5YiG5Yir5Li6IDkyLjUlIOS4jiA5MS43JeOAguivpeezu+e7n+ivtOaYjuKAnOWkp+ivreiogOaooeWeiyArIOW3peS9nOa1gee8luaOkiArIOWPl+aOp+W3peWFt+iuv+mXruKAneiDveWkn+iQveWIsOS4quS6uuaZuuiDveWKqeeQhueahOWunumZheWcuuaZr+S4re+8jOS5n+S4uuWQjue7reWujOWWhOS4quaAp+WMluW7uuaooeOAgeWkjeadguaWh+aho+WkhOeQhuWSjOaJp+ihjOaOp+WItuaPkOS+m+S6huWPr+e7p+e7reaOqOi/m+eahOWfuuehgOOAgg=="
$zhKeywords = Decode-Utf8Base64 "5YWz6ZSu6K+N77yaTmV4dC5qc+OAgeS7u+WKoeeuoeeQhuOAgeajgOe0ouWinuW8uueUn+aIkOOAgeWkmuaooeaAgeS6pOS6kuOAgeaZuuiDveWKqeeQhg=="
$enTitle = Decode-Utf8Base64 "QWJzdHJhY3Q="
$enAbstract = Decode-Utf8Base64 "VGhpcyB0aGVzaXMgZGVzaWducyBhbmQgaW1wbGVtZW50cyBMaWZlUGlsb3QsIGFuIGludGVsbGlnZW50IGRhaWx5IGFzc2lzdGFudCBidWlsdCB3aXRoIE5leHQuanMgZm9yIHBlcnNvbmFsIHRhc2sgbWFuYWdlbWVudCwga25vd2xlZGdlIHJldHJpZXZhbCwgYW5kIG11bHRpbW9kYWwgaW50ZXJhY3Rpb24uIFRoZSB3b3JrIHN0YXJ0cyBmcm9tIHR3byBwcmFjdGljYWwgbGltaXRhdGlvbnM6IGNvbnZlbnRpb25hbCB0by1kbyBhcHBsaWNhdGlvbnMgaGFuZGxlIG5hdHVyYWwtbGFuZ3VhZ2UgaW5wdXQgcG9vcmx5LCBhbmQgbGFyZ2UgbGFuZ3VhZ2UgbW9kZWxzLCB3aGVuIGNvbm5lY3RlZCBkaXJlY3RseSB0byBidXNpbmVzcyBvcGVyYXRpb25zLCBtYXkgaW50cm9kdWNlIHVuc3RhYmxlIG91dHB1dHMgYW5kIHVuY2xlYXIgYWNjZXNzIGJvdW5kYXJpZXMuIFRvIGFkZHJlc3MgdGhlc2UgaXNzdWVzLCB0aGUgc3lzdGVtIGFkb3B0cyBhIGZyb250LWVuZC9iYWNrLWVuZCBzZXBhcmF0ZWQgYW5kIG11bHRpLXNlcnZpY2UgYXJjaGl0ZWN0dXJlLiBUaGUgZnJvbnQgZW5kIHByb3ZpZGVzIHRhc2sgbWFuYWdlbWVudCwgY29udmVyc2F0aW9uYWwgaW50ZXJhY3Rpb24sIGtub3dsZWRnZS1iYXNlIGFjY2VzcywgYW5kIHBlcnNvbmFsIHJlY29yZCBicm93c2luZywgd2hpbGUgdGhlIGJhY2sgZW5kIGludGVncmF0ZXMgYSBMYW5nR3JhcGggd29ya2Zsb3csIE1DUC1iYXNlZCB0b29sIGludm9jYXRpb24sIGFuZCByZXRyaWV2YWwtYXVnbWVudGVkIGdlbmVyYXRpb24uIEluIHRoaXMgd2F5LCBuYXR1cmFsLWxhbmd1YWdlIHVuZGVyc3RhbmRpbmcsIHVzZXIgY29uZmlybWF0aW9uLCBrbm93bGVkZ2UgcmV0cmlldmFsLCBhbmQgcmVtaW5kZXIgc2NoZWR1bGluZyBhcmUgb3JnYW5pemVkIGludG8gYSBjb250cm9sbGVkIGV4ZWN1dGlvbiBjaGFpbi4gVGVzdCByZXN1bHRzIHNob3cgdGhhdCB0aGUgc3lzdGVtIGNhbiBzdGFibHkgY29tcGxldGUgdGFzayBjcmVhdGlvbiwga25vd2xlZGdlIHF1ZXN0aW9uIGFuc3dlcmluZywgcmVtaW5kZXIgdHJpZ2dlcmluZywgYW5kIG11bHRpLWRldmljZSBhY2Nlc3MuIEluIHRoZSBrbm93bGVkZ2UtYmFzZSBldmFsdWF0aW9uLCBhbGwgNjAgdXBsb2FkcywgNjAgcXVlcmllcywgYW5kIDYwIHJldHJpZXZhbCB2ZXJpZmljYXRpb25zIHdlcmUgY29tcGxldGVkIHN1Y2Nlc3NmdWxseS4gVGhlIGF2ZXJhZ2UgcmVzcG9uc2UgdGltZSB3YXMgMjg1IG1zLCB0aGUgb3ZlcmFsbCBhY2N1cmFjeSByZWFjaGVkIDg3LjIlLCBhbmQgcmVjYWxsIGFuZCBwcmVjaXNpb24gd2VyZSA5Mi41JSBhbmQgOTEuNyUsIHJlc3BlY3RpdmVseS4gVGhlIGltcGxlbWVudGF0aW9uIGluZGljYXRlcyB0aGF0IHRoZSBjb21iaW5hdGlvbiBvZiBsYXJnZSBsYW5ndWFnZSBtb2RlbHMsIHdvcmtmbG93IG9yY2hlc3RyYXRpb24sIGFuZCBjb250cm9sbGVkIHRvb2wgYWNjZXNzIGNhbiBiZSBhcHBsaWVkIHRvIGEgcGVyc29uYWwgYXNzaXN0YW50IHNjZW5hcmlvIGluIGEgcHJhY3RpY2FsIHdheSwgd2hpbGUgc3RpbGwgbGVhdmluZyByb29tIGZvciBmdXR1cmUgd29yayBvbiBwZXJzb25hbGl6ZWQgbW9kZWxpbmcsIGNvbXBsZXggZG9jdW1lbnQgcHJvY2Vzc2luZywgYW5kIGV4ZWN1dGlvbiBjb250cm9sLg=="
$enKeywords = Decode-Utf8Base64 "S2V5IHdvcmRzOiBOZXh0LmpzLCB0YXNrIG1hbmFnZW1lbnQsIHJldHJpZXZhbC1hdWdtZW50ZWQgZ2VuZXJhdGlvbiwgbXVsdGltb2RhbCBpbnRlcmFjdGlvbiwgaW50ZWxsaWdlbnQgYXNzaXN0YW50"

$fragment = @(
    (New-ParagraphXml -Runs @((New-RunXml -Text $zhTitle -Size "36" -Bold $true)) -Line "400" -Before "0" -After "360" -Alignment "center"),
    (New-ParagraphXml -Runs @((New-RunXml -Text $zhAbstract -Size "24")) -Line "480" -Before "0" -After "0" -Alignment "left" -FirstLineChars "200"),
    (New-ParagraphXml -Runs @((New-RunXml -Text $zhKeywords -Size "24")) -Line "480" -Before "0" -After "0" -Alignment "left"),
    (New-PageBreakParagraphXml),
    (New-ParagraphXml -Runs @((New-RunXml -Text $enTitle -Size "36" -Bold $true)) -Line "400" -Before "0" -After "360" -Alignment "center"),
    (New-ParagraphXml -Runs @((New-RunXml -Text $enAbstract -Size "24")) -Line "480" -Before "0" -After "0" -Alignment "left"),
    (New-ParagraphXml -Runs @((New-RunXml -Text $enKeywords -Size "24")) -Line "480" -Before "0" -After "0" -Alignment "left"),
    (New-PageBreakParagraphXml)
) -join ""

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
[xml]$document = Get-Content -LiteralPath $documentPath -Raw -Encoding UTF8
$ns = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
$ns.AddNamespace("w", $WordNs)

$body = $document.SelectSingleNode("//w:body", $ns)
$coverMarker = Decode-Utf8Base64 "5LicIOiOkueQhuW3peWtpumZog=="
$current = $body.FirstChild
while ($null -ne $current) {
    $next = $current.NextSibling
    $text = Get-NodeText -Node $current -Ns $ns
    if ($text -eq $coverMarker -or $current.LocalName -eq "sdt") {
        break
    }
    [void]$body.RemoveChild($current)
    $current = $next
}

$tocNode = $body.SelectSingleNode("./w:sdt[1]", $ns)
if ($null -eq $tocNode) {
    throw "TOC node not found."
}
Insert-FragmentBeforeNode -Document $document -Parent $body -BeforeNode $tocNode -InnerXml $fragment

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($documentPath, $document.OuterXml, $utf8NoBom)

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $stageZip) {
    Remove-Item -LiteralPath $stageZip -Force
}
[System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $stageZip)
Copy-Item -LiteralPath $stageZip -Destination $docxPath -Force
Remove-Item -LiteralPath $stageDir -Recurse -Force
Remove-Item -LiteralPath $stageZip -Force

Write-Output "ABSTRACT_INSERTED"
