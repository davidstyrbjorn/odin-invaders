package main

find_available_group_index :: proc() -> int {
	for i := 0; i < INVADER_CAPACITY; i += 1 {
		if !gameState.invader_dead[i] {
			return i
		}
	}

	return -1
}
