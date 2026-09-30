# Tethered Debt (Godot 4.2+)

Open Godot -> Import -> select project.godot -> press F5.

## Controls
A/D move | W/Space jump | Shift dash | LMB (or F) punch | RMB hold (or E) tether toward the mouse | R restart after death/win
Punch damage scales with your speed: swing or dash into the boss for big hits.

## Files (who owns what)
- player.gd            Jeremiah - movement, dash, tether physics, combat. SEAM 1 vars: glitch_gravity, rope_elasticity, anchor_grip
- inheritance_manager  Daryl    - boss queue + active glitches, writes into the player (clamped, so it can't break physics)
- phantom_echo.gd      Caleb    - replays dead boss's last 10s; reads player.velocity to cut off your swing (SEAM 2)
- boss.gd              boss AI (telegraph -> strike -> recover). Stats live in the BOSSES array in main.gd
- main.gd              round flow, hit-stop, screen shake, input map (created in code)
- stick_figure.gd      procedural neon stick-figure animation
- arena.gd / hud.gd / fx.gd   map, HUD, sparks

Add a boss: append a dictionary to BOSSES in main.gd and a glitch name to boss_queue in inheritance_manager.gd.
