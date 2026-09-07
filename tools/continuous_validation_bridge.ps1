#Requires -Version 7.0
param([Parameter(Mandatory = $true)][string] $InvocationPath)
$ErrorActionPreference = 'Stop'
try {
    $invocation = Get-Content -LiteralPath $InvocationPath -Raw | ConvertFrom-Json
    if ($invocation.mode -notin @('parse', 'contract', 'parked')) { throw 'Validation mode only.' }
    $project = Split-Path -Parent $PSScriptRoot
    $receipt = (Get-Item -LiteralPath $InvocationPath).FullName
    if (-not $receipt.EndsWith('-invocation.json')) { throw 'Invalid receipt path.' }
    $prefix = $receipt.Substring(0, $receipt.Length - '-invocation.json'.Length)
    if ((Split-Path -Parent $prefix) -ne (Join-Path $project 'validation-output') -or (Split-Path -Leaf $prefix) -notlike 'm501i-*') { throw 'Invalid validation output prefix.' }
    $inputPath = $prefix + '-inputs.json'
    if ((Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $invocation.inputs_sha256) { throw 'Prepared input changed.' }
    $engine = [string]$invocation.command_argv[0]
    if ((Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant() -ne $invocation.engine_sha256) { throw 'Engine identity changed.' }
    $mode = if ($invocation.mode -eq 'parse') { 'parked' } else { $invocation.mode }
    $engineArgs = @('--headless', '--path', $project, '--fixed-fps', '60', '--script', 'res://tests/continuous_capture_checks.gd', '--log-file', ($prefix + '.log'))
    if ($invocation.mode -eq 'parse') { $engineArgs += '--check-only' }
    $engineArgs += @('--', ('--continuous-mode=' + $mode), ('--continuous-prefix=' + $prefix), ('--continuous-inputs=' + $inputPath))
    $recorded = @($invocation.command_argv | Select-Object -Skip 1)
    if ($recorded.Count -ne $engineArgs.Count) { throw 'Recorded engine arguments mismatch.' }
    for ($i = 0; $i -lt $engineArgs.Count; $i++) {
        if ($recorded[$i] -cne $engineArgs[$i]) { throw 'Recorded engine argument mismatch.' }
    }
    & (Join-Path $PSScriptRoot 'run-godot.ps1') -GodotPath $engine -ProjectPath $project -TimeoutSeconds 240 -GodotArguments $engineArgs
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine('CONTINUOUS_BRIDGE_BLOCKED: ' + $_.Exception.Message)
    exit 2
}
