param(
    [string]$Markdown = "charts.md",
    [string]$OutputDir = "exported_png",
    [int]$Width = 800,
    [string]$Mmdc = "mmdc",
    [switch]$KeepMmd
)

$ErrorActionPreference = "Stop"

if ($Width -le 0) {
    throw "Width must be greater than 0."
}

if (-not (Test-Path -LiteralPath $Markdown)) {
    throw "Markdown file not found: $Markdown"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$tempDir = Join-Path $OutputDir ".mmd_tmp"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$content = Get-Content -LiteralPath $Markdown -Raw -Encoding UTF8
$pattern = '```mermaid\s*\r?\n(.*?)\r?\n```'
$regex = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
$matches = $regex.Matches($content)

if ($matches.Count -eq 0) {
    Write-Host "No mermaid blocks found in $Markdown"
    exit 1
}

function Get-SafeName([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "chart" }
    $name = $s.Trim()
    $name = $name -replace "[\r\n\t]", " "
    $name = $name -replace "[\x00-\x1F\x7F]", ""
    $name = $name -replace "\s+", "_"
    $name = $name -replace '[\\/:*?""<>|]', '_'
    $name = $name -replace "_+", "_"
    $name = $name.Trim("_")
    if ($name.Length -gt 80) { $name = $name.Substring(0, 80).Trim("_") }
    if ([string]::IsNullOrWhiteSpace($name)) { return "chart" }
    return $name
}

function Get-HeadingBeforeOffset([string]$text, [int]$offset) {
    $prefix = $text.Substring(0, [Math]::Max(0, $offset))
    $lines = $prefix -split "`r?`n"
    for ($i = $lines.Length - 1; $i -ge 0; $i--) {
        $line = $lines[$i].Trim()
        if ($line.StartsWith("### ")) { return $line.Substring(4).Trim() }
        if ($line.StartsWith("## ")) { return $line.Substring(3).Trim() }
    }
    return ""
}

function Ensure-ExactWidth([string]$pngPath, [int]$targetWidth) {
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($pngPath)
    $tempPng = "$pngPath.tmp.png"
    try {
        if ($img.Width -eq $targetWidth) { return }
        if ($img.Width -gt $targetWidth) {
            throw ("Image width {0} exceeds target width {1}: {2}" -f $img.Width, $targetWidth, $pngPath)
        }

        $bmp = New-Object System.Drawing.Bitmap($targetWidth, $img.Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.Clear([System.Drawing.Color]::White)
            $x = [int](($targetWidth - $img.Width) / 2)
            $g.DrawImage($img, $x, 0, $img.Width, $img.Height)
            $bmp.Save($tempPng, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $g.Dispose()
            $bmp.Dispose()
        }
    } finally {
        $img.Dispose()
    }
    Move-Item -LiteralPath $tempPng -Destination $pngPath -Force
}

$exported = 0

for ($i = 0; $i -lt $matches.Count; $i++) {
    $idx = $i + 1
    $block = $matches[$i]
    $title = Get-HeadingBeforeOffset -text $content -offset $block.Index
    $safeTitle = Get-SafeName $title
    $code = $block.Groups[1].Value.Trim() + "`n"

    $mmdPath = Join-Path $tempDir ("{0:D2}_{1}.mmd" -f $idx, $safeTitle)
    $pngPath = Join-Path $OutputDir ("{0:D2}_{1}.png" -f $idx, $safeTitle)
    Set-Content -LiteralPath $mmdPath -Value $code -Encoding UTF8

    try {
        & $Mmdc -i $mmdPath -o $pngPath -w $Width
        if ($LASTEXITCODE -eq 0) {
            Ensure-ExactWidth -pngPath $pngPath -targetWidth $Width
            $exported++
            Write-Host ("[ok] " + [IO.Path]::GetFileName($pngPath))
        } else {
            Write-Warning ("[fail] " + [IO.Path]::GetFileName($pngPath))
        }
    } catch {
        Write-Warning ("[fail] " + [IO.Path]::GetFileName($pngPath) + " : " + $_.Exception.Message)
    }
}

if (-not $KeepMmd) {
    Get-ChildItem -LiteralPath $tempDir -Filter *.mmd -File | Remove-Item -Force
    if (-not (Get-ChildItem -LiteralPath $tempDir -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $tempDir -Force
    }
}

Write-Host "done: $exported/$($matches.Count) exported to $OutputDir"

if ($exported -eq $matches.Count) {
    exit 0
}
exit 1
