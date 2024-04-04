package main

import rl "vendor:raylib"

EmitterDefinition :: struct {
	origin:    rl.Vector2,
	type:      enum u8 {
		InvaderDead,
		PlayerShoot,
	},
	emitCount: u32, // amount of particles to emit per second
}

Particle :: struct {
	pos: rl.Vector2,
}

Emitter :: struct {
	using _:    EmitterDefinition,
	isEmitting: bool,
	particles:  [dynamic]Particle,
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
			particles = [dynamic]Particle{},
		},
	)
}

PS_update :: proc() {
	for i := 0; i < len(PS.emitters); i += 1 {
		PS_update_emitter(&PS.emitters[i])
	}
}

PS_update_emitter :: proc(emitter: ^Emitter) -> bool {
	for particle in emitter.particles {

	}

	return false
}
