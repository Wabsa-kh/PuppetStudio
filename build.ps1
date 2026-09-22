param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$WindowsTemplate,
    [switch]$FullChecks
)
$ErrorActionPreference = 'Stop'
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$templatePath = (Resolve-Path -LiteralPath $WindowsTemplate).Path.Replace('\','/')
$deliveryDirectory = Split-Path $PSScriptRoot -Parent
$portableDirectory = Join-Path $deliveryDirectory 'portable'
$checkDirectory = Join-Path $deliveryDirectory 'evidence\build'
$stagingDirectory = Join-Path $checkDirectory 'staging'
New-Item -ItemType Directory -Force -Path $portableDirectory,$checkDirectory,$stagingDirectory | Out-Null

function Invoke-CheckedProcess {
    param([string]$Executable, [string[]]$Arguments, [string]$Label, [string]$SuccessPattern = '', [int]$TimeoutSeconds = 180)
    $stdout = Join-Path $checkDirectory ($Label + '.log')
    $stderr = Join-Path $checkDirectory ($Label + '.stderr.log')
    # Start-Process joins its argument array; preserve paths containing spaces.
    $quoted = ($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $process = Start-Process -FilePath $Executable -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        throw "$Label timed out. See $stdout"
    }
    $process.Refresh()
    $result = (Get-Content -LiteralPath $stdout -Raw) + "`n" + (Get-Content -LiteralPath $stderr -Raw)
    $result = [regex]::Replace($result, '\x1B\[[0-?]*[ -/]*[@-~]', '')
    # Godot can return zero even after a script parse error or export failure.
    if ($process.ExitCode -ne 0 -or $result -match '(?m)(SCRIPT ERROR:|^ERROR:|^FAIL:)') {
        throw "$Label failed. See $stdout and $stderr"
    }
    if ($SuccessPattern -and $result -notmatch $SuccessPattern) {
        throw "$Label did not produce its required completion result. See $stdout"
    }
    Write-Output "$Label passed"
}

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /optimize+ "/out:$PSScriptRoot\platform\InputBridge.exe" "$PSScriptRoot\platform\InputBridge.cs"
if ($LASTEXITCODE -ne 0) { throw 'Input helper compilation failed.' }
& $compiler /nologo /target:winexe /optimize+ /reference:System.Drawing.dll "/out:$PSScriptRoot\platform\GifDecoder.exe" "$PSScriptRoot\platform\GifDecoder.cs"
if ($LASTEXITCODE -ne 0) { throw 'GIF decoder compilation failed.' }
foreach ($helper in 'InputBridge.exe','GifDecoder.exe') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "platform\$helper") -Destination $stagingDirectory -Force
}
Invoke-CheckedProcess $godotPath @('--headless','--path',$PSScriptRoot,'--editor','--import','--quit') 'import'
Invoke-CheckedProcess $godotPath @('--headless','--path',$PSScriptRoot,'--script','res://tests/test_core.gd') 'core' 'RESULT: \d+ checks, 0 failures'
Invoke-CheckedProcess $godotPath @('--headless','--path',$PSScriptRoot,'--script','res://tests/test_release_safety.gd') 'save-safety' 'SAFETY_RESULT: \d+ checks, 0 failures'
if ($FullChecks) {
    foreach ($suite in 'workspace','advanced','rig','editor_ui','lifecycle') {
        Invoke-CheckedProcess $godotPath @('--path',$PSScriptRoot,'--script',"res://tests/test_$suite.gd") $suite 'RESULT: \d+( workspace)? checks, 0 failures'
    }
}
$presetPath = Join-Path $PSScriptRoot 'export_presets.cfg'
$originalPresets = [IO.File]::ReadAllBytes($presetPath)
$stagedExecutable = Join-Path $stagingDirectory 'PuppetStudio.exe'
try {
    $localPresets = [regex]::Replace([Text.Encoding]::UTF8.GetString($originalPresets), '(?m)^custom_template/release=.*$', ('custom_template/release="' + $templatePath + '"'))
    [IO.File]::WriteAllText($presetPath, $localPresets, [Text.UTF8Encoding]::new($false))
    Invoke-CheckedProcess $godotPath @('--headless','--path',$PSScriptRoot,'--export-release','Windows Portable',$stagedExecutable) 'export' '\[ DONE \] savepack' 300
} finally {
    [IO.File]::WriteAllBytes($presetPath, $originalPresets)
}
if (-not (Test-Path -LiteralPath $stagedExecutable)) { throw 'No executable was exported.' }
Invoke-CheckedProcess $stagedExecutable @('--','--self-test',('--preview-shot=' + (Join-Path $checkDirectory 'exported.png'))) 'exported' 'EXPORTED_RESULT: \d+ checks, 0 failures'
# Publish only after the staged executable has passed its own runtime checks.
$destination = Join-Path $portableDirectory 'PuppetStudio.exe'
if (Test-Path -LiteralPath $destination) {
    [IO.File]::Replace($stagedExecutable, $destination, (Join-Path $checkDirectory 'previous-PuppetStudio.exe'))
} else {
    [IO.File]::Move($stagedExecutable, $destination)
}
foreach ($helper in 'InputBridge.exe','GifDecoder.exe') {
    Copy-Item -LiteralPath (Join-Path $stagingDirectory $helper) -Destination $portableDirectory -Force
}
Write-Output 'Verified Windows executable published to portable/PuppetStudio.exe'
