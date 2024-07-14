package main

import rl "vendor:raylib"

INVADER_SIZE :: rl.Vector2{32, 32}
INVADER_CAPACITY :: 32 // Max amount of invader groups

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

setup_invaders :: proc() {

}

draw_invaders :: proc() {

}

update_invaders :: proc() {
}
