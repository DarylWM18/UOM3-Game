extends Node2D
# Procedurally drawn neon stick figure. No image assets needed.

var color: Color = Color(0.0, 1.0, 1.0)
var facing: int = 1
var pose: String = "idle"   # idle, run, air, punch, windup, swing, hurt
var atk: float = 0.0        # 0..1 attack progress
var aim: Vector2 = Vector2.RIGHT
var flash: float = 0.0
var head_style: int = 0     # 0 ring, 1 horned, 2 visor
var rope_to = null          # world position of anchor, or null
var reticle = null          # world position of aim preview, or null
var t: float = 0.0

func _process(delta: float) -> void:
    t += delta
    flash = maxf(0.0, flash - delta * 5.0)
    queue_redraw()

func _m(v: Vector2) -> Vector2:
    return Vector2(v.x * facing, v.y)

func _seg(a: Vector2, b: Vector2, c: Color) -> void:
    var col := Color(lerpf(c.r, 1.0, flash), lerpf(c.g, 1.0, flash), lerpf(c.b, 1.0, flash), c.a)
    draw_line(a, b, Color(col.r, col.g, col.b, col.a * 0.22), 10.0, true)
    draw_line(a, b, col, 4.0, true)
    draw_line(a, b, Color(1, 1, 1, col.a * 0.7), 1.5, true)

func _limb(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
    _seg(a, b, col)
    _seg(b, c, col)

func _draw() -> void:
    var ph := t * 13.0
    var lean := 0.0
    var breathe := sin(t * 3.0) * 1.0
    var foot_f := Vector2(9, 35)
    var foot_b := Vector2(-9, 35)
    var hand_f := Vector2(16, -8)
    var hand_b := Vector2(7, -4)
    match pose:
        "run":
            foot_f = Vector2(sin(ph) * 15.0, 35.0 - maxf(0.0, -cos(ph)) * 9.0)
            foot_b = Vector2(-sin(ph) * 15.0, 35.0 - maxf(0.0, cos(ph)) * 9.0)
            hand_f = Vector2(6.0 - sin(ph) * 13.0, -3)
            hand_b = Vector2(6.0 + sin(ph) * 13.0, -3)
            lean = 5.0
        "air":
            foot_f = Vector2(11, 24); foot_b = Vector2(-9, 32)
            hand_f = Vector2(14, -18); hand_b = Vector2(-6, -14)
        "swing":
            foot_f = Vector2(-4, 34); foot_b = Vector2(-13, 30)
            hand_b = Vector2(-8, -16)
            lean = 6.0
        "hurt":
            foot_f = Vector2(-6, 35); foot_b = Vector2(10, 33)
            hand_f = Vector2(-12, -18); hand_b = Vector2(-16, -6)
            lean = -8.0
        "windup":
            hand_f = Vector2(-10, -6); hand_b = Vector2(10, -12)
            lean = -4.0
        "punch":
            var e := sin(clampf(atk, 0.0, 1.0) * PI)
            hand_f = Vector2(10.0 + 34.0 * e, -10.0 - 2.0 * e)
            hand_b = Vector2(-4, -6)
            lean = 6.0 * e
            foot_f = Vector2(14, 35); foot_b = Vector2(-12, 35)
    var hip := Vector2(0, 8)
    var neck := _m(Vector2(lean * 0.6, -14.0 + breathe))
    var head := _m(Vector2(lean * 1.2, -25.0 + breathe))
    var sh := neck + Vector2(0, 3)
    var ff := _m(foot_f)
    var fb := _m(foot_b)
    var hf := _m(hand_f)
    var hb := _m(hand_b)
    if pose == "swing":
        hf = sh + aim.normalized() * 28.0
    var kf := (hip + ff) * 0.5 + Vector2(facing * 6.0, -2)
    var kb := (hip + fb) * 0.5 + Vector2(facing * 6.0, -2)
    var ef := (sh + hf) * 0.5 + Vector2(0, 5)
    var eb := (sh + hb) * 0.5 + Vector2(0, 5)
    var back := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, color.a)
    # back limbs
    _limb(hip, kb, fb, back)
    _limb(sh, eb, hb, back)
    # torso
    _seg(hip, neck, color)
    # front leg
    _limb(hip, kf, ff, color)
    # head
    var hc := Color(lerpf(color.r, 1.0, flash), lerpf(color.g, 1.0, flash), lerpf(color.b, 1.0, flash), color.a)
    draw_arc(head, 9.0, 0, TAU, 24, Color(hc.r, hc.g, hc.b, hc.a * 0.25), 9.0, true)
    draw_arc(head, 9.0, 0, TAU, 24, hc, 3.5, true)
    match head_style:
        1:
            _seg(head + Vector2(-6, -7), head + Vector2(-10, -18), color)
            _seg(head + Vector2(6, -7), head + Vector2(10, -18), color)
        2:
            draw_circle(head, 7.0, Color(hc.r, hc.g, hc.b, hc.a * 0.6))
            draw_line(head + Vector2(-2 * facing, -1), head + Vector2(10 * facing, -1), Color(0, 0, 0, hc.a), 3.0)
        _:
            draw_circle(head + Vector2(3 * facing, -1), 1.6, Color(1, 1, 1, hc.a))
    # front arm
    _limb(sh, ef, hf, color)
    # tether visuals
    if rope_to != null:
        var end: Vector2 = to_local(rope_to)
        draw_line(hf, end, Color(1, 0.1, 0.9, 0.28), 9.0, true)
        draw_line(hf, end, Color(1, 0.2, 0.95), 3.0, true)
        draw_line(hf, end, Color(1, 1, 1, 0.8), 1.0, true)
        draw_circle(end, 7.0, Color(1, 0.2, 0.95, 0.9))
        draw_circle(end, 3.0, Color.WHITE)
    elif reticle != null:
        var r: Vector2 = to_local(reticle)
        draw_line(sh, r, Color(1, 0.2, 0.95, 0.12), 1.0)
        draw_arc(r, 9.0, 0, TAU, 16, Color(1, 0.2, 0.95, 0.85), 2.0, true)
        draw_circle(r, 2.0, Color(1, 1, 1, 0.9))
