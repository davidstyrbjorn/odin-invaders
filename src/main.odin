package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

player_particle_init_particle_velocity :: proc() -> rl.Vector2 {
	angle := rand.float32() * rl.PI
	vel := rl.Vector2{-1, 0}
	vel = rl.Vector2Rotate(vel, angle)
	magnitude := 80 + rand.float32() * 10
	return rl.Vector2{vel[0] * magnitude, vel[1] * magnitude * 0}
}

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
	position:         rl.Vector2,
	timealive:        f32,
	source:           EntityType,
	alive:            bool,
	attached_emitter: int,
}

// 48x48 sized player
PLAYER_SIZE :: rl.Vector2{48, 48}
PLAYER_Y :: WINDOW_HEIGHT - PLAYER_SIZE.y * 2
PLAYER_SPEED :: 200

PLAYER_COLOR :: rl.GREEN
INVADER_COLOR :: rl.RED

BEATS_IN_SONG :: 8

PROJECTILE_CAPACITY :: 256

GameState :: struct {
	player_position:              rl.Vector2,
	projectiles:                  #soa[PROJECTILE_CAPACITY]Projectile,
	invader_dead:                 [INVADER_CAPACITY]bool,
	invader_x:                    [INVADER_CAPACITY]f32,
	invader_y:                    [INVADER_CAPACITY]f32,
	invader_direction:            i8,
	invader_groups:               #soa[INVADER_CAPACITY]InvaderGroup,
	bpm:                          u8,
	rhytms:                       map[int]struct {},
	camera:                       rl.Camera2D,
	camera_shake_time_seconds:    f32,
	camera_shake_strength_pixels: f32,
}

gameState := GameState{}

init_game :: proc() {
	t := time.now()
	rand.create(u64(time.to_unix_seconds(t)))

	gameState.player_position = rl.Vector2(0)
	gameState.player_position.x = WINDOW_WIDTH / 2 - PLAYER_SIZE.x / 2
	gameState.player_position.y = PLAYER_Y

	for i := 0; i < PROJECTILE_CAPACITY; i += 1 {
		gameState.projectiles[i] = Projectile{rl.Vector2{0, 0}, f32(0), .Player, false, -1}
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

	gameState.camera = rl.Camera2D {
		offset   = rl.Vector2{0, 0},
		target   = rl.Vector2{0, 0},
		rotation = 0,
		zoom     = 1,
	}
	gameState.camera_shake_time_seconds = 0
	gameState.camera_shake_strength_pixels = 10
}

find_available_projectile_index :: proc() -> int {
	for i := 0; i < PROJECTILE_CAPACITY; i += 1 {
		if !gameState.projectiles.alive[i] {
			return i
		}
	}

	return -1
}

create_projectile_player :: proc() -> Projectile {
	x := gameState.player_position.x + PLAYER_SIZE.x / 2
	y := gameState.player_position.y
	return Projectile{rl.Vector2{x, y}, f32(0), .Player, true, -1}
}

create_projectile_invader :: proc(x: f32, y: f32) -> Projectile {
	return Projectile{rl.Vector2{x, y}, f32(0), .Invader, true, -1}
}

draw_player :: proc() {
	rl.DrawRectangleV(gameState.player_position, PLAYER_SIZE, PLAYER_COLOR)
}

draw_projectiles :: proc() {
	for i := uint(0); i < len(gameState.projectiles); i += 1 {
		pj := gameState.projectiles[i]
		if !pj.alive {continue}
		rl.DrawRectangle(
			i32(pj.position.x),
			i32(pj.position.y),
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
		index := find_available_projectile_index()
		gameState.projectiles[index] = create_projectile_player()
		test := EmitterDefinition {
			origin = rl.Vector2{0, 0},
			type = ProjectileType{projectile = &gameState.projectiles.position[index]},
			force = rl.Vector2{0, 200},
			emitRate = 0.05,
			emitCount = 1,
			particleDuration = 1,
		}
		test.initVelocityCallback = player_particle_init_particle_velocity

		emitter := PS_create_emitter(test)
		gameState.projectiles[index].attached_emitter = emitter
	}
}

update_projectiles :: proc() {
	dt := rl.GetFrameTime()
	projectiles := &gameState.projectiles
	for i := 0; i < len(gameState.projectiles); i += 1 {
		if !projectiles.alive[i] {continue}
		switch (projectiles.source[i]) {
		case .Player:
			projectiles.position[i].y -= PROJECTILE_SPEED_PLAYER * dt
			break
		case .Invader:
			projectiles.position[i].y += PROJECTILE_SPEED_INVADER * dt
			break
		}

		projectiles.timealive[i] += dt
		if projectiles.timealive[i] > 5 {
			projectiles.alive[i] = false
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

	{ /* SHOOT PROJECTILES FROM INVADERS */
		for i := 0; i < INVADER_CAPACITY; i += 1 {
			index_to_below := i + INVADERS_PER_LINE
			if index_to_below >= INVADER_CAPACITY {
				continue
			}

			if !gameState.invader_dead[i] &&
			   (index_to_below >= INVADER_CAPACITY || gameState.invader_dead[index_to_below]) {
				r := (f32)(rand.uint32()) / 4_294_967_295
				if r > 0.5 { 	// 50% chance of shooting
					x := gameState.invader_x[i] + (INVADER_SIZE[0] / 2)
					y := gameState.invader_y[i] + (INVADER_SIZE[1] / 2)
					gameState.projectiles[find_available_projectile_index()] =
						create_projectile_invader(x, y)
				}
			}

			// if r > 0.9 {
			// 	x := gameState.invader_x[i] + (INVADER_SIZE[0] / 2)
			// 	y := gameState.invader_y[i] + (INVADER_SIZE[1] / 2)
			// 	gameState.projectiles[find_available_projectile_index()] =
			// 		create_projectile_invader(x, y)
			// }
		}
	}
}

update_camera :: proc() {
	if gameState.camera_shake_time_seconds > 0 {
		offset_x := (f32)(rand.uint32()) / 4_294_967_295
		offset_y := (f32)(rand.uint32()) / 4_294_967_295
		gameState.camera.offset = rl.Vector2 {
			offset_x * gameState.camera_shake_strength_pixels,
			offset_y * gameState.camera_shake_strength_pixels,
		}
		gameState.camera_shake_time_seconds -= rl.GetFrameTime()
	} else {
		gameState.camera.offset = rl.Vector2{0, 0}
	}

}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin Invaders")
	rl.SetTargetFPS(144)

	// Init particle system
	PS_init()
	defer PS_destruct()

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

	/*
	test := EmitterDefinition {
		origin = rl.Vector2{WINDOW_WIDTH/2.0, WINDOW_HEIGHT/2.0},
		type = ProjectileType {
			
		},
		force = rl.Vector2{0, 0},
		emitRate = 2,
		emitCount = 1,
		particleDuration = 1,
	}
	PS_create_emitter(test)
	*/

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
			// update_invaders()
			update_camera()

			// brassiere_test()

			PS_update()
		}

		// Tooling 
		{
			mouse_pos := rl.GetMousePosition()
			brassiere_on_update(mouse_pos, rl.Vector2{WINDOW_WIDTH, WINDOW_HEIGHT})
			if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
				brassiere_on_click(mouse_pos)
			}
			if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
				brassiere_on_release()
			}
		}

		// Draw stuff
		{
			rl.BeginDrawing()
			rl.ClearBackground(rl.BLACK)
			rl.BeginMode2D(gameState.camera)

			draw_player()
			draw_projectiles()
			// draw_invaders()
			PS_draw()

			brassiere_draw()

			rl.EndMode2D()

			rl.DrawText("Invaders left: -", 0, 0, 20, rl.WHITE)
			rl.EndDrawing()
		}

		free_all(context.temp_allocator)
	}

}
