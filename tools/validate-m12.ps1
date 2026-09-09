#Requires -Version 7.0
<# Expanded ordinary M12 matrix; the existing runner owns snapshots and timeouts. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunName,
    [string] $GodotPath = 'C:\Users\Tyler\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe',
    [double] $TimeoutSeconds = 240
)
$suites = @(
    'builder_checks', 'builder_integration_checks',
    'supply_depot_checks', 'supply_depot_integration_checks',
    'enemy_economy_checks', 'enemy_economy_integration_checks',
    'attack_move_checks', 'attack_move_batch_checks', 'attack_move_ui_checks',
    'hud_clarity_checks', 'milestone_checks', 'movement_repair_checks',
    'parked_deadlock_checks', 'parked_deadlock_controls', 'captured_parked_cluster_checks',
    'projection_step_checks', 'boundary_neighbor_checks', 'boundary_neighbor_controls',
    'gate_movement_checks', 'construction_checks', 'construction_cleanup_checks',
    'harvesting_checks', 'production_checks', 'combat_checks', 'combat_repair_checks',
    'line_of_fire_checks', 'spherical_projectile_checks', 'movement_stress_checks',
    'base_assault_checks', 'vehicle_production_checks', 'combat_load',
    'tactical_interface_checks', 'control_group_checks'
)
& "$PSScriptRoot/validate-m8.ps1" -RunName $RunName -GodotPath $GodotPath -TimeoutSeconds $TimeoutSeconds -Modes @('headless', 'graphical') -Suites $suites
exit $LASTEXITCODE
