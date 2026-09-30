extends CharacterBody2D
# Boss AI: approach -> windup (telegraph) -> strike -> recover (-> retreat)

const StickFigure = preload("res://stick_figure.gd")
const GRAVITY := 1900.0

var game
var target
var cfg: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var boss_name := ""
var dead := false
var active := false
var facing := -1
var state := "approach"
var st_t := 0.0
var cd := 1.0
var jump_cd := 0.0
var stun := 0.0
var hit_done := false
var recording: Array = []
var fig

func setup(c: Dictionary, g, t) -> void:
    cfg = c
    game = g
    target = t
    hp = c["hp"]
    max_hp = hp
    boss_name = c["name"]

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    var s: float = cfg.get("scale", 1.0)
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(22, 70) * s
    col.shape = shape
    add_child(col)
    fig = StickFigure.new()
    fig.color = cfg["color"]
    fig.head_style = cfg["head"]
    fig.scale = Vector2(s, s)
    add_child(fig)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += GRAVITY * delta
    stun = maxf(0.0, stun - delta)
    jump_cd = maxf(0.0, jump_cd - delta)
    cd = maxf(0.0, cd - delta)
    if dead:
        velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
    elif stun > 0.0 or not active or target.dead:
        velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
    else:
        _ai(delta)
    move_and_slide()
    if active and not dead:
        _record()
    _update_fig()

func _ai(delta: float) -> void:
    var dx: float = target.global_position.x - global_position.x
    var dist := absf(dx)
    var dy: float = target.global_position.y - global_position.y
    var toward := 1 if dx > 0.0 else -1
    st_t += delta
    match state:
        "approach":
            facing = toward
            velocity.x = move_toward(velocity.x, facing * float(cfg["speed"]), 2600.0 * delta)
            if is_on_floor() and jump_cd <= 0.0 and dy < -100.0 and dist < 380.0:
                velocity.y = -820.0
                jump_cd = 1.6
            if cd <= 0.0 and dist < float(cfg["reach"]) + 18.0 and absf(dy) < 70.0:
                state = "windup"
                st_t = 0.0
        "windup":
            if st_t < 0.1:
                facing = toward
            velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
            if st_t >= float(cfg["windup"]):
                state = "strike"
                st_t = 0.0
                hit_done = false
                velocity.x = facing * float(cfg["lunge"])
        "strike":
            if st_t >= 0.05 and st_t <= 0.2 and not hit_done:
                _try_hit()
            if st_t >= 0.22:
                state = "recover"
                st_t = 0.0
        "recover":
            velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta)
            if st_t >= 0.4:
                cd = float(cfg["cooldown"])
                state = "retreat" if cfg["retreat"] else "approach"
                st_t = 0.0
        "retreat":
            facing = toward
            velocity.x = move_toward(velocity.x, -facing * float(cfg["speed"]) * 1.1, 2600.0 * delta)
            if st_t >= 0.55:
                state = "approach"
                st_t = 0.0

func _try_hit() -> void:
    var reach: float = cfg["reach"]
    var s: float = cfg.get("scale", 1.0)
    var hb := Rect2(global_position + Vector2(facing * (reach * 0.5 + 8.0) - reach * 0.5, -28.0 * s), Vector2(reach, 52.0 * s))
    var tb := Rect2(target.global_position - Vector2(11, 35), Vector2(22, 70))
    if hb.intersects(tb):
        hit_done = true
        target.take_damage(float(cfg["dmg"]), facing, float(cfg["kb"]))

func take_damage(amount: float, dir: int, kb: float) -> void:
    if dead:
        return
    hp -= amount
    fig.flash = 1.0
    var armored := state == "strike" or (state == "windup" and amount < 14.0)
    if not armored:
        stun = 0.18
        velocity = Vector2(dir * kb * 0.6, -140.0)
        state = "approach"
        st_t = 0.0
        cd = maxf(cd, 0.3)
    else:
        velocity.x += dir * kb * 0.15
    if hp <= 0.0:
        hp = 0.0
        dead = true
        fig.pose = "hurt"
        fig.rotation = deg_to_rad(80.0) * -facing
        fig.position = Vector2(0, 28.0 * float(cfg.get("scale", 1.0)))
        game.on_boss_died(self)

func _record() -> void:
    recording.append({
        "p": global_position, "f": facing, "pose": fig.pose, "atk": fig.atk,
        "a": state == "strike" and st_t >= 0.05 and st_t <= 0.2, "r": cfg["reach"],
    })
    if recording.size() > 600:
        recording.pop_front()

func _update_fig() -> void:
    if dead:
        return
    var pose := "idle"
    var atk := 0.0
    if stun > 0.0:
        pose = "hurt"
    elif state == "windup":
        pose = "windup"
    elif state == "strike":
        pose = "punch"
        atk = st_t / 0.22
    elif not is_on_floor():
        pose = "air"
    elif absf(velocity.x) > 40.0:
        pose = "run"
    fig.pose = pose
    fig.atk = atk
    fig.facing = facing
