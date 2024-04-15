package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

CB_init_particle_velocity :: proc() -> rl.Vector2

PS_default_cb_init_particle_velocity :: proc() -> rl.Vector2 {
	angle := rand.float32() * rl.PI * 2
	vel := rl.Vector2{1, 0}
	vel = rl.Vector2Rotate(vel, angle)
	magnitude := 50 + rand.float32() * 100
	return rl.Vector2{vel[0] * magnitude, vel[1] * magnitude}
}

EmitterDefinition :: struct {
	origin:               rl.Vector2,
	type:                 Type,
	force:                rl.Vector2,
	emitRate:             f64, // time between each emission (seconds)
	emitCount:            u32, // how many particles to emit each time
	particleDuration:     u8, // life of a particle emitted (seconds)
	initVelocityCallback: CB_init_particle_velocity,
}

Particle :: struct {
	position:   rl.Vector2,
	velocity:   rl.Vector2,
	deathstamp: f64,
	birthstamp: f64,
	active:     bool,
}

Range :: struct($Type: typeid) {
	min: Type,
	max: Type,
}

PARTICLE_CAPACITY :: 2048

PlayerType :: struct {
	player: ^rl.Vector2,
}
ProjectileType :: struct {
	projectile: ^rl.Vector2,
}
Type :: union {
	PlayerType,
	ProjectileType,
}

Emitter :: struct {
	using _:       EmitterDefinition,
	particles:     #soa[PARTICLE_CAPACITY]Particle,
	deathstamp:    f64,
	emissionstamp: f64,
	kill:          bool,
}

// Master of all Particles and their Emitters
ParticleSystem :: struct {
	emitters: [dynamic]Emitter,
	rand:     rand.Rand,
}

PS := ParticleSystem{}

PS_init :: proc() {
	PS.emitters = [dynamic]Emitter{}
	t := time.now()
	PS.rand = rand.create(u64(time.to_unix_seconds(t)))
}

PS_destruct :: proc() {
	clear(&PS.emitters)
}

PS_create_emitter :: proc(def: EmitterDefinition) -> ^Emitter {
	new_emitter := Emitter {
		origin               = def.origin,
		type                 = def.type,
		emitCount            = def.emitCount,
		emitRate             = def.emitRate,
		particleDuration     = def.particleDuration,
		initVelocityCallback = PS_default_cb_init_particle_velocity,
		particles            = #soa[PARTICLE_CAPACITY]Particle{},
		deathstamp           = rl.GetTime() + 5, // TODO: All emitters shouldn't have a 5 seconds default alive time
		emissionstamp        = 0, // immediate emission upon creation
		kill                 = false,
	}

	append(&PS.emitters, new_emitter)
	emitter := &PS.emitters[len(PS.emitters) - 1]

	// Init particles iteratively
	for i := 0; i < PARTICLE_CAPACITY; i += 1 {
		emitter.particles.position[i] = rl.Vector2{0, 0}
		emitter.particles.velocity[i] = rl.Vector2{0, 0}
		emitter.particles.deathstamp[i] = f64(-1)
		emitter.particles.active[i] = false
		emitter.particles.birthstamp[i] = f64(-1)
	}

	return emitter
}

PS_update :: proc() {
	dead_emitter := -1
	for i := 0; i < len(PS.emitters); i += 1 {
		if PS_update_emitter(&PS.emitters[i]) == true { 				
			dead_emitter = i
		}
	}

	if dead_emitter != -1 {
		ordered_remove(&PS.emitters, dead_emitter)
	}
}

PS_draw :: proc() {
	for i := 0; i < len(PS.emitters); i += 1 {
		PS_draw_emitter(&PS.emitters[i])
	}
}

PS_draw_emitter :: proc(emitter: ^Emitter) {
	for i := 0; i < PARTICLE_CAPACITY; i += 1 {
		if !emitter.particles.active[i] {continue}
		PS_draw_particle(emitter, i)
	}
}

PS_draw_particle :: proc(emitter: ^Emitter, slot: int) {
	position := emitter.particles.position[slot]
	current := rl.GetTime()
	start := emitter.particles.birthstamp[slot]
	end := emitter.particles.deathstamp[slot]
	t := 1 - min((current - start) / (end - start), 1.0)
	color := rl.ColorAlpha(rl.GREEN, f32(t))
	rl.DrawCircle(i32(position[0]), i32(position[1]), 2, color)
}

PS_emit :: proc(emitter: ^Emitter, slot: int) {
	emitter.particles.position[slot] = emitter.origin
	emitter.particles.velocity[slot] = emitter.initVelocityCallback()
	emitter.particles.birthstamp[slot] = rl.GetTime()
	emitter.particles.deathstamp[slot] = rl.GetTime() + f64(emitter.particleDuration)
	emitter.particles.active[slot] = true
}

print_vec2 :: proc(vec2 : rl.Vector2) {
	fmt.printf("x: %1.f, y: %.1f\n", vec2[0], vec2[1]);
}

PS_update_emitter :: proc(emitter: ^Emitter) -> bool {
	time := rl.GetTime()

	// Different type of emitters might have origin
	type: Type = emitter.type
	switch v in type {
		case PlayerType:
			emitter.origin[0] = v.player[0]
			emitter.origin[1] = v.player[1]
		case ProjectileType:
			emitter.origin[0] = v.projectile[0]
			emitter.origin[1] = v.projectile[1]
	}

	// Emit particles?
	if time > emitter.emissionstamp {
		emitter.emissionstamp = time + emitter.emitRate
		slots := PS_find_available_particle_slots(&emitter.particles.active, emitter.emitCount)
		for i := 0; i < len(slots); i += 1 {
			PS_emit(emitter, slots[i])
		}
	}

	// Update all projectiles
	for i := 0; i < len(emitter.particles); i += 1 {
		emitter.particles.active[i] = !PS_update_particle(emitter, i)
	}

	fmt.println(emitter.kill)
	
	return time > emitter.deathstamp || emitter.kill
}

PS_update_particle :: proc(emitter: ^Emitter, particle_i: int) -> bool {
	// Euler integration of the position
	force := emitter.force
	mass := f32(1)
	dt := rl.GetFrameTime()
	acceleration := Scale_Vector2(force, mass)
	emitter.particles.velocity[particle_i] += acceleration * dt
	emitter.particles.position[particle_i] += emitter.particles.velocity[particle_i] * dt
	return rl.GetTime() > emitter.particles.deathstamp[particle_i]
}

Scale_Vector2 :: proc(vec: rl.Vector2, scalar: f32) -> rl.Vector2 {
	return rl.Vector2{vec[0] * scalar, vec[1] * scalar}
}

PS_find_available_particle_slots :: proc(
	particles: ^[PARTICLE_CAPACITY]bool,
	howMany: u32 = 1,
) -> [dynamic]int {
	slots := [dynamic]int{}
	for i := 0; i < PARTICLE_CAPACITY; i += 1 {
		if particles[i] {continue}
		append(&slots, i)
		if len(slots) == int(howMany) {
			break
		}
	}

	return slots
}
