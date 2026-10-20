# Publishes an Android update: exports android.pck, signs it, writes version.json into the repo root.
# Usage: powershell -File tools\deploy_android.ps1 -Version 2   (must be higher than the last one)
param([Parameter(Mandatory=$true)][int]$Version)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$g='F:\AI\android-build\godot\Godot_v4.4.1-stable_win64_console.exe'
$o='C:\Program Files\Git\usr\bin\openssl.exe'
$key='F:\AI\android-build\keys\update_private.pem'
& $g --headless --path "$root\godot-project" --export-pack Android "$root\android.pck" | Out-Null
& $o dgst -sha256 -sign $key -out "$root\android.sig" "$root\android.pck"
$sig=[Convert]::ToBase64String([IO.File]::ReadAllBytes("$root\android.sig")); Remove-Item "$root\android.sig"
$j=@{version=$Version;sig=$sig} | ConvertTo-Json -Compress
[IO.File]::WriteAllText("$root\version.json",$j,(New-Object Text.UTF8Encoding $false))
"android.pck + version.json written (version $Version). Commit both and push."