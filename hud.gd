extends Control
# Arcade HUD drawn in one pass.

var game

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    size = Vector2(1280, 720)

func _txt(s: String, pos: Vector2, px: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
    var f := ThemeDB.fallback_font
    draw_string(f, pos + Vector2(2, 2), s, align, width, px, Color(0, 0, 0, col.a * 0.8))
    draw_string(f, pos, s, align, width, px, col)

func _bar(pos: Vector2, w: float, ratio: float, col: Color, from_right: bool) -> void:
    var h := 24.0
    draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.6))
    var fw := w * clampf(ratio, 0.0, 1.0)
    var fx := pos.x + (w - fw if from_right else 0.0)
    draw_rect(Rect2(Vector2(fx, pos.y), Vector2(fw, h)), col)
    draw_rect(Rect2(Vector2(fx, pos.y), Vector2(fw, h * 0.4)), Color(1, 1, 1, 0.22))
    draw_rect(Rect2(pos, Vector2(w, h)), Color(col.r, col.g, col.b, 1.0), false, 2.5)

func _draw() -> void:
    if game == null or game.player == null:
        return
    var p = game.player
    _bar(Vector2(50, 34), 440, p.hp / p.max_hp, Color(0, 1, 1), false)
    _txt("YOU", Vector2(52, 28), 16, Color(0, 1, 1))
    var b = game.boss
    if b != null and is_instance_valid(b):
        _bar(Vector2(790, 34), 440, b.hp / b.max_hp, b.cfg["color"], true)
        _txt(b.boss_name, Vector2(790, 28), 16, b.cfg["color"], HORIZONTAL_ALIGNMENT_RIGHT, 440)
    _txt("ROUND %d/%d" % [game.round_idx + 1, game.BOSSES.size()], Vector2(0, 52), 22, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 1280)
    var secs := int(game.round_time)
    _txt("%02d:%02d" % [secs / 60, secs % 60], Vector2(0, 78), 18, Color(1, 0.3, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 1280)

    # inherited glitches
    var n: int = game.inherit.active_glitches.size()
    if n > 0:
        var y0 := 686.0 - 20.0 * n
        _txt("INHERITED CODE:", Vector2(56, y0 - 22.0), 14, Color(1, 0.3, 0.9))
        for g in game.inherit.active_glitches:
            _txt("> " + game.inherit.INFO[g]["label"] + " - " + game.inherit.INFO[g]["desc"], Vector2(56, y0), 14, Color(1, 1, 1, 0.9))
            y0 += 20.0
    if game.phantom.is_active:
        _txt("ECHO HUNTING YOU", Vector2(0, 690), 16, Color(1, 0.2, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 1224)
    _txt("A/D move  W jump  SHIFT dash  LMB punch  RMB hold = tether (momentum = damage)", Vector2(0, 706), 12, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 1280)

    # banner
    if game.banner_t > 0.0:
        var a := clampf(game.banner_t, 0.0, 1.0)
        _txt(game.banner_title, Vector2(0, 300), 54, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 1280)
        _txt(game.banner_sub, Vector2(0, 345), 22, Color(1, 0.3, 0.9, a), HORIZONTAL_ALIGNMENT_CENTER, 1280)

    # hurt flash, scanlines, vignette
    if game.hurt_flash > 0.0:
        draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0, 0.1, game.hurt_flash * 0.35))
    for sy in range(0, 720, 4):
        draw_line(Vector2(0, sy), Vector2(1280, sy), Color(0, 0, 0, 0.10), 1.0)
    for i in 7:
        draw_rect(Rect2(Vector2(i * 7, i * 7), Vector2(1280 - i * 14, 720 - i * 14)), Color(0, 0, 0, 0.06), false, 14.0)
