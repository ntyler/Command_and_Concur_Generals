#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string] $GodotPath)

$ErrorActionPreference = 'Stop'
$wrapper = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/run-godot.ps1'
$failed = 0
$checked = 0
function Assert-Wrapper([bool] $Condition, [string] $Description) {
    $script:checked++
    if ($Condition) { Write-Output "PASS: $Description" }
    else { $script:failed++; Write-Output "FAIL: $Description" }
}

$normal = @(& $wrapper -GodotPath $GodotPath -TimeoutSeconds 15 -GodotArguments @('--version'))
$normalExit = $LASTEXITCODE
Assert-Wrapper ($normalExit -eq 0 -and ($normal -join "`n").Contains('GODOT_EXIT: 0')) 'normal child exit zero is preserved and reported'

$guarded = @(& $wrapper -GodotPath $GodotPath -TimeoutSeconds 15 -GodotArguments @('--headless', '--path', '.', '--script', 'res://tests/blocking_fixture.gd', '--log-file', 'validation-output/m151-fixture-guard.log'))
$guardExit = $LASTEXITCODE
Assert-Wrapper ($guardExit -eq 3) 'blocking fixture refuses an ordinary invocation and child exit three is preserved'

$internal = @(& $wrapper -GodotPath $GodotPath -TimeoutSeconds 15 -GodotArguments @('--headless', '--path', '.', '--script', 'res://tests/milestone_checks.gd', '--log-file', 'validation-output/m151-internal-timeout.log', '--', '--verify-timeout'))
$internalExit = $LASTEXITCODE
Assert-Wrapper ($internalExit -eq 2) 'responsive-loop watchdog exit two is preserved'

$timer = [System.Diagnostics.Stopwatch]::StartNew()
$blocked = @(& $wrapper -GodotPath $GodotPath -TimeoutSeconds 2 -GodotArguments @('--headless', '--path', '.', '--script', 'res://tests/blocking_fixture.gd', '--log-file', 'validation-output/m151-external-timeout.log', '--', '--verify-external-timeout'))
$blockedExit = $LASTEXITCODE
$timer.Stop()
$blockedText = $blocked -join "`n"
Assert-Wrapper ($blockedExit -eq 124 -and $blockedText.Contains('BLOCKING_FIXTURE:') -and $timer.Elapsed.TotalSeconds -lt 12) 'external timeout terminates a blocked main thread with exit 124'
$processIds = [regex]::Matches($blockedText, 'pid=(\d+)') | ForEach-Object { [int] $_.Groups[1].Value }
$survivors = @($processIds | ForEach-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
Assert-Wrapper ($processIds.Count -ge 1 -and $survivors.Count -eq 0) 'neither console launcher nor blocked engine process survives'
Write-Output "WRAPPER_CHECKS: $checked checks, $failed failures; child codes=$normalExit,$guardExit,$internalExit,$blockedExit"
exit $(if ($failed -eq 0) { 0 } else { 1 })
