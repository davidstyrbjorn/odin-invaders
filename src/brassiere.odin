package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

// P = (1−t)^3 * P1 + 3(1−t)^2*t*P2 +3(1−t)t^2 * P3 + t^3*P4
// keep positions 0 to 1
// DEBUG
control_points := [4]rl.Vector2 {
	rl.Vector2{100, 100},
	rl.Vector2{200, 100},
	rl.Vector2{300, 100},
	rl.Vector2{400, 100},
}
t := f32(0)

brassiere_4 :: proc(
	t: f32,
	p1: rl.Vector2,
	p2: rl.Vector2,
	p3: rl.Vector2,
	p4: rl.Vector2,
) -> rl.Vector2 {
	assert(t >= 0 && t <= 1)
	// assert(p1[0] >= 0 && p1[0] <= 1)
	// assert(p1[1] >= 0 && p1[1] <= 1)
	// assert(p2[0] >= 0 && p2[0] <= 1)
	// assert(p2[1] >= 0 && p2[1] <= 1)
	// assert(p3[0] >= 0 && p3[0] <= 1)
	// assert(p3[1] >= 0 && p3[1] <= 1)
	// assert(p4[0] >= 0 && p4[0] <= 1)
	// assert(p4[1] >= 0 && p4[1] <= 1)

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

// brassiere_test :: proc() {
// 	// Oscillate t from 0 to 1
// 	speed := f32(0.5)
// 	t = (math.sin_f32(cast(f32)rl.GetTime() * speed) + 1) / 2
// 	// curr is normalized, scale it to be inside play_area
// 	curr := brassiere_4(t, p1, p2, p3, p4)
// 	curr[0] = play_area.x + curr[0] * play_area.width
// 	curr[1] = play_area.y + curr[1] * play_area.height
// 	rl.DrawCircleV(curr, 5, rl.RED)
// }

// Editor tooling
current_point: int = -1

brassiere_on_click :: proc(mouse_pos: rl.Vector2) {
	// Find the closest of the 4 points to our mouse
	closest := 0
	closest_dist := rl.Vector2Distance(control_points[closest], mouse_pos)
	for i := 1; i < 4; i += 1 {
		dist := rl.Vector2Distance(control_points[i], mouse_pos)
		if dist < closest_dist {
			closest = i
			closest_dist = dist
		}
	}

	fmt.printf("closest_dist: %f\n", closest_dist)

	// Select the point if it is within reasonable distance
	closest_dist_threshold_pixels :: f32(10)
	if closest_dist < closest_dist_threshold_pixels {
		current_point = closest
		fmt.printf("Selected point: %v\n", current_point)
	}
}

brassiere_on_release :: proc() {
	current_point = -1
}

brassiere_on_update :: proc(mouse_pos: rl.Vector2, window_size: rl.Vector2) {
	if current_point == -1 {
		return
	}

	// Move the point to the mouse
	control_points[current_point][0] = mouse_pos[0]
	control_points[current_point][1] = mouse_pos[1]

	fmt.printf("current_point: %v\n", current_point)

	// Clamp to the relative space
	// current_point[0] = math.clamp(current_point[0], 0, 1)
	// current_point[1] = math.clamp(current_point[1], 0, 1)

}

brassiere_draw :: proc() {
	for i := 0; i < 4; i += 1 {
		rl.DrawCircleV(control_points[i], 5, rl.ORANGE)

		// Draw some text 
		str := fmt.tprintfln("point_%d", i)
		cstr := strings.clone_to_cstring(str, context.temp_allocator)
		rl.DrawText(
			cstr,
			i32(control_points[i][0]) - 10,
			i32(control_points[i][1]) - 35,
			15,
			rl.WHITE,
		)
	}

	time := rl.GetTime()
	t := math.sin(time * 2) * 0.5 + 0.5 // 0 to 1
	// fmt.printf("t: %f\n", t)

	for i := 0; i < 100; i += 1 {
		t := f32(i) / 100
		fmt.printf("t: %f\n", t)
		p := brassiere_4(
			t,
			control_points[0],
			control_points[1],
			control_points[2],
			control_points[3],
		)
		rl.DrawCircleV(p, 2, rl.RED)
	}
}
