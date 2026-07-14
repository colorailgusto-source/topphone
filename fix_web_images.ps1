$files = Get-ChildItem lib -Recurse -Filter *.dart

foreach ($file in $files) {
  $text = Get-Content $file.FullName -Raw
  $original = $text
  $needle = "Image.network("
  $pos = 0
  $out = New-Object System.Text.StringBuilder

  while ($true) {
    $idx = $text.IndexOf($needle, $pos)
    if ($idx -lt 0) {
      [void]$out.Append($text.Substring($pos))
      break
    }

    [void]$out.Append($text.Substring($pos, $idx - $pos))

    $start = $idx + $needle.Length
    $i = $start
    $depth = 1
    $inSingle = $false
    $inDouble = $false
    $escape = $false

    while ($i -lt $text.Length -and $depth -gt 0) {
      $ch = $text[$i]

      if ($escape) {
        $escape = $false
      } elseif ($ch -eq '\') {
        $escape = $true
      } elseif ($inSingle) {
        if ($ch -eq "'") { $inSingle = $false }
      } elseif ($inDouble) {
        if ($ch -eq '"') { $inDouble = $false }
      } else {
        if ($ch -eq "'") {
          $inSingle = $true
        } elseif ($ch -eq '"') {
          $inDouble = $true
        } elseif ($ch -eq '(') {
          $depth++
        } elseif ($ch -eq ')') {
          $depth--
        }
      }

      $i++
    }

    if ($depth -ne 0) {
      [void]$out.Append($text.Substring($idx))
      break
    }

    $call = $text.Substring($idx, $i - $idx)

    if ($call.Contains("webHtmlElementStrategy:")) {
      [void]$out.Append($call)
    } else {
      $inside = $call.Substring($needle.Length, $call.Length - $needle.Length - 1)
      $trimmed = $inside.TrimEnd()

      if ($trimmed.EndsWith(",")) {
        $newCall = $needle + $trimmed + " webHtmlElementStrategy: WebHtmlElementStrategy.prefer," + ")"
      } else {
        $newCall = $needle + $trimmed + ", webHtmlElementStrategy: WebHtmlElementStrategy.prefer" + ")"
      }

      [void]$out.Append($newCall)
    }

    $pos = $i
  }

  $newText = $out.ToString()

  if ($newText -ne $original) {
    Copy-Item $file.FullName "$($file.FullName).bak" -Force
    Set-Content $file.FullName $newText
    Write-Host "Aggiornato: $($file.FullName)"
  }
}
