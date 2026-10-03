extends Node2D
# CALEB - Phantom Echo System
# Replays the last ~10s of the dead boss, and re-aims itself at where the
# player is HEADING (Seam 2: reads player.velocity).

const StickFigure = preload("res://stick_figure.gd")

var target_player
var recording: Array = []
var is_active := false
var playback_speed := 3.0
var idx_f := 0.0
var shift := Vector2.ZERO
var retarget_t := 0.0
var materialize := 0.0
var strike_cd := 0.0
var fig
var dmg := 12.0

func _ready() -> void:
    z_index = 4
    fig = StickFigure.new()
    fig.color = Color(1.0, 0.15, 0.9, 0.6)
    add_child(fig)
    visible = false

func load_recording(rec: Array, head_style: int, sc: float) -> void:
    recording = rec.duplicate()
    idx_f = 0.0
    fig.head_style = head_style
    fig.scale = Vector2(sc, sc)
    is_active = recording.size() > 10
    visible = is_active
    retarget_t = 0.0

func deactivate() -> void:
    is_active = false
    visible = false

func _retarget() -> void:
    var base: Vector2 = recording[int(idx_f)]["p"]
    # SEAM 2: predict the player's position from their swing/dash velocity
    var v: Vector2 = target_player.velocity
    var predicted: Vector2 = target_player.global_position + v * 0.4
    var side := signf(v.x) if absf(v.x) > 60.0 else (1.0 if randf() > 0.5 else -1.0)
    shift = (predicted + Vector2(side * 170.0, -10.0)) - base

func _physics_process(delta: float) -> void:
    if not is_active or target_player == null or recording.is_empty():
        return
    if target_player.dead:
        return
    retarget_t -= delta
    if retarget_t <= 0.0:
        retarget_t = 3.2
        materialize = 0.9
        _retarget()
    materialize = maxf(0.0, materialize - delta)
    strike_cd = maxf(0.0, strike_cd - delta)
    idx_f += delta * 60.0 * playback_speed
    if idx_f >= recording.size():
        idx_f = 0.0
    var fr: Dictionary = recording[int(idx_f)]
    var p: Vector2 = fr["p"] + shift
    p.x = clampf(p.x, 80.0, 1200.0)
    p.y = clampf(p.y, 90.0, 590.0)
    global_position = p
    fig.facing = fr["f"]
    fig.pose = fr["pose"]
    fig.atk = fr["atk"]
    fig.modulate.a = 0.3 if materialize > 0.0 else 1.0
    if materialize <= 0.0 and fr["a"] and strike_cd <= 0.0:
        var reach: float = fr["r"]
        var f: int = fr["f"]
        var hb := Rect2(global_position + Vector2(f * (reach * 0.5 + 8.0) - reach * 0.5, -28.0), Vector2(reach, 52))
        var tb := Rect2(target_player.global_position - Vector2(11, 35), Vector2(22, 70))
        if hb.intersects(tb):
            strike_cd = 0.6
            var d := 1 if target_player.global_position.x > global_position.x else -1
            target_player.take_damage(dmg, d, 380.0)
