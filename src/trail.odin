package main

import rl "vendor:raylib"

LineSegment :: struct {
	position:            rl.Vector2,
	time_to_next_update: f32,
}

Trail :: struct {
	segments:      []LineSegment,
	segment_count: int,
	tracking:      ^rl.Vector2,
	lifetime:      f32,
	offset:        rl.Vector2,
}

create_trail :: proc(segment_count: int, tracking: ^rl.Vector2, offset: rl.Vector2) -> Trail {
	lifetime :: f32(0.05)
	trail := Trail{make([]LineSegment, segment_count), segment_count, tracking, lifetime, offset}
	for i := 0; i < segment_count; i += 1 {
		trail.segments[i] = LineSegment{tracking^, lifetime * f32(i)}
	}

	return trail
}

free_trail :: proc(trail: Trail) {
	delete(trail.segments)
}

update_trail :: proc(trail: ^Trail) {
	dt := rl.GetFrameTime()
	for i := 0; i < trail.segment_count; i += 1 {
		trail.segments[i].time_to_next_update -= dt
		if trail.segments[i].time_to_next_update <= 0 {
			update_vertex_position(trail, i)
			trail.segments[i].time_to_next_update = trail.lifetime
		}
	}
}

update_vertex_position :: proc(trail: ^Trail, index: int) {
	new_pos := trail.tracking^ // Default to tracking position
	if index != 0 {
		new_pos = trail.segments[index - 1].position // If not first, set to previous position
	}

	curr_pos := trail.segments[index].position
	trail.segments[index].position = new_pos
}

draw_trail :: proc(trail: Trail) {
	for i := 0; i < trail.segment_count - 1; i += 1 {
		start := trail.segments[i].position + trail.offset
		end := trail.segments[i + 1].position + trail.offset
		t := f32(i) / f32(trail.segment_count)
		rl.DrawLineEx(start, end, 30 * (1 - t), rl.Fade(rl.GRAY, 1 - t))
	}
}
