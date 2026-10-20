param(
    [string]$DocPath,
    [string]$SearchText
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($DocPath)
$docXml = (New-Object System.IO.StreamReader($zip.GetEntry('word/document.xml').Open())).ReadToEnd()
$relsXml = (New-Object System.IO.StreamReader($zip.GetEntry('word/_rels/document.xml.rels').Open())).ReadToEnd()
$zip.Dispose()

$pos = $docXml.IndexOf($SearchText)
if ($pos -ge 0) {
    $start = [Math]::Max(0, $pos - 2000)
    $len = [Math]::Min($docXml.Length - $start, 4000)
    $sub = $docXml.Substring($start, $len)
    $matches = [System.Text.RegularExpressions.Regex]::Matches($sub, 'r:embed="(rId\d+)"')
    foreach ($m in $matches) {
        $rid = $m.Groups[1].Value
        $pattern = "Id=`"$rid`"[^>]*Target=`"([^`"]+)`""
        $relM = [System.Text.RegularExpressions.Regex]::Match($relsXml, $pattern)
        if ($relM.Success) {
            Write-Output "$SearchText : $rid -> $($relM.Groups[1].Value)"
        }
    }
} else {
    Write-Output "SearchText '$SearchText' not found in document.xml"
}
