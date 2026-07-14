$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Save-Utf8NoBom($path, $text) {
  [System.IO.File]::WriteAllText((Resolve-Path $path), $text, $utf8NoBom)
}

# -------------------------
# admin_orders_screen.dart
# -------------------------
$path = "lib\screens\admin\admin_orders_screen.dart"
$text = Get-Content $path -Raw

# Pulisce separatori strani prima del prezzo
$text = [regex]::Replace($text, "\s+[\u00C2-\u00F4][^\\']{0,40}\\u20AC", " - \u20AC")

# Pulisce emoji/testi notifiche admin
$text = [regex]::Replace($text, "const Text\('[^']*Foto Garanzia/Scontrino \(opzionale\)'", "const Text('Foto Garanzia/Scontrino (opzionale)'")
$text = [regex]::Replace($text, "titolo = ""[^""]*Ordine spedito"";", "titolo = ""Ordine spedito"";")
$text = [regex]::Replace($text, "titolo = ""[^""]*Pronto per il ritiro"";", "titolo = ""Pronto per il ritiro"";")
$text = [regex]::Replace($text, "titolo = ""[^""]*Ordine consegnato"";", "titolo = ""Ordine consegnato"";")
$text = $text.Replace("Ã¨", "e")
$text = $text.Replace("Ã ", "a")
$text = $text.Replace("Ã", "a")

Save-Utf8NoBom $path $text

# -------------------------
# welcome_screen.dart
# -------------------------
$path = "lib\screens\auth\welcome_screen.dart"
$text = Get-Content $path -Raw

$text = [regex]::Replace($text, "Text\('Registrati - [^']* gratis!'\)", "Text('Registrati - e gratis!')")
$text = [regex]::Replace($text, "Text\('Continua come ospite [^']*'\)", "Text('Continua come ospite ->')")
$text = $text.Replace("Ã¨", "e")
$text = $text.Replace("Ã ", "a")
$text = $text.Replace("Ã¢â€ â€™", "->")
$text = $text.Replace("Ã¢â‚¬Â¢", "-")

Save-Utf8NoBom $path $text

# -------------------------
# product_detail_screen.dart
# -------------------------
$path = "lib\screens\catalog\product_detail_screen.dart"
$text = Get-Content $path -Raw

$text = $text.Replace("c'Ã¨", "c'e")
$text = $text.Replace("Â±150\u20AC", "+/-150\u20AC")

$text = [regex]::Replace($text, "'[^']*Seleziona prima una variante per confrontare!'", "'Attenzione: Seleziona prima una variante per confrontare!'")
$text = [regex]::Replace($text, "'[^']*Esaurito'", "'Esaurito'")
$text = [regex]::Replace($text, "'[^']*Stock esaurito\.'", "'Attenzione: Stock esaurito.'")
$text = [regex]::Replace($text, "'[^']*Specifiche Tecniche'", "'Specifiche Tecniche'")
$text = [regex]::Replace($text, "text:\s*'[^']*'\s*\+", "text: 'Top Phone - ' +")
$text = [regex]::Replace($text, "'\\n[^']*\\u20AC'\s*\+", "'\\nPrezzo: \\u20AC' +")
$text = [regex]::Replace($text, "const Text\('[\u00C2-\u00F4][^']*\\u20AC'", "const Text('Info'")

Save-Utf8NoBom $path $text

dart format lib
