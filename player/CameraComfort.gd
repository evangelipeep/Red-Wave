extends Camera3D
class_name CameraComfort
## Comfort + ощущение движения (GDD §3, обязательно):
##   • FOV (настраиваемый) + лёгкий FOV-kick на скорости — чувство разгона;
##   • headbob (отключаемо) — покачивание при ходьбе;
##   • посадочный «клевок» при приземлении;
##   • «снизить тряску» (reduce_shake) — глобально гасит амплитуду.
## Виньетка на скорости — фаза 6 (нужен пост-шейдер); точка расширения ниже.

@export_group("FOV")
@export var base_fov: float = 75.0
@export var sprint_fov_add: float = 8.0
@export var fov_lerp: float = 8.0

@export_group("Headbob")
@export var headbob_enabled: bool = true
@export var headbob_freq: float = 8.0
@export var headbob_amp: float = 0.04

@export_group("Comfort")
@export var reduce_shake: bool = false   # «снизить тряску»

var _bob_t: float = 0.0
var _base_pos: Vector3
var _land_offset: float = 0.0

func _ready() -> void:
	fov = base_fov
	_base_pos = position

## Вызывается контроллером каждый физический кадр.
## speed_ratio — доля от макс. скорости [0..1], grounded — на земле ли (для bob).
func update_motion(speed_ratio: float, grounded: bool, delta: float, sprinting: bool) -> void:
	var target_fov := base_fov + ((sprint_fov_add * speed_ratio) if sprinting else 0.0)
	fov = lerp(fov, target_fov, clamp(fov_lerp * delta, 0.0, 1.0))

	var amp := headbob_amp * (0.3 if reduce_shake else 1.0)
	var offset := Vector3.ZERO
	if headbob_enabled and grounded and speed_ratio > 0.05:
		_bob_t += delta * headbob_freq * maxf(speed_ratio, 0.4)
		offset.y = sin(_bob_t * TAU) * amp
		offset.x = cos(_bob_t * TAU * 0.5) * amp * 0.5
	else:
		_bob_t = 0.0

	_land_offset = move_toward(_land_offset, 0.0, delta * 0.6)
	position = _base_pos + offset + Vector3(0.0, -_land_offset, 0.0)
	# TODO(фаза 6): _update_vignette(speed_ratio) — пост-эффект на скорости.

func land_kick(strength: float = 0.12) -> void:
	_land_offset = strength * (0.3 if reduce_shake else 1.0)
