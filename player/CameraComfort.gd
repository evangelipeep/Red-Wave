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

var nausea: float = 0.0   # 0..1, ставит PlayerController — мутит/качает картинку
var heavy: float = 0.0    # 0..1 (вес 90→100): тяжёлая косолапая походка
var _bob_t: float = 0.0
var _naus_t: float = 0.0
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
	# Тяжёлый (>90 кг): шаги реже, сильнее раскачка вбок — «косолапая», переваливающаяся
	# походка. Эффект мягкий (heavy 0..1), comfort (reduce_shake) дополнительно гасит.
	var hv := heavy * (0.4 if reduce_shake else 1.0)
	if headbob_enabled and grounded and speed_ratio > 0.05:
		_bob_t += delta * headbob_freq * lerpf(1.0, 0.78, hv) * maxf(speed_ratio, 0.4)
		offset.y = sin(_bob_t * TAU) * amp * lerpf(1.0, 1.25, hv)        # тяжелее ступаешь
		offset.x = cos(_bob_t * TAU * 0.5) * amp * lerpf(0.5, 1.6, hv)   # шире вбок (вперевалку)
	else:
		_bob_t = 0.0

	# Тошнота: «мутная» качка камеры (сильнее к полной шкале; comfort гасит).
	if nausea > 0.0:
		var n := nausea * (0.35 if reduce_shake else 1.0)
		_naus_t += delta * 3.2
		offset.x += sin(_naus_t) * 0.07 * n
		offset.y += sin(_naus_t * 1.7) * 0.05 * n
		fov += sin(_naus_t * 0.8) * 2.5 * n

	_land_offset = move_toward(_land_offset, 0.0, delta * 0.6)
	position = _base_pos + offset + Vector3(0.0, -_land_offset, 0.0)
	# TODO(фаза 6): _update_vignette(speed_ratio) — пост-эффект на скорости.

func land_kick(strength: float = 0.12) -> void:
	_land_offset = strength * (0.3 if reduce_shake else 1.0)
