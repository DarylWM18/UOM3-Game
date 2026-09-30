extends Node2D
# TETHERED DEBT - glue: builds the scene in code, runs round flow, juice.

const ArenaScript = preload("res://arena.gd")
const PlayerScript = preload("res://player.gd")
const BossScript = preload("res://boss.gd")
const PhantomScript = preload("res://phantom_echo.gd")
const InheritScript = preload("res://inheritance_manager.gd")
const FxScript = preload("res://fx.gd")
const HudScript = preload("res://hud.gd")

var BOSSES: Array = [
    {"name": "THE DRIFTER", "color": Color(1.0, 0.35, 0.2), "hp": 70.0, "speed": 300.0, "dmg": 10.0,
     "windup": 0.30, "reach": 58.0, "cooldown": 0.7, "lunge": 450.0, "kb": 300.0, "retreat": true, "head": 1, "scale": 1.0},
    {"name": "THE ELASTIC", "color": Color(1.0, 0.9, 0.2), "hp": 100.0, "speed": 260.0, "dmg": 14.0,
     "windup": 0.26, "reach": 66.0, "cooldown": 0.9, "lunge": 760.0, "kb": 420.0, "retreat": false, "head": 2, "scale": 1.0},
    {"name": "LEADFOOT", "color": Color(0.85, 0.9, 1.0), "hp": 150.0, "speed": 170.0, "dmg": 24.0,
     "windup": 0.50, "reach": 92.0, "cooldown": 1.2, "lunge": 150.0, "kb": 600.0, "retreat": false, "head": 1, "scale": 1.25},
]

var player
var boss
var phantom
var inherit
var fx
var hud
var camera: Camera2D

var round_idx := 0
var state := "intro"
var round_time := 0.0
var shake_amt := 0.0
var hurt_flash := 0.0
var banner_title := ""
var banner_sub := ""
var banner_t := 0.0
var hitstop_active := false
var pending_rec: Array = []
var pending_head := 0
var pending_scale := 1.0

func _ready() -> void:
    Engine.time_scale = 1.0
    _setup_input()
    add_child(ArenaScript.new())
    camera = Camera2D.new()
    camera.position = Vector2(640, 360)
    add_child(camera)
    fx = FxScript.new()
    fx.z_index = 10
    add_child(fx)

    player = PlayerScript.new()
    player.game = self
    player.position = Vector2(240, 560)
    add_child(player)

    inherit = InheritScript.new()
    inherit.player = player
    add_child(inherit)

    phantom = PhantomScript.new()
    phantom.target_player = player
    add_child(phantom)

    var layer := CanvasLayer.new()
    hud = HudScript.new()
    hud.game = self
    layer.add_child(hud)
    add_child(layer)

    start_round(0)

func _setup_input() -> void:
    _key("move_left", [KEY_A, KEY_LEFT])
    _key("move_right", [KEY_D, KEY_RIGHT])
    _key("jump", [KEY_W, KEY_SPACE, KEY_UP])
    _key("dash", [KEY_SHIFT, KEY_K])
    _key("attack", [KEY_F, KEY_J])
    _key("grapple", [KEY_E, KEY_L])
    _key("restart", [KEY_R])
    _mouse("attack", MOUSE_BUTTON_LEFT)
    _mouse("grapple", MOUSE_BUTTON_RIGHT)

func _key(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for k in keys:
        var e := InputEventKey.new()
        e.physical_keycode = k
        InputMap.action_add_event(action, e)

func _mouse(action: String, button: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var e := InputEventMouseButton.new()
    e.button_index = button
    InputMap.action_add_event(action, e)

func set_banner(title: String, sub: String, dur: float) -> void:
    banner_title = title
    banner_sub = sub
    banner_t = dur

func start_round(i: int) -> void:
    round_idx = i
    round_time = 0.0
    state = "intro"
    if boss != null and is_instance_valid(boss):
        boss.queue_free()
    boss = BossScript.new()
    boss.setup(BOSSES[i], self, player)
    boss.position = Vector2(1040, 560)
    add_child(boss)
    player.reset_for_round(Vector2(240, 560))
    if pending_rec.size() > 0:
        phantom.load_recording(pending_rec, pending_head, pending_scale)
    else:
        phantom.deactivate()
    var sub := "An echo of the last boss haunts this arena" if pending_rec.size() > 0 else "Tether. Swing. Strike."
    set_banner("ROUND %d - %s" % [i + 1, BOSSES[i]["name"]], sub, 2.2)
    await get_tree().create_timer(1.8).timeout
    if state == "intro":
        state = "fight"
        boss.active = true
        player.locked = false
        set_banner("FIGHT!", "", 0.7)

# ---------- juice ----------
func fx_burst(pos: Vector2, col: Color, n: int = 10, speed: float = 300.0) -> void:
    fx.burst(pos, col, n, speed)

func shake(v: float) -> void:
    shake_amt = maxf(shake_amt, v)

func hitstop(dur: float) -> void:
    if hitstop_active:
        return
    hitstop_active = true
    Engine.time_scale = 0.06
    await get_tree().create_timer(dur, true, false, true).timeout
    Engine.time_scale = 1.0
    hitstop_active = false

func on_hit(pos: Vector2, dmg: float) -> void:
    fx.burst(pos, Color.WHITE, 10, 380.0)
    fx.burst(pos, Color(0, 1, 1), 8, 300.0)
    shake(3.0 + minf(dmg * 0.4, 10.0))
    hitstop(0.035 + dmg * 0.0018)

func on_player_hurt(_amount: float) -> void:
    fx.burst(player.global_position, Color(1, 0.2, 0.3), 14, 350.0)
    shake(9.0)
    hurt_flash = 1.0
    hitstop(0.07)

func on_player_died() -> void:
    state = "dead"
    fx.burst(player.global_position, Color(0, 1, 1), 40, 550.0)
    shake(20.0)
    hitstop(0.4)
    set_banner("TETHER SEVERED", "Press R to restart the gauntlet", 999.0)

func on_boss_died(b) -> void:
    if state != "fight":
        return
    state = "between"
    fx.burst(b.global_position, b.cfg["color"], 45, 650.0)
    fx.burst(b.global_position, Color.WHITE, 20, 500.0)
    shake(18.0)
    hitstop(0.3)
    phantom.deactivate()
    pending_rec = b.recording.duplicate()
    pending_head = b.cfg["head"]
    pending_scale = b.cfg["scale"]
    var g: String = inherit.apply_next_inheritance()
    var label := ""
    if g != "":
        label = "INHERITED: %s - %s" % [inherit.INFO[g]["label"], inherit.INFO[g]["desc"]]
    set_banner("%s DELETED" % b.boss_name, label, 3.4)
    player.locked = true
    await get_tree().create_timer(3.4).timeout
    if round_idx + 1 >= BOSSES.size():
        state = "won"
        player.locked = false
        set_banner("GAUNTLET CLEARED", "Time %02d:%02d - Press R to run it again" % [int(round_time) / 60, int(round_time) % 60], 999.0)
    else:
        start_round(round_idx + 1)

func _process(delta: float) -> void:
    if state == "fight":
        round_time += delta
    banner_t = maxf(0.0, banner_t - delta)
    hurt_flash = maxf(0.0, hurt_flash - delta * 3.0)
    shake_amt *= 0.86
    camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amt
    hud.queue_redraw()
    if (state == "dead" or state == "won") and Input.is_action_just_pressed("restart"):
        get_tree().reload_current_scene()
