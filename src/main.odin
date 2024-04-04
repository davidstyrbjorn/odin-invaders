package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 900

PROJECTILE_WIDTH: f32 : 2.0
PROJECTILE_HEIGHT: f32 : 16.0
PROJECTILE_SPEED_PLAYER :: 600
PROJECTILE_SPEED_INVADER :: 450

EntityType :: enum u8 {
	Player  = 0,
	Invader = 1,
}
EntityColors := []rl.Color{rl.GREEN, rl.RED}

Projectile :: struct {
	x:         f32,
	y:         f32,
	timealive: f32,
	source:    EntityType,
	alive:     bool,
}

INVADERS_PER_LINE :: 5
INVADER_LINES :: 8
INVADER_CAPACITY :: INVADER_LINES * INVADERS_PER_LINE
INVADER_SIZE :: rl.Vector2{32, 32}
INVADER_PADDING :: f32(16)

// 48x48 sized player
PLAYER_SIZE :: rl.Vector2{48, 48}
PLAYER_Y :: WINDOW_HEIGHT - PLAYER_SIZE.y * 2
PLAYER_SPEED :: 200

PLAYER_COLOR :: rl.GREEN
INVADER_COLOR :: rl.RED

BEATS_IN_SONG :: 8

PROJECTILE_CAPACITY :: 256

GameState :: struct {
	rand:              rand.Rand,
	player_position:   rl.Vector2,
	projectiles:       [PROJECTILE_CAPACITY]Projectile,
	invader_dead:      [INVADER_CAPACITY]bool,
	invader_x:         [INVADER_CAPACITY]f32,
	invader_y:         [INVADER_CAPACITY]f32,
	invader_direction: i8,
	bpm:               u8,
	rhytms:            map[int]struct {},
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
	t := time.now()
	gameState.rand = rand.create(u64(time.to_unix_seconds(t)))

	gameState.player_position = rl.Vector2(0)
	gameState.player_position.x = WINDOW_WIDTH / 2 - PLAYER_SIZE.x / 2
	gameState.player_position.y = PLAYER_Y

	for i := 0; i < PROJECTILE_CAPACITY; i += 1 {
		gameState.projectiles[i] = create_projectile_dead()
	}

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

find_available_projectile_index :: proc() -> int {
	for i := 0; i < PROJECTILE_CAPACITY; i += 1 {
		if !gameState.projectiles[i].alive {
			return i
		}
	}

	return -1
}

create_projectile_player :: proc() -> Projectile {
	x := gameState.player_position.x + PLAYER_SIZE.x / 2
	y := gameState.player_position.y
	return Projectile{x, y, f32(0), .Player, true}
}

create_projectile_invader :: proc(x: f32, y: f32) -> Projectile {
	return Projectile{x, y, f32(0), .Invader, true}
}

create_projectile_dead :: proc() -> Projectile {
	return Projectile{f32(0), f32(0), f32(0), .Player, false}

}

draw_player :: proc() {
	rl.DrawRectangleV(gameState.player_position, PLAYER_SIZE, PLAYER_COLOR)
}

draw_projectiles :: proc() {
	for i := uint(0); i < len(gameState.projectiles); i += 1 {
		pj := gameState.projectiles[i]
		if !pj.alive {continue}
		rl.DrawRectangle(
			i32(pj.x),
			i32(pj.y),
			i32(PROJECTILE_WIDTH),
			i32(PROJECTILE_HEIGHT),
			EntityColors[u8(pj.source)],
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
		gameState.projectiles[find_available_projectile_index()] = create_projectile_player()
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

		for pjl, j in gameState.projectiles {
			if pjl.source != .Player || !pjl.alive {continue}
			projectile_rec := rl.Rectangle{pjl.x, pjl.y, PROJECTILE_WIDTH, PROJECTILE_HEIGHT}
			invader_rec := rl.Rectangle {
				gameState.invader_x[i],
				gameState.invader_y[i],
				INVADER_SIZE.x,
				INVADER_SIZE.y,
			}
			if rl.CheckCollisionRecs(projectile_rec, invader_rec) {
				// Feedback
				// TODO: Camera shake
				// TODO: Particles
				create_emitter({x, y, .Invader})

				// Unalive them
				gameState.invader_dead[i] = true
				gameState.projectiles[j].alive = false
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
	for i := 0; i < len(gameState.projectiles); i += 1 {
		pj := &gameState.projectiles[i]
		if !pj.alive {continue}
		switch (pj.source) {
		case .Player:
			pj.y -= PROJECTILE_SPEED_PLAYER * dt
			break
		case .Invader:
			pj.y += PROJECTILE_SPEED_INVADER * dt
			break
		}

		pj.timealive += dt
		if pj.timealive > 5 {
			gameState.projectiles[i].alive = false
		}
	}
}

rhytm_event :: proc() {
	{ /* MOVE THE INVADERS */
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

	// Important to do this after moving the invaders, since this will make sure the shot is coming from the correct position
	{ /* SHOOT PROJECTILES FROM INVADERS */
		for i := 0; i < INVADER_CAPACITY; i += 1 {
			r := (f32)(rand.uint32(&gameState.rand)) / 4_294_967_295
			if r > 0.9 {
				x := gameState.invader_x[i] + (INVADER_SIZE[0] / 2)
				y := gameState.invader_y[i] + (INVADER_SIZE[1] / 2)
				gameState.projectiles[find_available_projectile_index()] =
					create_projectile_invader(x, y)
			}
		}
	}
}

foo :: proc(x: u32) -> u32 {
	return x + 1
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
					rhytm_event()
				}
			}

			lastFrameBeat = currentBeat
		}

		// Update stuff
		{
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
