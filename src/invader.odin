package main

import rl "vendor:raylib"

INVADERS_PER_LINE :: 5
INVADER_LINES :: 8
INVADER_CAPACITY :: INVADER_LINES * INVADERS_PER_LINE
INVADER_SIZE :: rl.Vector2{32, 32}
INVADER_PADDING :: f32(16)

// A small assortment of invaders that together follow a predermined path
GroupSpeed :: f32(0.5)
InvaderGroup :: struct {
	invaders:        [4]bool,
	position:        [4]rl.Vector2,
	time:            f32, // 0 to 1
	brassier_handle: u8, // index into a specific brassier pattern
}


find_available_group_index :: proc() -> int {
	for i := 0; i < INVADER_CAPACITY; i += 1 {
		if !gameState.invader_dead[i] {
			return i
		}
	}
	return -1
}

get_invader_position :: proc(index: int) -> (i32, i32) {
	x := i32(index % INVADERS_PER_LINE)
	y := i32(f32(index) / INVADERS_PER_LINE)
	return x, y
}

/// Calculates the total width of the invaders army
get_invaders_width :: proc() -> f32 {
	return INVADERS_PER_LINE * INVADER_SIZE.x + INVADER_PADDING * INVADERS_PER_LINE
}

setup_invaders :: proc() {
	invaders_width := get_invaders_width()
	origin_x := WINDOW_WIDTH / 2 - invaders_width / 2
	origin_y := f32(100)
	for i := 0; i < INVADER_CAPACITY; i += 1 {
		padding := INVADER_PADDING
		x, y := get_invader_position(i)
		gameState.invader_dead[i] = false
		gameState.invader_x[i] = origin_x + f32(x) * INVADER_SIZE.x + f32(x) * padding
		gameState.invader_y[i] = origin_y + f32(y) * INVADER_SIZE.y + f32(y) * padding
	}
}

draw_invaders :: proc() {
	for i := 0; i < INVADER_CAPACITY; i += 1 {
		if gameState.invader_dead[i] {continue}
		p := rl.Vector2{gameState.invader_x[i], gameState.invader_y[i]}
		rl.DrawRectangleV(p, INVADER_SIZE, rl.GREEN)
	}
}

update_invaders :: proc() {
	someone_hit_wall := false
	for x, i in gameState.invader_x {
		if gameState.invader_dead[i] {continue}

		for pjl, j in gameState.projectiles {
			if pjl.source != .Player || !pjl.alive {continue}
			projectile_rec := rl.Rectangle {
				pjl.position.x,
				pjl.position.y,
				PROJECTILE_WIDTH,
				PROJECTILE_HEIGHT,
			}
			invader_rec := rl.Rectangle {
				gameState.invader_x[i],
				gameState.invader_y[i],
				INVADER_SIZE.x,
				INVADER_SIZE.y,
			}
			if rl.CheckCollisionRecs(projectile_rec, invader_rec) {
				// Feedback
				// TODO: Camera shake
				gameState.camera_shake_time_seconds = 0.1

				// TODO: Particles
				// create_emitter({x, y, .Invader})

				// Unalive them
				gameState.invader_dead[i] = true
				gameState.projectiles.alive[j] = false
				PS_kill_emitter(gameState.projectiles.attached_emitter[j])
			}
		}
	}

	if someone_hit_wall {
		gameState.invader_direction *= -1
		gameState.invader_y += 20
	}
}
