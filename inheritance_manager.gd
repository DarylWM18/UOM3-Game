extends Node
# DARYL - Corrupt Inheritance System

const INFO := {
    "slippery_anchor": {"label": "SLIPPERY ANCHOR", "desc": "Grapple anchors slide down the wall"},
    "rubber_band": {"label": "RUBBER BAND", "desc": "Tether yanks and bounces violently"},
    "lead_bones": {"label": "LEAD BONES", "desc": "Gravity is 2.4x heavier"},
}

var boss_queue: Array = ["slippery_anchor", "rubber_band", "lead_bones"]
var active_glitches: Array = []
var player

signal glitch_applied(glitch_name: String)

func apply_next_inheritance() -> String:
    if boss_queue.is_empty():
        return ""
    var g: String = boss_queue.pop_front()
    active_glitches.append(g)
    apply_corruption()
    glitch_applied.emit(g)
    return g

# --- SEAM 1: write into Jeremiah's tether engine ---
# Values are clamped so a bad glitch can never break the physics
# (this is the seam the GDD predicted would break first).
func apply_corruption() -> void:
    if player == null:
        return
    var grav := 1.0
    var elastic := 30.0
    var grip := 1.0
    for g in active_glitches:
        match g:
            "slippery_anchor":
                grip = 0.85
            "rubber_band":
                elastic = 110.0
            "lead_bones":
                grav = 2.4
    player.glitch_gravity = clampf(grav, 0.3, 4.0)
    player.rope_elasticity = clampf(elastic, 5.0, 140.0)
    player.anchor_grip = clampf(grip, 0.5, 1.0)
