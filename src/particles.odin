package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

CB_init_particle_velocity :: proc() -> rl.Vector2

PS_default_cb_init_particle_velocity :: proc() -> rl.Vector2 {
	x := (rand.float32() * 2) - 1
	y := (rand.float32() * 2) - 1
	return rl.Vector2{x*100, y*100}
}

EmitterDefinition :: struct {
	origin:               rl.Vector2,
	type:                 enum u8 {
		InvaderDead,
		PlayerShoot,
	},
	force:                rl.Vector2,
	emitRate:             u8, // time between each emission (seconds)
	emitCount:            u32, // how many particles to emit each time
	particleDuration:     u8, // life of a particle emitted (seconds)
	initVelocityCallback: CB_init_particle_velocity,
}

Particle :: struct {
	position:   rl.Vector2,
	velocity:   rl.Vector2,
	deathstamp: f64,
	active:     bool,
}

Range :: struct($Type: typeid) {
	min: Type,
	max: Type,
}

PARTICLE_CAPACITY :: 2048

Emitter :: struct {
	using _:       EmitterDefinition,
	particles:     #soa[PARTICLE_CAPACITY]Particle,
	deathstamp:    f64,
	emissionstamp: f64,
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

PS_create_emitter :: proc(def: EmitterDefinition) {
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
	}

	append(&PS.emitters, new_emitter)
	emitter := &PS.emitters[len(PS.emitters) - 1]

	// Init particles iteratively
	for i := 0; i < PARTICLE_CAPACITY; i += 1 {
		emitter.particles.position[i] = rl.Vector2{0, 0}
		emitter.particles.velocity[i] = rl.Vector2{0, 0}
		emitter.particles.deathstamp[i] = f64(-1)
		emitter.particles.active[i] = false
	}
}

PS_update :: proc() {
	dead_emitters := [dynamic]int{}
	for i := 0; i < len(PS.emitters); i += 1 {
		if PS_update_emitter(&PS.emitters[i]) == true { 	// dead emitter?
			append(&dead_emitters, i)
		}
	}

	for idx in dead_emitters {
		fmt.println("removing emitter")
		ordered_remove(&PS.emitters, idx)
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
	// TODO: check range before casting since we're casting down (range)
	rl.DrawCircle(i32(position[0]), i32(position[1]), 2, rl.PURPLE)
}

PS_emit :: proc(emitter: ^Emitter, slot: int) {
	emitter.particles.position[slot] = emitter.origin
	emitter.particles.velocity[slot] = emitter.initVelocityCallback()
	emitter.particles.deathstamp[slot] = rl.GetTime() + f64(emitter.particleDuration)
	emitter.particles.active[slot] = true
}

PS_update_emitter :: proc(emitter: ^Emitter) -> bool {
	time := rl.GetTime()

	if time > emitter.emissionstamp {
		fmt.println("Emitting particles...")
		emitter.emissionstamp = time + f64(emitter.emitRate)
		slots := PS_find_available_particle_slots(&emitter.particles.active, emitter.emitCount)
		for i := 0; i < len(slots); i += 1 {
			PS_emit(emitter, slots[i])
		}
	}

	for i := 0; i < len(emitter.particles); i += 1 {
		emitter.particles.active[i] = !PS_update_particle(emitter, i)

	}
	return time > emitter.deathstamp
}

PS_update_particle :: proc(emitter: ^Emitter, particle_i: int) -> bool {

	// Euler integration of the position
	force := rl.Vector2{0, 0}
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

		}
	}

	return slots
}
