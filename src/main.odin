package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 900

PROJECTILE_WIDTH: f32 : 2.0
PROJECTILE_HEIGHT: f32 : 16.0
PROJECTILE_COLOR :: rl.GREEN
PROJECTILE_SPEED :: 600
// removed_projectiles := make(map[int]struct {})

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

// invader_direction := 1
// Player :: struct {
// 	position:    rl.Vector2,
// }

// 48x48 sized player
PLAYER_SIZE :: rl.Vector2{48, 48}
PLAYER_COLOR :: rl.GREEN
PLAYER_Y :: WINDOW_HEIGHT - PLAYER_SIZE.y * 2
PLAYER_SPEED :: 200

BEATS_IN_SONG :: 8

GameState :: struct {
	player_position:            rl.Vector2,
	player_projectiles:         [dynamic]Projectile,
	removed_player_projectiles: map[int]struct {},
	invader_dead:               [INVADER_CAPACITY]bool,
	invader_x:                  [INVADER_CAPACITY]f32,
	invader_y:                  [INVADER_CAPACITY]f32,
	invader_direction:          i8,
	bpm:                        u8,
	rhytms:                     map[int]struct {},
}

gameState := GameState{}

get_invader_position :: proc(index: int) -> (i32, i32) {
	x := i32(index % INVADERS_PER_LINE)
	y := i32(f32(index) / INVADERS_PER_LINE)
	return x, y
}

/// Calculates the total width of the invaders army
get_invaders_width :: proc() -> f32 {
	return INVADERS_PER_LINE * INVADER_SIZE.x + INVADER_PADDING * INVADERS_PER_LINE
}

init_game :: proc() {
	gameState.player_position = rl.Vector2(0)
	gameState.player_position.x = WINDOW_WIDTH / 2 - PLAYER_SIZE.x / 2
	gameState.player_position.y = PLAYER_Y
	gameState.player_projectiles = [dynamic]Projectile{}

	gameState.invader_dead = [INVADER_CAPACITY]bool{}
	gameState.invader_x = [INVADER_CAPACITY]f32{}
	gameState.invader_y = [INVADER_CAPACITY]f32{}
	gameState.invader_direction = 1

	gameState.bpm = 130
	gameState.rhytms[0] = {}
	gameState.rhytms[3] = {}
	gameState.rhytms[4] = {}

	setup_invaders()
}

create_projectile :: proc() -> Projectile {
	x := gameState.player_position.x + PLAYER_SIZE.x / 2
	y := gameState.player_position.y
	return Projectile{x, y, f32(0)}
}

draw_player :: proc() {
	rl.DrawRectangleV(gameState.player_position, PLAYER_SIZE, PLAYER_COLOR)
}

draw_projectiles :: proc() {
	for i := uint(0); i < len(gameState.player_projectiles); i += 1 {
		pj := gameState.player_projectiles[i]
		rl.DrawRectangle(
			i32(pj.x),
			i32(pj.y),
			i32(PROJECTILE_WIDTH),
			i32(PROJECTILE_HEIGHT),
			PROJECTILE_COLOR,
		)
	}
}

update_player :: proc() {
	dt := rl.GetFrameTime()

	player_position := &gameState.player_position

	if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
		gameState.player_position.x += PLAYER_SPEED * dt
	} else if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
		gameState.player_position.x -= PLAYER_SPEED * dt
	}

	// Let's make sure player stays inside the bounds
	gameState.player_position.x = clamp(
		gameState.player_position.x,
		0,
		WINDOW_WIDTH - PLAYER_SIZE.x,
	)

	// Shoot?!?!
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
		append(&gameState.player_projectiles, create_projectile())
	}
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

		for pjl, j in gameState.player_projectiles {
			projectile_rec := rl.Rectangle{pjl.x, pjl.y, PROJECTILE_WIDTH, PROJECTILE_HEIGHT}
			invader_rec := rl.Rectangle {
				gameState.invader_x[i],
				gameState.invader_y[i],
				INVADER_SIZE.x,
				INVADER_SIZE.y,
			}
			if rl.CheckCollisionRecs(projectile_rec, invader_rec) {
				gameState.invader_dead[i] = true
				gameState.removed_player_projectiles[j] = {}
			}
		}
	}

	if someone_hit_wall {
		gameState.invader_direction *= -1
		gameState.invader_y += 20
	}
}

update_projectiles :: proc() {
	dt := rl.GetFrameTime()
	for i := 0; i < len(gameState.player_projectiles); i += 1 {
		pj := &gameState.player_projectiles[i]
		pj.y -= PROJECTILE_SPEED * dt
		pj.timealive += dt
		if pj.timealive > 5 {
			gameState.removed_player_projectiles[i] = {}
		}
	}
}

remove_dead_projectiles :: proc() {
	for i, _ in gameState.removed_player_projectiles {
		unordered_remove(&gameState.player_projectiles, i)
	}
	clear(&gameState.removed_player_projectiles)
}

rhtym_event :: proc() {
	would_translate := 50 * f32(gameState.invader_direction)

	someone_hit_wall := false
	for x, i in gameState.invader_x {
		if (x + would_translate) + INVADER_SIZE.x > WINDOW_WIDTH &&
		   gameState.invader_direction == 1 {
			someone_hit_wall = true
			break
		} else if (x + would_translate) < 0 && gameState.invader_direction == -1 {
			someone_hit_wall = true
			break
		}
	}

	if someone_hit_wall {
		gameState.invader_direction *= -1
		gameState.invader_y += 20
	} else {
		translation := 50 * f32(gameState.invader_direction)
		gameState.invader_x = gameState.invader_x + translation
	}
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin Invaders")
	rl.SetTargetFPS(144)

	init_game()

	rl.InitAudioDevice()
	song := rl.LoadMusicStream("../assets/beat-invaders.wav")
	song.looping = true
	rl.SetMusicVolume(song, 0.2)
	rl.PlayMusicStream(song)

	totalLength := rl.GetMusicTimeLength(song)
	bps := f32(gameState.bpm) / 60
	beatsInSong := u32(bps * totalLength)
	fmt.println(beatsInSong)

	// If we can figure out the current beat we are on (the beat we are the closest to)
	// then we can trigger different stuff depending on if its a rhytm beat (on change to it)

	currentBeat := int(0)
	lastFrameBeat := int(-1)

	for {
		if rl.WindowShouldClose() {
			break
		}

		{
			rl.UpdateMusicStream(song)

			t := rl.GetMusicTimePlayed(song) / totalLength // 0 -> 1
			t *= BEATS_IN_SONG // 0 -> BEATS_IN_SONG
			currentBeat = int(math.floor(t))
			if currentBeat != lastFrameBeat {
				_, ok := gameState.rhytms[currentBeat]
				if ok {
					rhtym_event()
				}
			}

			lastFrameBeat = currentBeat
		}

		// Update stuff
		{
			remove_dead_projectiles()
			update_player()
			update_projectiles()
			update_invaders()
		}

		// Draw stuff
		{
			rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.DrawText("Invaders left: -", 0, 0, 20, rl.WHITE)
			draw_player()
			draw_projectiles()
			draw_invaders()

			rl.EndDrawing()
		}
	}
}
