package main

import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 900

PROJECTILE_WIDTH: f32 : 2.0
PROJECTILE_HEIGHT: f32 : 16.0
PROJECTILE_COLOR :: rl.GREEN
PROJECTILE_SPEED :: 600
removed_projectiles := make(map[int]struct {})

Projectile :: struct {
	x:         f32,
	y:         f32,
	timealive: f32,
}

INVADERS_PER_LINE :: 5
INVADER_LINES :: 8
INVADER_CAPACITY :: INVADER_LINES * INVADERS_PER_LINE
INVADER_SIZE :: rl.Vector2{32, 32}
INVADER_PADDING :: f32(16)

invader_dead := [INVADER_CAPACITY]bool{}
invader_x := [INVADER_CAPACITY]f32{}
invader_y := [INVADER_CAPACITY]f32{}
invader_direction := 1

Player :: struct {
	position:    rl.Vector2,
	projectiles: [dynamic]Projectile,
}

// 48x48 sized player
PLAYER_SIZE :: rl.Vector2{48, 48}
PLAYER_COLOR :: rl.GREEN
PLAYER_Y :: WINDOW_HEIGHT - PLAYER_SIZE.y * 2
PLAYER_SPEED :: 200

get_invader_position :: proc(index: int) -> (i32, i32) {
	x := i32(index % INVADERS_PER_LINE)
	y := i32(f32(index) / INVADERS_PER_LINE)
	return x, y
}

/// Calculates the total width of the invaders army
get_invaders_width :: proc() -> f32 {
	return INVADERS_PER_LINE * INVADER_SIZE.x + INVADER_PADDING * INVADERS_PER_LINE
}

create_player :: proc() -> ^Player {
	p := new(Player)
	p.position = rl.Vector2(0)
	p.position.x = WINDOW_WIDTH / 2 - PLAYER_SIZE.x / 2
	p.position.y = PLAYER_Y
	p.projectiles = [dynamic]Projectile{}
	return p
}

create_projectile :: proc(p: ^Player) -> Projectile {
	x := p.position.x + PLAYER_SIZE.x / 2
	y := p.position.y
	return Projectile{x, y, f32(0)}
}

draw_player :: proc(p: ^Player) {
	rl.DrawRectangleV(p.position, PLAYER_SIZE, PLAYER_COLOR)
}

draw_projectiles :: proc(p: ^Player) {
	for i := uint(0); i < len(p.projectiles); i += 1 {
		pj := p.projectiles[i]
		rl.DrawRectangle(
			i32(pj.x),
			i32(pj.y),
			i32(PROJECTILE_WIDTH),
			i32(PROJECTILE_HEIGHT),
			PROJECTILE_COLOR,
		)
	}
}

update_player :: proc(p: ^Player) {
	dt := rl.GetFrameTime()
	if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
		p.position.x += PLAYER_SPEED * dt
	} else if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
		p.position.x -= PLAYER_SPEED * dt
	}

	// Let's make sure player stays inside the bounds
	p.position.x = clamp(p.position.x, 0, WINDOW_WIDTH - PLAYER_SIZE.x)

	// Shoot?!?!
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
		append(&p.projectiles, create_projectile(p))
	}
}

create_invaders :: proc() {
	invaders_width := get_invaders_width()
	origin_x := WINDOW_WIDTH / 2 - invaders_width / 2
	origin_y := f32(100)
	for i := 0; i < INVADER_CAPACITY; i += 1 {
		padding := INVADER_PADDING
		x, y := get_invader_position(i)
		invader_dead[i] = false
		invader_x[i] = origin_x + f32(x) * INVADER_SIZE.x + f32(x) * padding
		invader_y[i] = origin_y + f32(y) * INVADER_SIZE.y + f32(y) * padding
	}
}

draw_invaders :: proc() {
	for i := 0; i < INVADER_CAPACITY; i += 1 {
		if invader_dead[i] {continue}
		p := rl.Vector2{invader_x[i], invader_y[i]}
		rl.DrawRectangleV(p, INVADER_SIZE, rl.GREEN)
	}
}

update_invaders :: proc(player: ^Player) {
	translation := 100 * rl.GetFrameTime() * f32(invader_direction)
	invader_x = invader_x + translation

	someone_hit_wall := false
	for x, i in invader_x {
		if invader_dead[i] {continue}

		for pjl, j in player.projectiles {
			projectile_rec := rl.Rectangle{pjl.x, pjl.y, PROJECTILE_WIDTH, PROJECTILE_HEIGHT}
			invader_rec := rl.Rectangle{invader_x[i], invader_y[i], INVADER_SIZE.x, INVADER_SIZE.y}
			if rl.CheckCollisionRecs(projectile_rec, invader_rec) {
				invader_dead[i] = true
				removed_projectiles[j] = {}
			}
		}

		if x + INVADER_SIZE.x > WINDOW_WIDTH && invader_direction == 1 {
			someone_hit_wall = true
			break
		} else if x < 0 && invader_direction == -1 {
			someone_hit_wall = true
			break
		}
	}

	if someone_hit_wall {
		invader_direction *= -1
		invader_y += 20
	}
}

update_projectiles :: proc(p: ^Player) {
	dt := rl.GetFrameTime()
	for i := 0; i < len(p.projectiles); i += 1 {
		pj := &p.projectiles[i]
		pj.y -= PROJECTILE_SPEED * dt
		pj.timealive += dt
		if pj.timealive > 5 {
			removed_projectiles[i] = {}
		}
	}
}

remove_dead_projectiles :: proc(p: ^Player) {
	for i, _ in removed_projectiles {
		unordered_remove(&p.projectiles, i)
	}
	clear(&removed_projectiles)
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin Invaders")
	rl.SetTargetFPS(144)
	player: ^Player = create_player()

	create_invaders()

	for {
		if rl.WindowShouldClose() {
			break
		}

		{
			remove_dead_projectiles(player)
			update_player(player)
			update_projectiles(player)
			update_invaders(player)
		}

		{
			rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.DrawText("Invaders left: -", 0, 0, 20, rl.WHITE)
			draw_player(player)
			draw_projectiles(player)
			draw_invaders()

			rl.EndDrawing()
		}
	}
}
