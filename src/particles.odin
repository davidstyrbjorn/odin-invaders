package main

import rl "vendor:raylib"

EmitterDefinition :: struct {
	origin:    rl.Vector2,
	type:      enum u8 {
		InvaderDead,
		PlayerShoot,
	},
	emitCount: u32, // amount of particles to emit per second
	force: rl.Vector2,
}

Particle :: struct {
	pos:        rl.Vector2,
	deathstamp: f64,
	active:     bool,
}

Range :: struct($Type: typeid) {
	min: Type,
	max: Type,
}

PARTICLE_CAPACITY :: 256

Emitter :: struct {
	using _:    EmitterDefinition,
	isEmitting: bool,
	particles:  [PARTICLE_CAPACITY]Particle,
	duration:   Range(f32),
	deathstamp: f64,
}

// Master of all Particles and their Emitters
ParticleSystem :: struct {
	emitters: [dynamic]Emitter,
}

PS := ParticleSystem{}

PS_create_emitter :: proc(def: EmitterDefinition) {
	append(
		&PS.emitters,
		Emitter {
			origin = def.origin,
			type = def.type,
			emitCount = def.emitCount,
			isEmitting = false,
			particles = [PARTICLE_CAPACITY]Particle{},
		},
	)
}

PS_update :: proc() {
	for i := 0; i < len(PS.emitters); i += 1 {
		PS_update_emitter(&PS.emitters[i])
	}
}

PS_update_emitter :: proc(emitter: ^Emitter) -> bool {
	time := rl.GetTime()
	for i := 0; i < len(emitter.particles); i += 1 {
		p := &emitter.particles[i]
		if time > p.deathstamp {
			p.active = false
			continue
		} else {
			
		}
	}
	return time > emitter.deathstamp
}
