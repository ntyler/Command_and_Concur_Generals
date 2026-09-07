#Requires -Version 7.0
param([Parameter(Mandatory = $true)][string] $InvocationPath)
$ErrorActionPreference = 'Stop'
try {
    $invocation = Get-Content -LiteralPath $InvocationPath -Raw | ConvertFrom-Json
    if ($invocation.mode -notin @('parse', 'validate', 'observe')) { throw 'J validation or single observation only.' }
    $project = Split-Path -Parent $PSScriptRoot
    $receipt = (Get-Item -LiteralPath $InvocationPath).FullName
    if (-not $receipt.EndsWith('-invocation.json')) { throw 'Invalid receipt path.' }
    $prefix = $receipt.Substring(0, $receipt.Length - '-invocation.json'.Length)
    $allowedNames = switch ($invocation.mode) {
        'parse' { @('m501j-parser-1', 'm501j-parser-2') }
        'validate' { @('m501j-validate-1') }
        'observe' { @('m501j-observe-1') }
    }
    if ((Split-Path -Parent $prefix) -ne (Join-Path $project 'validation-output') -or (Split-Path -Leaf $prefix) -notin $allowedNames) { throw 'Invalid bounded execution prefix.' }
    $inputPath = $prefix + '-inputs.json'
    if ((Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $invocation.inputs_sha256) { throw 'Prepared input changed.' }
    $engine = [string]$invocation.command_argv[0]
    if ((Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643') { throw 'Engine identity changed.' }
    if ((Get-FileHash -LiteralPath (Join-Path $project 'scripts/rts_unit.gd') -Algorithm SHA256).Hash.ToLowerInvariant() -ne '1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4') { throw 'Production changed.' }
    if ((Get-FileHash -LiteralPath (Join-Path $project 'tests/fixtures/unit13_predeadlock.json') -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'd56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307') { throw 'Fixture changed.' }
    if ($invocation.producer_manifest.Count -lt 1) { throw 'Missing producer identity manifest.' }
    foreach ($producer in $invocation.producer_manifest) {
        $producerPath = [IO.Path]::GetFullPath((Join-Path $project $producer.File))
        if (-not $producerPath.StartsWith($project + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Producer path outside project.' }
        if ((Get-FileHash -LiteralPath $producerPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $producer.SHA256) { throw 'Producer changed after preparation.' }
    }
    foreach ($gate in $invocation.gate_artifacts) {
        if ((Get-FileHash -LiteralPath $gate.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $gate.sha256) { throw 'Validation gate changed after preparation.' }
    }
    $slotPath = Join-Path $project 'validation-output/m501j-observation-slot.json'
    if ($invocation.mode -eq 'observe') {
        $slot = Get-Content -LiteralPath $slotPath -Raw | ConvertFrom-Json
        if ($slot.invocation_path -cne $receipt -or $slot.attempts -ne 1 -or $invocation.observation_slots_spent -ne 1 -or $invocation.gate_artifacts.Count -lt 5) { throw 'One-shot observation receipt/gates missing.' }
        # Exclusive bridge entry prevents manually replaying the same prepared receipt.
        $entry = [IO.File]::Open(($slotPath + '.entered'), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $entry.Dispose()
    } elseif (Test-Path -LiteralPath $slotPath) { throw 'Observation budget already closed.' }
    $mode = if ($invocation.mode -eq 'parse') { 'validate' } else { $invocation.mode }
    $engineArgs = @('--headless', '--path', $project, '--fixed-fps', '60', '--script', 'res://tests/continuous_route_checks.gd', '--log-file', ($prefix + '.log'))
    if ($invocation.mode -eq 'parse') { $engineArgs += '--check-only' }
    $engineArgs += @('--', ('--diagnostic-prefix=' + $prefix), ('--capture-run-id=' + (Split-Path -Leaf $prefix)), ('--continuous-route-mode=' + $mode), ('--continuous-route-inputs=' + $inputPath))
    $recorded = @($invocation.command_argv | Select-Object -Skip 1)
    if ($recorded.Count -ne $engineArgs.Count) { throw 'Recorded argument count mismatch.' }
    for ($i = 0; $i -lt $engineArgs.Count; $i++) {
        if ($recorded[$i] -cne $engineArgs[$i]) { throw 'Recorded engine argument mismatch.' }
    }
    & (Join-Path $PSScriptRoot 'run-godot.ps1') -GodotPath $engine -ProjectPath $project -TimeoutSeconds 240 -GodotArguments $engineArgs
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine('CONTINUOUS_ROUTE_BRIDGE_BLOCKED: ' + $_.Exception.Message)
    exit 2
}
