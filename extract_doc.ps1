param(
    [string]$DocPath,
    [string]$Pattern = ".*"
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $DocPath)) {
    Write-Error "File not found: $DocPath"
    exit 1
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($DocPath)
$entry = $zip.GetEntry("word/document.xml")
$stream = $entry.Open()
$reader = New-Object System.IO.StreamReader($stream)
$xmlContent = $reader.ReadToEnd()
$reader.Close()
$stream.Close()
$zip.Dispose()

$pMatches = [System.Text.RegularExpressions.Regex]::Matches($xmlContent, "<w:p[ >].*?</w:p>")
$results = @()
foreach ($m in $pMatches) {
    $txt = [System.Text.RegularExpressions.Regex]::Replace($m.Value, "<[^>]+>", " ")
    $txt = [System.Text.RegularExpressions.Regex]::Replace($txt, "\s+", " ").Trim()
    if ($txt -match $Pattern) {
        $results += $txt
    }
}

$results
