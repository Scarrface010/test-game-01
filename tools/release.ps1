# One-step release: bumps BUILD, runs tests, exports web + signed Android pack with the SAME build number.
# Usage: powershell -File tools\release.ps1        (then commit + push the files it lists)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$proj="$root\godot-project"
$g='F:\AI\android-build\godot\Godot_v4.4.1-stable_win64_console.exe'
$o='C:\Program Files\Git\usr\bin\openssl.exe'
$key='F:\AI\android-build\keys\update_private.pem'
$utf=New-Object Text.UTF8Encoding $false
$src=[IO.File]::ReadAllText("$proj\main.gd")
$m=[regex]::Match($src,'const BUILD := (\d+)')
$b=[int]$m.Groups[1].Value+1
[IO.File]::WriteAllText("$proj\main.gd",$src.Replace($m.Value,"const BUILD := $b"),$utf)
& $g --headless --path $proj --import 2>&1 | Out-Null
foreach($t in '--test','--advtest','--savetest'){ "$t : " + ((& $g --headless --path $proj -- $t 2>&1 | Select-String 'bad=|unsolvable' | Select-Object -Last 1)) }
& $g --headless --path $proj --export-release Web "$root\index.html" 2>&1 | Out-Null
git -C $root checkout HEAD -- index.manifest.json 2>&1 | Out-Null
& $g --headless --path $proj --export-pack Android "$root\android.pck" 2>&1 | Out-Null
& $o dgst -sha256 -sign $key -out "$root\android.sig" "$root\android.pck"
$sig=[Convert]::ToBase64String([IO.File]::ReadAllBytes("$root\android.sig")); Remove-Item "$root\android.sig"
[IO.File]::WriteAllText("$root\version.json",(@{version=$b;sig=$sig}|ConvertTo-Json -Compress),$utf)
"Build $b ready (web + android). Commit: godot-project/main.gd index.html index.pck index.service.worker.js android.pck version.json"