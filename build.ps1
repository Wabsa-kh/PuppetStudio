param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$WindowsTemplate
)
$ErrorActionPreference = 'Stop'
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$templatePath = (Resolve-Path -LiteralPath $WindowsTemplate).Path.Replace('\','/')
$portableDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'portable'
New-Item -ItemType Directory -Force -Path $portableDirectory | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /optimize+ "/out:$PSScriptRoot\platform\InputBridge.exe" "$PSScriptRoot\platform\InputBridge.cs"
if ($LASTEXITCODE -ne 0) { throw 'Input helper compilation failed.' }
Copy-Item -LiteralPath "$PSScriptRoot\platform\InputBridge.exe" -Destination $portableDirectory
& $compiler /nologo /target:winexe /optimize+ /reference:System.Drawing.dll "/out:$PSScriptRoot\platform\GifDecoder.exe" "$PSScriptRoot\platform\GifDecoder.cs"
if ($LASTEXITCODE -ne 0) { throw 'GIF decoder compilation failed.' }
Copy-Item -LiteralPath "$PSScriptRoot\platform\GifDecoder.exe" -Destination $portableDirectory
& $godotPath --headless --path $PSScriptRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $godotPath --headless --path $PSScriptRoot --script res://tests/test_core.gd
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }
$presetPath = Join-Path $PSScriptRoot 'export_presets.cfg'
$originalPresets = Get-Content -LiteralPath $presetPath -Raw
try {
    $localPresets = [regex]::Replace($originalPresets, '(?m)^custom_template/release=.*$', ('custom_template/release="' + $templatePath + '"'))
    Set-Content -LiteralPath $presetPath -Value $localPresets -Encoding utf8
    & $godotPath --headless --path $PSScriptRoot --export-release 'Windows Portable' (Join-Path $portableDirectory 'PuppetStudio.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
} finally {
    Set-Content -LiteralPath $presetPath -Value $originalPresets -Encoding utf8
}
