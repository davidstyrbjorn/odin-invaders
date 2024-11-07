package main

import rl "vendor:raylib"

INVADER_SIZE :: rl.Vector2{32, 32}
INVADER_CAPACITY :: 32 // Max amount of invader groups

invader1_texture: rl.Texture2D
invader_group: InvaderGroup

// A small assortment of invaders that together follow a predermined path
GroupSpeed :: f32(0.5)
InvaderGroup :: struct {
	invaders:        [4]bool,
	position:        rl.Vector2,
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

setup_invaders :: proc() {
	invader1_texture = rl.LoadTexture("../assets/invader1.png")

	// Create a group of invaders
	invader_group = InvaderGroup{}
	invader_group.position = rl.Vector2{0, 0}
	invader_group.time = 0
	invader_group.brassier_handle = 0
	for i := 0; i < 4; i += 1 {
		invader_group.invaders[i] = true
	}
}

draw_invaders :: proc() {

}

update_invaders :: proc() {
}
