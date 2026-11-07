# Exports the Play Store AAB (preset "Android Play") signed with the upload key. versionCode = BUILD from main.gd.
# Usage: powershell -ExecutionPolicy Bypass -File tools\release_play.ps1
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$proj="$root\godot-project"
$g='F:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
$build=[int]([regex]::Match((Get-Content "$proj\main.gd" -Raw),'const BUILD := (\d+)').Groups[1].Value)
$cfg="$proj\export_presets.cfg"
$t=Get-Content $cfg -Raw
$i=$t.IndexOf('[preset.2.options]')
$t=$t.Substring(0,$i)+($t.Substring($i) -replace 'version/code=\d+',"version/code=$build")
[IO.File]::WriteAllText($cfg,$t,(New-Object Text.UTF8Encoding $false))
$pw=((Get-Content F:\AI\android-build\keys\upload_password.txt) -match '^password=') -replace '^password=',''
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH='F:\AI\android-build\keys\upload.keystore'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER='upload'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$pw
$env:JAVA_HOME='F:\Tools\jdk17'
# No Gradle daemon: a lingering daemon kept Godot's output pipe open and the export never returned.
$env:GRADLE_OPTS='-Dorg.gradle.daemon=false'
& $g --headless --path $proj --export-release "Android Play" F:\AI\android-build\out\pocketstation.aab
$built="$proj\android\build\build\outputs\bundle\standardRelease\build-standard-release.aab"
if (Test-Path $built) { Copy-Item $built F:\AI\android-build\out\pocketstation.aab -Force }
"AAB build $build -> F:\AI\android-build\out\pocketstation.aab"
