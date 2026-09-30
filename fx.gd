extends Node2D
# Hit sparks / particles.

var sparks: Array = []

func burst(pos: Vector2, col: Color, n: int = 10, speed: float = 300.0) -> void:
    for i in n:
        var a := randf() * TAU
        var s := randf_range(0.25, 1.0) * speed
        sparks.append({"p": pos, "v": Vector2(cos(a), sin(a)) * s, "l": randf_range(0.25, 0.6), "c": col})

func _process(delta: float) -> void:
    for i in range(sparks.size() - 1, -1, -1):
        var s: Dictionary = sparks[i]
        s["p"] += s["v"] * delta
        s["v"] *= 0.93
        s["l"] -= delta
        if s["l"] <= 0.0:
            sparks.remove_at(i)
    queue_redraw()

func _draw() -> void:
    for s in sparks:
        var c: Color = s["c"]
        var a := clampf(s["l"] / 0.4, 0.0, 1.0)
        var p: Vector2 = s["p"]
        var v: Vector2 = s["v"]
        draw_line(p, p - v * 0.035, Color(c.r, c.g, c.b, a), 4.0)
        draw_line(p, p - v * 0.03, Color(1, 1, 1, a), 1.5)
