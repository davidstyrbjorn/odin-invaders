package main

import "core:math"
import rl "vendor:raylib"

// P = (1−t)^3 * P1 + 3(1−t)^2*t*P2 +3(1−t)t^2 * P3 + t^3*P4
// keep positions 0 to 1
// DEBUG
p1 := rl.Vector2{0, 0.2}
p2 := rl.Vector2{1, 1}
p3 := rl.Vector2{1, 0}
p4 := rl.Vector2{1, 0.8}
t := f32(0)

brassiere_4 :: proc(
	t: f32,
	p1: rl.Vector2,
	p2: rl.Vector2,
	p3: rl.Vector2,
	p4: rl.Vector2,
) -> rl.Vector2 {
	assert(t >= 0 && t <= 1)
	assert(p1[0] >= 0 && p1[0] <= 1)
	assert(p1[1] >= 0 && p1[1] <= 1)
	assert(p2[0] >= 0 && p2[0] <= 1)
	assert(p2[1] >= 0 && p2[1] <= 1)
	assert(p3[0] >= 0 && p3[0] <= 1)
	assert(p3[1] >= 0 && p3[1] <= 1)
	assert(p4[0] >= 0 && p4[0] <= 1)
	assert(p4[1] >= 0 && p4[1] <= 1)

	return rl.Vector2 {
		math.pow_f32(1 - t, 3) * p1[0] +
		3 * math.pow_f32((1 - t), 2) * t * p2[0] +
		3 * (1 - t) * t * t * p3[0] +
		t * t * t * p4[0],
		math.pow_f32(1 - t, 3) * p1[1] +
		3 * math.pow_f32((1 - t), 2) * t * p2[1] +
		3 * (1 - t) * t * t * p3[1] +
		t * t * t * p4[1],
	}
}

brassiere_test :: proc() {
	// Oscillate t from 0 to 1
	speed := f32(0.5)
	t = (math.sin_f32(cast(f32)rl.GetTime() * speed) + 1) / 2
	// curr is normalized, scale it to be inside play_area
	curr := brassiere_4(t, p1, p2, p3, p4)
	curr[0] = play_area.x + curr[0] * play_area.width
	curr[1] = play_area.y + curr[1] * play_area.height
	rl.DrawCircleV(curr, 5, rl.RED)
}

// Editor tooling
current_point: ^rl.Vector2 = nil

brassiere_on_click :: proc(mouse_pos: rl.Vector2) {
	// Find the closest of the 4 points to our mouse
	points := [4]rl.Vector2{p1, p2, p3, p4}
	closest := points[0]
	closest_dist := math.distance(closest, mouse_pos)
	for i in 1 .. 4 {
		dist := math.distance(points[i], mouse_pos)
		if dist < closest_dist {
			closest = points[i]
			closest_dist = dist
		}
	}

	// Select the point if it is within reasonable distance
	closest_dist_threshold_pixels :: f32(50)
	if closest_dist < closest_dist_threshold_pixels {
		current_point = &closest
	}
}

brassiere_on_release :: proc() {
	if current_point != nil {
		current_point = nil
	}
}

brassiere_on_update :: proc(mouse_pos: rl.Vector2, window_size: rl.Vector2) {
	if current_point == nil {
		return
	}

	// Move the point to the mouse
	current_point[0] = mouse_pos[0]
	current_point[1] = mouse_pos[1]

	// Relative inside window

	// Clamp to the relative space
	current_point[0] = math.clamp_f32(current_point[0], 0, 1)
	current_point[1] = math.clamp_f32(current_point[1], 0, 1)

}

brassiere_draw :: proc() {
	rl.DrawCircleV(p1, 5, rl.ORANGE)
	rl.DrawCircleV(p2, 5, rl.ORANGE)
	rl.DrawCircleV(p3, 5, rl.ORANGE)
	rl.DrawCircleV(p4, 5, rl.ORANGE)
}
