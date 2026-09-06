#Requires -Version 7.0
<#
Launch Godot with an external deadline. Normal completion preserves its exit
code; external timeout returns 124 after terminating the entire child tree.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $GodotPath,

    [ValidateRange(0.1, 86400)]
    [double] $TimeoutSeconds = 240,

    [string[]] $GodotArguments = @('--headless', '--path', '.'),

    [string] $ProjectPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$child = $null
$childStarted = $false
try {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Item -LiteralPath $GodotPath).FullName
    $start.WorkingDirectory = (Get-Item -LiteralPath $ProjectPath).FullName
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $GodotArguments) { $start.ArgumentList.Add($argument) }
    $child = [System.Diagnostics.Process]::new()
    $child.StartInfo = $start
    [void] $child.Start()
    $childStarted = $true
    $outputTask = $child.StandardOutput.ReadToEndAsync()
    $errorTask = $child.StandardError.ReadToEndAsync()
    Write-Output "GODOT_PROCESS: pid=$($child.Id) timeout_seconds=$TimeoutSeconds"
    $completed = $child.WaitForExit([int][Math]::Ceiling($TimeoutSeconds * 1000))
    if (-not $completed) {
        # Kill(true) also handles a console launcher spawning another engine process.
        try { $child.Kill($true) } catch [System.InvalidOperationException] { }
        if (-not $child.WaitForExit(10000)) { throw 'Timed-out Godot process could not be terminated.' }
    }
    $standardOutput = $outputTask.GetAwaiter().GetResult()
    $standardError = $errorTask.GetAwaiter().GetResult()
    if ($standardOutput) { Write-Output $standardOutput.TrimEnd() }
    if ($standardError) { [Console]::Error.WriteLine($standardError.TrimEnd()) }
    if (-not $completed) {
        [Console]::Error.WriteLine("EXTERNAL_TIMEOUT: Godot exceeded $TimeoutSeconds seconds; process tree terminated; exit=124")
        exit 124
    }
    $childExit = $child.ExitCode
    Write-Output "GODOT_EXIT: $childExit"
    exit $childExit
} catch {
    [Console]::Error.WriteLine("VALIDATION_LAUNCH_ERROR: $($_.Exception.Message)")
    exit 125
} finally {
    if ($null -ne $child) {
        if ($childStarted -and -not $child.HasExited) { $child.Kill($true) }
        $child.Dispose()
    }
}
