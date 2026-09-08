#Requires -Version 7.0
<#
Run one bounded validation phase on a fresh, source-hashed project copy.
The default matrix is the 44 M7 regression executions plus both M8 suites in
both display modes. Use -Suites for a focused edit/test cycle. A phase directory
is never reused, and all failed executions remain in its results and logs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]*$')]
    [string] $RunName,

    [string] $GodotPath = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe',

    [ValidateRange(0.1, 86400)]
    [double] $TimeoutSeconds = 240,

    [ValidateSet('headless', 'graphical')]
    [string[]] $Modes = @('headless', 'graphical'),

    [ValidatePattern('^[a-z0-9_]+$')]
    [string[]] $Suites = @(
        'milestone_checks', 'movement_repair_checks', 'parked_deadlock_checks',
        'parked_deadlock_controls', 'captured_parked_cluster_checks', 'projection_step_checks',
        'boundary_neighbor_checks', 'boundary_neighbor_controls', 'gate_movement_checks',
        'construction_checks', 'construction_cleanup_checks', 'harvesting_checks',
        'production_checks', 'combat_checks', 'combat_repair_checks', 'line_of_fire_checks',
        'spherical_projectile_checks', 'movement_stress_checks', 'base_assault_checks',
        'vehicle_production_checks', 'combat_load',
        'tactical_interface_checks', 'control_group_checks'
    )
)

$ErrorActionPreference = 'Stop'
$repoPath = (Get-Item -LiteralPath (Split-Path -Parent $PSScriptRoot)).FullName
$runPath = Join-Path $repoPath "validation-output/m8/$RunName"
if (Test-Path -LiteralPath $runPath) { throw "Refusing to overwrite retained phase: $runPath" }
$enginePath = (Get-Item -LiteralPath $GodotPath).FullName
$shellPath = (Get-Process -Id $PID).Path
$projectPath = Join-Path $runPath 'project'
[void] [IO.Directory]::CreateDirectory($projectPath)
$utf8 = [Text.UTF8Encoding]::new($false)

function Write-JsonFile([string] $Path, $Value) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 12), $utf8)
}

function Quote-PowerShell([string] $Value) {
    return "'" + $Value.Replace("'", "''") + "'"
}

$fileNames = @(& git -C $repoPath ls-files --cached --others --exclude-standard | Sort-Object -Unique)
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate repository source.' }
$sourceHashes = [ordered] @{}
foreach ($name in $fileNames) {
    $sourcePath = Join-Path $repoPath $name
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { continue }
    $copyPath = Join-Path $projectPath $name
    [void] [IO.Directory]::CreateDirectory((Split-Path -Parent $copyPath))
    [IO.File]::Copy($sourcePath, $copyPath, $false)
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
    $copyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $copyPath).Hash.ToLowerInvariant()
    if ($sourceHash -ne $copyHash) { throw "Source changed during snapshot: $name" }
    $sourceHashes[$name] = $copyHash
}
Write-JsonFile (Join-Path $runPath 'source-hashes.json') $sourceHashes
[IO.File]::WriteAllLines((Join-Path $runPath 'revision.txt'), @(& git -C $repoPath rev-parse HEAD), $utf8)
[IO.File]::WriteAllLines((Join-Path $runPath 'starting-status.txt'), @(& git -C $repoPath status --short), $utf8)
[IO.File]::WriteAllLines((Join-Path $runPath 'starting-diff.patch'), @(& git -C $repoPath diff HEAD), $utf8)

$commands = [Collections.Generic.List[object]]::new()
$commands.Add([pscustomobject]@{
    label = 'import'; mode = 'headless'; suite = 'import'
    arguments = @('--headless', '--path', $projectPath, '--editor', '--import')
})
foreach ($mode in $Modes) {
    foreach ($suite in $Suites) {
        $scriptName = if ($suite -eq 'combat_load') { 'combat_checks' } else { $suite }
        $engineArguments = @()
        if ($mode -eq 'headless') { $engineArguments += '--headless' }
        $engineArguments += @('--path', $projectPath, '--fixed-fps', '60', '--script', "res://tests/$scriptName.gd")
        if ($suite -eq 'combat_load') { $engineArguments += @('--', '--combat-load') }
        $commands.Add([pscustomobject]@{ label = "$mode-$suite"; mode = $mode; suite = $suite; arguments = $engineArguments })
        if ($suite -eq 'gate_movement_checks') {
            $commands.Add([pscustomobject]@{
                label = "$mode-$suite-avoidance"; mode = $mode; suite = "$suite-avoidance"
                arguments = $engineArguments + @('--', '--avoidance')
            })
        }
    }
}
Write-JsonFile (Join-Path $runPath 'plan.json') ([ordered]@{
    utc = [DateTime]::UtcNow.ToString('o'); engine = $enginePath; shell = $shellPath
    timeout_seconds = $TimeoutSeconds; fresh_copy = $projectPath
    copied_files = $sourceHashes.Count; commands = @($commands.ToArray())
})

$rows = [Collections.Generic.List[object]]::new()
foreach ($command in $commands) {
    $label = $command.label
    $invocationPath = Join-Path $runPath "$label.ps1"
    $wrapperPath = Join-Path $projectPath 'tools/run-godot.ps1'
    $quotedArguments = @($command.arguments | ForEach-Object { Quote-PowerShell $_ }) -join ', '
    $wrapperCall = '& ' + (Quote-PowerShell $wrapperPath) + ' -GodotPath ' + (Quote-PowerShell $enginePath) +
        ' -ProjectPath ' + (Quote-PowerShell $projectPath) + ' -TimeoutSeconds ' +
        $TimeoutSeconds.ToString([Globalization.CultureInfo]::InvariantCulture) + ' -GodotArguments @(' + $quotedArguments + ')'
    [IO.File]::WriteAllText($invocationPath, "$wrapperCall`nexit `$LASTEXITCODE`n", $utf8)
    $wrapperArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $invocationPath)
    $started = [DateTime]::UtcNow
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $shellPath
    $start.WorkingDirectory = $repoPath
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $wrapperArguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        [void] $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $executionExit = $process.ExitCode
    } finally {
        $process.Dispose()
        $watch.Stop()
    }
    $log = $stdout + $stderr
    [IO.File]::WriteAllText((Join-Path $runPath "$label.stdout.log"), $stdout, $utf8)
    [IO.File]::WriteAllText((Join-Path $runPath "$label.stderr.log"), $stderr, $utf8)
    [IO.File]::WriteAllText((Join-Path $runPath "$label.log"), $log, $utf8)
    $summaries = [regex]::Matches($log, '(?m)^[A-Z0-9_]+: (?<checks>\d+) checks, (?<failures>\d+) failures[^\r\n]*')
    $checks = 0
    $failures = 0
    if ($summaries.Count -gt 0) {
        $lastSummary = $summaries[$summaries.Count - 1]
        $checks = [int] $lastSummary.Groups['checks'].Value
        $failures = [int] $lastSummary.Groups['failures'].Value
    }
    $errors = @([regex]::Matches($log, '(?m)^\s*(?:ERROR:|WARNING:|SCRIPT ERROR:|VALIDATION_LAUNCH_ERROR:|EXTERNAL_TIMEOUT:)[^\r\n]*') | ForEach-Object { $_.Value.Trim() })
    $isTest = $label -ne 'import'
    $passed = $executionExit -eq 0 -and $failures -eq 0 -and $errors.Count -eq 0 -and (-not $isTest -or $summaries.Count -gt 0)
    $rows.Add([pscustomobject]@{
        label = $label; mode = $command.mode; suite = $command.suite; utc = $started.ToString('o')
        command = @($shellPath) + $wrapperArguments; wrapper_call = $wrapperCall
        godot_arguments = @($command.arguments); exit = $executionExit
        seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 3)
        checks = $checks; failures = $failures; summary_found = $summaries.Count -gt 0
        errors = $errors; passed = $passed; attribution = if ($passed) { 'none' } else { 'UNASSESSED' }
    })
    Write-JsonFile (Join-Path $runPath 'results.json') @($rows.ToArray())
    $artifactSource = Join-Path $projectPath 'validation-output'
    if (Test-Path -LiteralPath $artifactSource) {
        foreach ($artifact in Get-ChildItem -LiteralPath $artifactSource -Recurse -File) {
            if ($artifact.LastWriteTimeUtc -lt $started.AddSeconds(-1)) { continue }
            $relative = [IO.Path]::GetRelativePath($artifactSource, $artifact.FullName)
            $retainedPath = Join-Path $runPath "artifacts/$label/$relative"
            [void] [IO.Directory]::CreateDirectory((Split-Path -Parent $retainedPath))
            [IO.File]::Copy($artifact.FullName, $retainedPath, $false)
        }
    }
    Write-Output "$label exit=$executionExit checks=$checks failures=$failures native_errors=$($errors.Count) seconds=$($watch.Elapsed.TotalSeconds.ToString('F3'))"
    if ($label -eq 'import' -and -not $passed) { break }
}

$sourceDifferences = @()
foreach ($name in $sourceHashes.Keys) {
    $currentPath = Join-Path $repoPath $name
    if (-not (Test-Path -LiteralPath $currentPath -PathType Leaf) -or
        (Get-FileHash -Algorithm SHA256 -LiteralPath $currentPath).Hash.ToLowerInvariant() -ne $sourceHashes[$name]) {
        $sourceDifferences += $name
    }
}
$testRows = @($rows | Where-Object label -ne 'import')
$failedRows = @($rows | Where-Object { -not $_.passed })
$summary = [ordered]@{
    run_name = $RunName; fresh_import_passed = $rows.Count -gt 0 -and $rows[0].passed
    planned_test_runs = $commands.Count - 1; completed_test_runs = $testRows.Count
    passed_tests = @($testRows | Where-Object passed).Count
    checks = ($testRows | Measure-Object -Property checks -Sum).Sum
    failures = ($testRows | Measure-Object -Property failures -Sum).Sum
    native_error_lines = @($rows | ForEach-Object { $_.errors }).Count
    failed_executions = @($failedRows | ForEach-Object label)
    seconds = [Math]::Round(($rows | Measure-Object -Property seconds -Sum).Sum, 3)
    captured_source_files = $sourceHashes.Count; source_differences_after_run = $sourceDifferences
    passed = $failedRows.Count -eq 0 -and $rows.Count -eq $commands.Count
}
Write-JsonFile (Join-Path $runPath 'summary.json') $summary
Write-Output (ConvertTo-Json -InputObject $summary -Depth 5 -Compress)
Write-Output "RESULTS: $runPath/results.json"
if (-not $summary.passed) { exit 1 }
exit 0
