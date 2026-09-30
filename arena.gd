extends Node2D
# Cyberpunk arena: collision + fully drawn background.

var solids: Array = []
var buildings: Array = []
var windows: Array = []

func _ready() -> void:
    z_index = -10
    solids = [
        Rect2(0, 640, 1280, 80),     # floor
        Rect2(0, 0, 1280, 40),       # ceiling
        Rect2(0, 0, 40, 720),        # left wall
        Rect2(1240, 0, 40, 720),     # right wall
        Rect2(170, 520, 230, 18),    # low platforms (jumpable)
        Rect2(880, 520, 230, 18),
        Rect2(525, 395, 230, 18),    # mid platform (needs tether/dash)
        Rect2(250, 270, 150, 18),    # high platforms
        Rect2(880, 270, 150, 18),
        Rect2(400, 40, 56, 110),     # hanging pylons (grapple anchors)
        Rect2(824, 40, 56, 110),
    ]
    var body := StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    for r in solids:
        var cs := CollisionShape2D.new()
        var sh := RectangleShape2D.new()
        sh.size = r.size
        cs.shape = sh
        cs.position = r.position + r.size * 0.5
        body.add_child(cs)
    add_child(body)

    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var x := 40.0
    while x < 1240.0:
        var w := rng.randf_range(50.0, 110.0)
        var h := rng.randf_range(150.0, 400.0)
        buildings.append(Rect2(x, 640.0 - h, w, h))
        var gy := int(640.0 - h + 14.0)
        while gy < 620:
            var gx := int(x + 8.0)
            while gx < int(x + w - 12.0):
                if rng.randf() < 0.3:
                    windows.append({"r": Rect2(gx, gy, 6, 9), "c": (Color(0, 1, 1, 0.55) if rng.randf() < 0.5 else Color(1, 0.2, 0.9, 0.55))})
                gx += 16
            gy += 22
        x += w + rng.randf_range(-10.0, 20.0)
    queue_redraw()

func _draw() -> void:
    # sky gradient
    for i in 36:
        var c := Color(0.02, 0.0, 0.07).lerp(Color(0.3, 0.03, 0.28), float(i) / 35.0)
        draw_rect(Rect2(0, i * 20.0, 1280, 21), c)
    # moon
    var mc := Vector2(930, 235)
    draw_circle(mc, 150.0, Color(1, 0.2, 0.75, 0.06))
    draw_circle(mc, 120.0, Color(1, 0.2, 0.75, 0.12))
    draw_circle(mc, 100.0, Color(1.0, 0.35, 0.7))
    for i in 6:
        var y := mc.y + 5.0 + i * 15.0
        draw_rect(Rect2(mc.x - 105.0, y, 210, 2.0 + i * 1.6), Color(0.2, 0.03, 0.22))
    # skyline
    for b in buildings:
        draw_rect(b, Color(0.04, 0.02, 0.1))
        draw_line(b.position, b.position + Vector2(b.size.x, 0), Color(0, 1, 1, 0.45), 2.0)
    for w in windows:
        draw_rect(w["r"], w["c"])
    # floor glow + grid
    draw_rect(Rect2(0, 640, 1280, 80), Color(0.03, 0.01, 0.08))
    for gx in range(0, 1281, 80):
        draw_line(Vector2(gx, 640), Vector2(gx, 720), Color(1, 0.2, 0.9, 0.18), 1.0)
    for gy in [665, 695]:
        draw_line(Vector2(0, gy), Vector2(1280, gy), Color(1, 0.2, 0.9, 0.18), 1.0)
    # solids
    for r in solids:
        draw_rect(r, Color(0.05, 0.03, 0.13))
    for r in solids:
        draw_rect(r, Color(0, 1, 1, 0.18), false, 8.0)
        draw_rect(r, Color(0, 1, 1, 0.9), false, 2.5)
        draw_line(r.position + Vector2(0, r.size.y), r.position + r.size, Color(1, 0.2, 0.9, 0.8), 2.0)
