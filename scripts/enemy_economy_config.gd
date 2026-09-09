class_name EnemyEconomyConfig
extends Resource
## Shared settings only. All clocks, jobs and recipients belong to the controller.

@export var starting_credits: int = 300
@export var cache_contents: int = 2000
@export var planning_interval: float = 0.5
@export var first_wave_time: float = 90.0
@export var wave_interval: float = 60.0
@export var preferred_wave_size: int = 3
@export var maximum_wave_size: int = 3
@export var partial_wait: float = 30.0
@export var population_limit: int = 12
@export var staging_point := Vector3(24, 0, 16)
@export var staging_radius: float = 3.2
@export var assault_approach := Vector3(-14, 0, -7)
@export var breach_enabled: bool = false # Fortified Assault only; older scenes unchanged.
@export var breach_reassessment_interval: float = 0.5
@export var breach_candidate_limit: int = 8
