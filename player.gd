extends CharacterBody2D
# JEREMIAH - Tether & Combat Engine

const StickFigure = preload("res://stick_figure.gd")

const SPEED := 380.0
const JUMP_VELOCITY := -720.0
const BASE_GRAVITY := 1900.0
const GRAPPLE_RANGE := 640.0
const MAX_SPEED := 1500.0

# --- SEAM 1: Daryl's InheritanceManager overwrites these ---
var glitch_gravity: float = 1.0
var rope_elasticity: float = 30.0   # pull strength (+ bounce when high)
var anchor_grip: float = 1.0        # <1.0 = anchor slides down the wall

# --- SEAM 2: Caleb's PhantomEcho reads `velocity` ---

var game
var hp: float = 100.0
var max_hp: float = 100.0
var dead := false
var locked := true
var facing := 1

var is_grappling := false
var grapple_point := Vector2.ZERO
var rope_len := 0.0
var aim_dir := Vector2.RIGHT
var aim_hit := false
var aim_point := Vector2.ZERO

var attack_t := -1.0
var attack_hit := false
var atk_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := 1
var air_dash_used := false
var invuln := 0.0
var stun := 0.0
var coyote := 0.0
var jump_buf := 0.0

var fig

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1
    var col := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(22, 70)
    col.shape = shape
    add_child(col)
    fig = StickFigure.new()
    fig.color = Color(0.0, 1.0, 1.0)
    add_child(fig)

func reset_for_round(pos: Vector2) -> void:
    hp = max_hp
    dead = false
    global_position = pos
    velocity = Vector2.ZERO
    is_grappling = false
    attack_t = -1.0
    stun = 0.0
    dash_t = 0.0
    invuln = 0.5
    locked = true
    fig.rotation = 0.0
    fig.position = Vector2.ZERO

func _release() -> void:
    is_grappling = false

func _physics_process(delta: float) -> void:
    if dead:
        velocity.y += BASE_GRAVITY * delta
        velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
        move_and_slide()
        return

    invuln = maxf(0.0, invuln - delta)
    stun = maxf(0.0, stun - delta)
    atk_cd = maxf(0.0, atk_cd - delta)
    dash_cd = maxf(0.0, dash_cd - delta)
    var can_act := not locked and stun <= 0.0
    var dir := 0.0
    if can_act:
        dir = Input.get_axis("move_left", "move_right")

    # ---- aim + preview ray ----
    var to_mouse := get_global_mouse_position() - global_position
    aim_dir = to_mouse.normalized() if to_mouse.length() > 2.0 else Vector2(facing, 0)
    var q := PhysicsRayQueryParameters2D.create(global_position, global_position + aim_dir * GRAPPLE_RANGE, 1)
    var res: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
    aim_hit = not res.is_empty()
    if aim_hit:
        aim_point = res["position"]

    if dir != 0.0:
        facing = 1 if dir > 0.0 else -1
    if attack_t >= 0.0 or is_grappling:
        facing = 1 if aim_dir.x >= 0.0 else -1

    # ---- floor bookkeeping ----
    var on_floor := is_on_floor()
    if on_floor:
        coyote = 0.1
        air_dash_used = false
    else:
        coyote -= delta
    jump_buf -= delta
    if can_act and Input.is_action_just_pressed("jump"):
        jump_buf = 0.12

    # ---- dash ----
    if can_act and Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and not is_grappling and (on_floor or not air_dash_used):
        dash_t = 0.15
        dash_cd = 0.55
        dash_dir = (1 if dir > 0.0 else -1) if dir != 0.0 else facing
        facing = dash_dir
        if not on_floor:
            air_dash_used = true
        game.fx_burst(global_position + Vector2(0, 20), Color(0.0, 1.0, 1.0), 10, 250.0)

    # ---- gravity / dash override ----
    if dash_t > 0.0:
        dash_t -= delta
        velocity.x = dash_dir * 950.0
        velocity.y = 0.0
    else:
        if not on_floor:
            velocity.y += BASE_GRAVITY * glitch_gravity * delta

        # jump
        if jump_buf > 0.0 and coyote > 0.0:
            velocity.y = JUMP_VELOCITY
            jump_buf = 0.0
            coyote = 0.0
            game.fx_burst(global_position + Vector2(0, 34), Color(0.0, 1.0, 1.0), 6, 160.0)
        if Input.is_action_just_released("jump") and velocity.y < -250.0 and not is_grappling:
            velocity.y *= 0.55

        # horizontal
        if stun > 0.0:
            if on_floor:
                velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
        elif is_grappling and not on_floor:
            velocity.x += dir * 1100.0 * delta
        else:
            if not on_floor and absf(velocity.x) > SPEED and (dir == 0.0 or signf(dir) == signf(velocity.x)):
                velocity.x = move_toward(velocity.x, signf(velocity.x) * SPEED, 350.0 * delta)
            else:
                velocity.x = move_toward(velocity.x, dir * SPEED, (3600.0 if on_floor else 2200.0) * delta)

    # ---- grapple ----
    if can_act and Input.is_action_just_pressed("grapple") and aim_hit:
        is_grappling = true
        grapple_point = aim_point
        rope_len = global_position.distance_to(grapple_point)
        game.fx_burst(grapple_point, Color(1, 0.2, 0.95), 12, 260.0)
    if is_grappling and (not Input.is_action_pressed("grapple") or stun > 0.0 or locked):
        _release()

    if is_grappling:
        # SEAM 1 (anchor_grip): anchor slides down the surface
        if anchor_grip < 1.0:
            grapple_point.y += (1.0 - anchor_grip) * 1400.0 * delta
            if grapple_point.y > 636.0:
                _release()
    if is_grappling:
        var to_anchor := grapple_point - global_position
        var dist := to_anchor.length()
        var n := to_anchor / maxf(dist, 0.001)
        # SEAM 1 (rope_elasticity): reel pull + rubber bounce
        if dist > 80.0:
            velocity += n * rope_elasticity * 16.0 * delta
        rope_len = maxf(minf(rope_len, dist), 70.0)
        if dist > rope_len:
            var out := -n
            var radial := velocity.dot(out)
            var bounce := maxf(0.0, (rope_elasticity - 30.0) / 100.0)
            if radial > 0.0:
                velocity -= out * radial * (1.0 + bounce)
            velocity += n * (dist - rope_len) * 8.0

    # ---- attack ----
    if can_act and Input.is_action_just_pressed("attack") and atk_cd <= 0.0 and attack_t < 0.0:
        attack_t = 0.0
        attack_hit = false
        atk_cd = 0.32
        facing = 1 if aim_dir.x >= 0.0 else -1
    if attack_t >= 0.0:
        attack_t += delta
        if attack_t >= 0.07 and attack_t <= 0.22 and not attack_hit:
            _check_hit()
        if attack_t > 0.3:
            attack_t = -1.0

    if velocity.length() > MAX_SPEED:
        velocity = velocity.normalized() * MAX_SPEED
    move_and_slide()

func _check_hit() -> void:
    var target = game.boss
    if target == null or not is_instance_valid(target) or target.dead:
        return
    var hb := Rect2(global_position + Vector2(facing * 38.0 - 26.0, -26.0), Vector2(52, 44))
    var s: float = target.cfg.get("scale", 1.0)
    var tb := Rect2(target.global_position - Vector2(11, 35) * s, Vector2(22, 70) * s)
    if hb.intersects(tb):
        attack_hit = true
        var bonus := clampf(velocity.length() / 45.0, 0.0, 24.0)   # momentum = damage
        var dmg := 8.0 + bonus
        target.take_damage(dmg, facing, 280.0 + bonus * 12.0)
        game.on_hit(target.global_position, dmg)

func take_damage(amount: float, dir: int, kb: float) -> void:
    if dead or invuln > 0.0:
        return
    hp -= amount
    invuln = 0.6
    stun = 0.28
    velocity = Vector2(dir * kb, -260.0)
    is_grappling = false
    attack_t = -1.0
    dash_t = 0.0
    fig.flash = 1.0
    game.on_player_hurt(amount)
    if hp <= 0.0:
        hp = 0.0
        dead = true
        fig.pose = "hurt"
        fig.rotation = deg_to_rad(80.0) * -facing
        fig.position = Vector2(0, 28)
        game.on_player_died()

func _process(_delta: float) -> void:
    if dead:
        return
    var pose := "idle"
    if stun > 0.0:
        pose = "hurt"
    elif attack_t >= 0.0:
        pose = "punch"
    elif is_grappling:
        pose = "swing"
    elif not is_on_floor():
        pose = "air"
    elif absf(velocity.x) > 40.0:
        pose = "run"
    fig.pose = pose
    fig.facing = facing
    fig.atk = maxf(attack_t, 0.0) / 0.3
    fig.aim = aim_dir
    fig.rope_to = grapple_point if is_grappling else null
    fig.reticle = aim_point if (aim_hit and not locked) else null
    fig.modulate.a = 0.45 if (invuln > 0.0 and int(invuln * 24.0) % 2 == 0) else 1.0
