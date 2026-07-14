$ErrorActionPreference = "Stop"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$cp1252 = [System.Text.Encoding]::GetEncoding(1252)
$utf8 = [System.Text.Encoding]::UTF8

function Fix-MojibakeText([string]$text) {
  # Ripara anche eventuali sequenze letterali create prima
  $text = $text.Replace(([string][char]0x00E2 + '\u20AC¢'), [string][char]0x2022)
  $text = $text.Replace(([string][char]0x00E2 + '\u20AC”'), '-')
  $text = $text.Replace(([string][char]0x00E2 + '\u20AC'), '-')

  # Ripara sequenze tipo Ã¨, Ã , âœ…, â†’, ðŸ“±
  $pattern = '([\u00C2\u00C3\u00C5\u00E2\u00F0][\u0080-\uFFFF]{0,8})'

  return [regex]::Replace($text, $pattern, {
    param($m)

    try {
      $bytes = $cp1252.GetBytes($m.Value)
      $fixed = $utf8.GetString($bytes)

      if ($fixed.Contains([char]0xFFFD)) {
        return $m.Value
      }

      return $fixed
    } catch {
      return $m.Value
    }
  })
}

Get-ChildItem lib -Recurse -Filter *.dart | ForEach-Object {
  $path = $_.FullName
  $oldText = [System.IO.File]::ReadAllText($path)
  $newText = Fix-MojibakeText $oldText

  if ($newText -ne $oldText) {
    [System.IO.File]::WriteAllText($path, $newText, $utf8NoBom)
    Write-Host "Corretto: $path"
  }
}
