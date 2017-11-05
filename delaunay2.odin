import "core:fmt.odin";
import "core:os.odin";
import "core:mem.odin";
import "core:strings.odin";
import "core:math.odin";
import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";
import "shared:odin-gl_font/font.odin";
using import "shared:random.odin";

scroll_x := 0.0;
scroll_y := 0.0;

Node_t :: enum {
    Inside  = 0,
    Inlet   = 1,
    Outlet  = 2,
    Outside = 3,
};

Link_t :: enum {
    Inside  = 0,
    Inlet   = 1,
    Outlet  = 2,
    Outside = 3,
};

append_to_log :: proc(log: ^$T/[dynamic]string, fmt_string: string, vals: ...any) {
	a := fmt.aprintf(fmt_string, ...vals);
	append(log, a);
}
temp_log: [dynamic]string;

Lx, Ly, Lz: f64;
min_x, min_y, min_z := +1.0e9, +1.0e9, +1.0e9;
max_x, max_y, max_z := -1.0e9, -1.0e9, -1.0e9;

main :: proc() {
	scroll_callback :: proc(window: ^glfw.window, dx, dy: f64) #cc_c {
		scroll_x += dx;
		scroll_y += dy;
	}
	// setup glfw
	error_callback :: proc(error: i32, desc: ^u8) #cc_c {
		fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
	}
	glfw.SetErrorCallback(error_callback);

	if glfw.Init() == 0 do return;
	defer glfw.Terminate();

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5);
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

	resx, resy := 1000.0, 1000.0;
	window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Delaunay ", nil, nil);
	if window == nil do return;

	glfw.MakeContextCurrent(window);
	glfw.SwapInterval(1);
	glfw.SetScrollCallback(window, scroll_callback);

	// setup opengl
	set_proc_address :: proc(p: rawptr, name: string) { 
		(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
	}
	gl.load_up_to(4, 5, set_proc_address);


	if !font.init("extra/font_3x1.bin", "shaders/shader_font.vs", "shaders/shader_font.fs") do return;  

	// load shaders
	program, shader_success := gl.load_shaders("shaders/shader_delaunay.vs", "shaders/shader_delaunay.fs");
	defer gl.DeleteProgram(program);

	uniforms := gl.get_uniforms_from_program(program);
	defer for uniform, name in uniforms do free(uniform.name);

	for uniform, name in uniforms {
		fmt.println(name, uniform);
	}

	points, nodes, links := load_from_file("extra/stuff.bin");
	if points == nil {
		fmt.println("Could not read file");
		return;
	}


	for node in nodes {
		min_x, min_y, min_z = min(min_x, cast(f64)node.x), min(min_y, cast(f64)node.y), min(min_z, cast(f64)0.0);
		max_x, max_y, max_z = max(max_x, cast(f64)node.x), max(max_y, cast(f64)node.y), max(max_z, cast(f64)0.0);
	}
	Lx, Ly, Lz = (max_x - min_x), (max_y - min_y), (max_z - min_z);



	// uniform buffers
	vao: u32;
	gl.CreateVertexArrays(1, &vao);
	gl.BindVertexArray(vao);
	defer gl.DeleteVertexArrays(1, &vao);



	// init gl state
	gl.Disable(gl.DEPTH_TEST);
	gl.Enable(gl.BLEND);
	gl.BlendEquation(gl.FUNC_ADD);
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

	gl.ClearColor(1.0, 1.0, 1.0, 1.0);

	// input state
	last_mouse_click_x, last_mouse_click_y: f64;
	mouse_x_prev, mouse_y_prev: f64;
	glfw.GetCursorPos(window, &mouse_x_prev, &mouse_y_prev);

	scroll_x_prev, scroll_y_prev := scroll_x, scroll_y;
	mouse_button_prev: [5]i32;

	// camera state
	x : f32 = 400.0;
	y : f32 = 200.0;
	dy : f32 = 400.0;
	dx : f32 = dy*f32(resx/resy);

	x = f32(min_x);
	y = f32(min_y);

	dx, dy = cast(f32)max(max_x - min_x, max_y - min_y)*f32(resx)/f32(resy), cast(f32)max(max_x - min_x, max_y - min_y);


	F5_prev : i32 = 0;
	TAB_prev : i32 = 0;
	F_prev : i32 = 0;

	key_states: map[i32]i32;

	polled_keys := [...]i32 {
		glfw.KEY_W,
		glfw.KEY_A,
		glfw.KEY_S,
		glfw.KEY_D,
		glfw.KEY_F,
		glfw.KEY_Z,
		glfw.KEY_C,
		glfw.KEY_1,
		glfw.KEY_2,
		glfw.KEY_3,
		glfw.KEY_4,
		glfw.KEY_5,
		glfw.KEY_6,
		glfw.KEY_7,
		glfw.KEY_8,
		glfw.KEY_9,
		glfw.KEY_0,
		glfw.KEY_LEFT,
		glfw.KEY_RIGHT,
		glfw.KEY_SPACE,
		glfw.KEY_F5,
		glfw.KEY_TAB,
		glfw.KEY_ESCAPE,
		glfw.KEY_LEFT_CONTROL,
	};

	enable_vsync := true;
	glfw.SwapInterval(cast(i32)enable_vsync);


	num_points := len(points);
	num_nodes := len(nodes);
	num_links := len(links);



	links_dynamic := make([]Links_Dynamic, num_links);
	defer free(links_dynamic);	
	
	StateHeader :: struct #ordered {
	    network_checksum: u32,
	    state_checksum: u32,
	    num_links: i32,
	    max_bubbles: i32,
	    total_bubbles: i32,
	    flow_mode: i32,
	    size: i32,
	    timestep: i32,
	    delta_time: f64,
	    time: f64,
	    porevolume: f64,
	    pressure: f64,
	    total_flowrate: f64,
	}

	state_data, success_data := os.read_entire_file("state_3.bin");
	defer free(state_data);

	state_header := (cast(^StateHeader)&state_data[0])^;

	num_bubbles := mem.slice_ptr(cast(^i32)&state_data[size_of(StateHeader)+3*8*num_links], num_links);
	bubble_positions := mem.slice_ptr(cast(^f64)&state_data[size_of(StateHeader)+3*8*num_links+4*num_links], int(state_header.total_bubbles*2));

	ctr := 0;
	for i in 0..num_links {
		links_dynamic[i].num_bubbles = num_bubbles[i];
		for j in 0..num_bubbles[i] {
			links_dynamic[i].bubbles_start[j] = cast(f32)bubble_positions[ctr];
			links_dynamic[i].bubbles_stop[j] = cast(f32)bubble_positions[ctr+1];
			ctr += 2;
		}
	}




	buf_points, buf_links, buf_nodes, buf_links_dynamic: u32;
	gl.CreateBuffers(1, &buf_points);
	gl.CreateBuffers(1, &buf_nodes);
	gl.CreateBuffers(1, &buf_links);
	gl.CreateBuffers(1, &buf_links_dynamic);
	defer {
		gl.DeleteBuffers(1, &buf_points);
		gl.DeleteBuffers(1, &buf_nodes);
		gl.DeleteBuffers(1, &buf_links);
		gl.DeleteBuffers(1, &buf_links_dynamic);
	}

	draw_states := [10]bool{true, true, true, true, true, true, true, false, false, true};

	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, buf_points);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, buf_nodes);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, buf_links);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, buf_links_dynamic);

	gl.NamedBufferData(buf_points, size_of(Point)*num_points, &points[0], gl.STATIC_DRAW);
	gl.NamedBufferData(buf_nodes,  size_of(Node)*num_nodes,   &nodes[0],  gl.STATIC_DRAW);
	gl.NamedBufferData(buf_links,  size_of(Link)*num_links,   &links[0],  gl.STATIC_DRAW);
	gl.NamedBufferData(buf_links_dynamic,  size_of(Links_Dynamic)*num_links,   &links_dynamic[0],  gl.STATIC_DRAW);

	lengths := make([]f64, len(links));
	sorted_by_length := make([]int, len(links));

	for link, i in links {
		lengths[i] = cast(f64)math.mag(nodes[link.front].xy - nodes[link.back].xy);
		sorted_by_length[i] = i;
	}

	for i in 0..len(links)-1 {
		min_index := i;
		for j in i+1..len(links) {
			if lengths[j] < lengths[min_index] {
				min_index = j;
			}
		}

		lengths[i], lengths[min_index] = lengths[min_index], lengths[i];
		sorted_by_length[i], sorted_by_length[min_index] = sorted_by_length[min_index], sorted_by_length[i];

	}

	current_link := 0;

	t1 := glfw.GetTime();

	should_clear := true;
	theta := 0.0;


	max_viewport_dims, max_framebuffer_width, max_framebuffer_height: i32;
	gl.GetIntegerv(gl.MAX_VIEWPORT_DIMS, &max_viewport_dims);
	gl.GetIntegerv(gl.MAX_FRAMEBUFFER_WIDTH, &max_framebuffer_width);
	gl.GetIntegerv(gl.MAX_FRAMEBUFFER_HEIGHT, &max_framebuffer_height);
	fmt.println(max_viewport_dims, max_framebuffer_width, max_framebuffer_height);

	render_resx, render_resy: i32 = 8192/4, 8192/4;

	screen_texture: u32;
	gl.GenTextures(1, &screen_texture);
	gl.BindTexture(gl.TEXTURE_2D, screen_texture);

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, cast(i32)render_resx, cast(i32)render_resy, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);

	framebuffer: u32;
	gl.GenFramebuffers(1, &framebuffer);
	gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer);
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, screen_texture, 0);

	buffers := [1]u32{ gl.COLOR_ATTACHMENT0 };
	gl.DrawBuffers(1, &buffers[0]);


	status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER);
	if status != gl.FRAMEBUFFER_COMPLETE do fmt.printf("ERR framebuffers: %d\n", status); 
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0);

	// the quad spanned by the left, back, right and front vertices tesselate the whole system
	total_area := 0.0;
	for _, i in links {
		using link := links[i];
		// area triangle = abs(Ax*(By - Cy) + Bx*(Cy - Ay) + Cx*(Ay - By))/2;
		
		A := nodes[back].xy;
		B := nodes[front].xy;
		C := points[left].xy;
		D := points[right].xy;

		A1 := abs(A.x*(B.y - C.y) + B.x*(C.y - A.y) + C.x*(A.y - B.y))/2.0;
		A2 := abs(A.x*(B.y - D.y) + B.x*(D.y - A.y) + D.x*(A.y - B.y))/2.0;

		total_area += f64(A1 + A2);
	}

	cylinder_area := 0.0;
	for _, i in points {
		using point := points[i];
		cylinder_area += math.PI*f64(r*r);
	}

	pore_area := total_area - cylinder_area;



	// convert from pixel area to millimeters^2
	area_factor := (54.0/1000.0)*(54.0/1000.0);
	total_area *= area_factor;
	cylinder_area *= area_factor;
	pore_area *= area_factor;

	// multiply by height in millimeters to get volume
	total_volume := total_area * 0.1;
	cylinder_volume := cylinder_area * 0.1;
	pore_volume := pore_area * 0.1;

	// convert from mm^3 to mL
	volume_factor := 0.001;
	total_volume *= volume_factor;
	cylinder_volume *= volume_factor;
	pore_volume *= volume_factor;

	fmt.printf("total volume = %f, pore volume = %f, porosity = %f\n", total_volume, pore_volume, pore_volume/total_volume);



	for glfw.WindowShouldClose(window) == glfw.FALSE {
		for _, i in temp_log do free(temp_log[i]);
		clear(&temp_log);

		// show fps in window title
		glfw.calculate_frame_timings(window);
		
		// listen to inut
		glfw.PollEvents();

		t2 := glfw.GetTime();
		dt := t2 - t1;
		t1 = t2;

		// get input state
		mouse_x, mouse_y: f64;
		glfw.GetCursorPos(window, &mouse_x, &mouse_y);

		mouse_dx, mouse_dy := mouse_x - mouse_x_prev, mouse_y - mouse_y_prev;
		scroll_dx, scroll_dy := scroll_x - scroll_x_prev, scroll_y - scroll_y_prev;

		for key in polled_keys {
			key_states[key] = ((key_states[key] & 1) << 1) | (glfw.GetKey(window, key) << 0);
		}

		mouse_button: [5]i32;
		for i in 0..5 do mouse_button[i] = glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_1 + cast(i32)i);

		// handle input
		if mouse_button[0] == 1 {
			x -= f32(mouse_dx/resx*f64(dx));
			y += f32(mouse_dy/resy*f64(dy));
		}

		x += f32(0.3*f64(dx)*dt * f64((key_states[glfw.KEY_D]&1) - key_states[glfw.KEY_A]&1));
		y += f32(0.3*f64(dy)*dt * f64((key_states[glfw.KEY_W]&1) - key_states[glfw.KEY_S]&1));
		xend := f32(f64(x) + mouse_x*f64(dx)/resx);           // convert screen position to world cooridnates
		yend := f32(f64(y) + (resy - mouse_y)*f64(dy)/resy);   

		if key_states[glfw.KEY_LEFT_CONTROL]&1 != 1 {
			zoom_factor := cast(f32)math.pow(0.95, scroll_dy);

			x = (1.0-zoom_factor)*xend + zoom_factor*x;       // update lower left corner
			y = (1.0-zoom_factor)*yend + zoom_factor*y;

			dx *= zoom_factor;
			dy *= zoom_factor;
		} else {
			theta = clamp(theta + 5*scroll_dy, 0.0, 180.0);
		}

		


		append_to_log(&temp_log, "theta = %.1f", theta);
		append_to_log(&temp_log, "mousepos = {%.1f, %.1f}", xend, yend);


		p := Point{Vec2f{xend, yend}, 0.0, 0.0};
		chosen_link := -1;
		for l, i in links {
			if l.front == -1 do continue;
			p1 := points[l.left];
			p2 := Point{Vec2f{nodes[l.front].x, nodes[l.front].y}, 1.0, 0.0};
			p3 := Point{Vec2f{nodes[l.back].x, nodes[l.back].y}, 1.0, 0.0};
			p4 := points[l.right];
			if inside_triangle(&p1, &p2, &p3, &p) || inside_triangle(&p2, &p3, &p4, &p) {
				chosen_link = i;
				break;
			}
		}
		append_to_log(&temp_log, "chosen_link = %d", chosen_link);

		closest_distance: f64;
		closest_point: Vec2d;

		points_regression: [5]Vec2d;
		A1, A2, A3: f64;

		if chosen_link != -1 {
			P := Vec2d{cast(f64)xend, cast(f64)yend};
			R := cast(f64)links[chosen_link].Cr;

			a := Vec2d{cast(f64)nodes[links[chosen_link].back].x, cast(f64)nodes[links[chosen_link].back].y};
			b := Vec2d{cast(f64)nodes[links[chosen_link].front].x, cast(f64)nodes[links[chosen_link].front].y};

			A := a;
			B: Vec2d;
			C := b;
			tA := 0.0;
			tB := 0.5;
			tC := 1.0;

			if R <= 6.6e4 {
				O := Vec2d{cast(f64)links[chosen_link].O.x, cast(f64)links[chosen_link].O.y};
				closest_point = O + (P - O)*(R/math.mag(P - O));
				B = O + (0.5*(A + C) - O)*(R/math.mag(0.5*(A + C) - O));
			} else {
				p := P;
				n := math.norm0(b - a);
				d := (p - a) - math.dot(p - a, n)*n;
				closest_point = a + math.dot(p - a, n)*n;
				B = 0.5*(A + C);
			}

			P1 := Vec2d{cast(f64)points[links[chosen_link].left].x, cast(f64)points[links[chosen_link].left].y};
			P2 := Vec2d{cast(f64)points[links[chosen_link].right].x, cast(f64)points[links[chosen_link].right].y};

			R1 := f64(points[links[chosen_link].left].r);
			R2 := f64(points[links[chosen_link].right].r);
			
			rA := math.mag(A - P1) - R1;
			rB := math.mag(B - P1) - R1;
			rC := math.mag(C - P1) - R1;

			closest_distance = math.mag(closest_point - P1) - R1;

			//fmt.println(rA, rB, rC, closest_distance, math.mag(closest_point - P1) - R1, math.mag(closest_point - P2) - R2, R);

			append_to_log(&temp_log, "back  = {%f, %f}", chosen_link != -1 ? nodes[links[chosen_link].back].x : 0.0, chosen_link != -1 ? nodes[links[chosen_link].back].y : 0.0);
			append_to_log(&temp_log, "mid   = {%f, %f}", chosen_link != -1 ? links[chosen_link].P.x : 0.0, chosen_link != -1 ? links[chosen_link].P.y : 0.0);
			append_to_log(&temp_log, "front = {%f, %f}", chosen_link != -1 ? nodes[links[chosen_link].front].x : 0.0, chosen_link != -1 ? nodes[links[chosen_link].front].y : 0.0);
			
			ts, points_regression, coeffs, coeffs3 := coeffs_from_link(links, nodes, points, chosen_link);
			coeffs2 := [3]f64{coeffs[0], coeffs[1] - coeffs[3]/2.0 - 3.0*coeffs[4]/4.0, coeffs[2] + 3*coeffs[3]/2.0 + 7*coeffs[4]/4.0};
			tt: f64;

			if R <= 6.6e4 {
				O := Vec2d{cast(f64)links[chosen_link].O.x, cast(f64)links[chosen_link].O.y};
				P := closest_point;
				OA := math.norm0(A - O);
				OC := math.norm0(C - O);
				OP := math.norm0(P - O);

				a1 := acos(OA.x*OP.x + OA.y*OP.y);
				a2 := acos(OA.x*OC.x + OA.y*OC.y);
				aa := acos(OA.x*1.0 + OA.y*0.0);
				aaa := acos(OC.x*1.0 + OC.y*0.0);
				if OA.y < 0 {
					aa = 2.0*math.PI - aa;
				}
				if OC.y < 0 {
					aaa = 2.0*math.PI - aaa;
				}

				tt = a1/a2;

				{
					for i in 0..5 {
						t := ts[i];
						p := cast(f64)coeffs[0] + cast(f64)coeffs[1]*t + cast(f64)coeffs[2]*t*t + cast(f64)coeffs[3]*t*t*t + cast(f64)coeffs[4]*t*t*t*t;
						r := max(math.mag(points_regression[i] - P1) - R1, math.mag(points_regression[i] - P2) - R2);
						e := abs(p - r)/r;
						append_to_log(&temp_log, "P(%.2f) = {%.2f, %.2f}, R = {left: %.4f, right: %.4f, fit: %.4f}, e = %.4f%%", t, points_regression[i].x, points_regression[i].y, math.mag(points_regression[i] - P1) - R1, math.mag(points_regression[i] - P2) - R2, p, 100*e);
					}

					A1 = a1;
					A2 = a2;
					A3 = min(aa, aaa);
				}

			} else {
				for i in 0..5 {
					t := ts[i];
					p := cast(f64)coeffs[0] + cast(f64)coeffs[1]*t + cast(f64)coeffs[2]*t*t + cast(f64)coeffs[3]*t*t*t + cast(f64)coeffs[4]*t*t*t*t;
					r := max(math.mag(points_regression[i] - P1) - R1, math.mag(points_regression[i] - P2) - R2);
					e := abs(p - r)/r;
					append_to_log(&temp_log, "P(%.2f) = {%.2f, %.2f}, R = {left: %.4f, right: %.4f, fit: %.4f}, e = %.4f%%", t, points_regression[i].x, points_regression[i].y, math.mag(points_regression[i] - P1) - R1, math.mag(points_regression[i] - P2) - R2, p, 100*e);
				}
				p := P;
				n := math.norm0(b - a);
				d := (p - a) - math.dot(p - a, n)*n;
				closest_point = a + math.dot(p - a, n)*n;
				B = 0.5*(A + C);
				tt = math.mag(closest_point - a)/math.mag(b - a);
			}
			
			{
				p := cast(f64)coeffs[0] + cast(f64)coeffs[1]*tt + cast(f64)coeffs[2]*tt*tt + cast(f64)coeffs[3]*tt*tt*tt + cast(f64)coeffs[4]*tt*tt*tt*tt;
				p2 := cast(f64)coeffs2[0] + cast(f64)coeffs2[1]*tt + cast(f64)coeffs2[2]*tt*tt;

				
				A := cast(f64)coeffs[0];
				B := cast(f64)coeffs[1];
				C := cast(f64)coeffs[2];
				D := cast(f64)coeffs[3];
				E := cast(f64)coeffs[4];

				A2 := cast(f64)coeffs3[0];
				B2 := cast(f64)coeffs3[1];
				C2 := cast(f64)coeffs3[2];
				D2 := cast(f64)coeffs3[3];
				E2 := cast(f64)coeffs3[4];

				// r(x) = A + Bx + Cx² + Dx³ + Ex⁴
				// r'(x) = B + 2Cx + 3Dx² + 4Ex³
				// R(x) = r(x) / cos(0 - atan(r'(x)))
				// cos(alpha(x)) = r(x)/R(x)
				// R(x) = r(x) / cos(cos^-1(r(x)/R(x)))

				t := tt;
				r := A2 + B2*t + C2*t*t + D2*t*t*t + E2*t*t*t*t;
				R := A + B*t + C*t*t + D*t*t*t + E*t*t*t*t;
				dR := B + 2*C*t + 3*D*t*t + 4*E*t*t*t;
				a := acos(min(1.0, r/R));
				dr := r / math.cos(theta*math.PI/180.0 - (dR > 0.0 ? a : -a));
				//dr = (dR > 0.0 ? -acos(min(1.0, r/R)) : acos(min(1.0, r/R)))*180.0/math.PI;
				//dr = dR;
				//dr = math.cos(theta*math.PI/180.0 - acos(min(1.0, r/R)));
				//dr = r/R;

				pc := 1.0/dr;
				pc0 := 1.0/R;

				rr := max(math.mag(closest_point - P1) - R1, math.mag(closest_point - P2) - R2);
				e := abs(R - rr)/rr;
				
				append_to_log(&temp_log, "P(%.2f) = {%.2f, %.2f}, R0 = {left: %.4f, right: %.4f, fit: %.4f}, pc = %.4f, pc0 = %.4f, r = %.4f, R = %.4f, a = %.4f, e = %.2f%%", tt, closest_point.x, closest_point.y, math.mag(closest_point - P1) - R1, math.mag(closest_point - P2) - R2, R, pc, pc0, r, dr, a, 100*e);
			}

			append_to_log(&temp_log, "%s", "");
			append_to_log(&temp_log, "R = %f",        chosen_link != -1 ? links[chosen_link].Cr : 0.0);
			append_to_log(&temp_log, "O = {%f, %f}",     chosen_link != -1 ? links[chosen_link].O.x : 0.0, chosen_link != -1 ? links[chosen_link].O.y : 0.0);

		}

		if (key_states[glfw.KEY_TAB] == 1) {
			enable_vsync = !enable_vsync;
			glfw.SwapInterval(cast(i32)enable_vsync);
		}

		if (key_states[glfw.KEY_C] == 1) {
			should_clear = !should_clear;
		}

		if (key_states[glfw.KEY_F5] == 1) {
			new_program, success := gl.load_shaders("shaders/shader_delaunay.vs", "shaders/shader_delaunay.fs");
			if success {
				gl.DeleteProgram(program);
				program = new_program;
			}
		}

		if key_states[glfw.KEY_RIGHT] == 1 {
			current_link = (current_link + 1) %% len(links);
			d := 0.5*(nodes[links[sorted_by_length[current_link]].front].xy + nodes[links[sorted_by_length[current_link]].back].xy);
			dx, dy = 50.0, 50.0*dy/dx;
			x = d.x - dx/2.0;
			y = d.y - dy/2.0;

		}
		if key_states[glfw.KEY_LEFT] == 1 {
			current_link = (current_link - 1) %% len(links);
			d := 0.5*(nodes[links[sorted_by_length[current_link]].front].xy + nodes[links[sorted_by_length[current_link]].back].xy);
			dx, dy = 50.0, 50.0*dy/dx;
			x = d.x - dx/2.0;
			y = d.y - dy/2.0;
		}

		if (key_states[glfw.KEY_SPACE] == 1) {
			current_link = 0;
			d := 0.5*(nodes[links[sorted_by_length[current_link]].front].xy + nodes[links[sorted_by_length[current_link]].back].xy);
			dx, dy = 50.0, 50.0*dy/dx;
			x = d.x - dx/2.0;
			y = d.y - dy/2.0;
		}

		if (key_states[glfw.KEY_Z] == 1) {
			current_link = 6311;
			current_link = 1042;
			current_link = 6170;
			current_link = 349;
			d := 0.5*(nodes[links[current_link].front].xy + nodes[links[current_link].back].xy);
			dx, dy = 50.0, 50.0*dy/dx;
			x = d.x - dx/2.0;
			y = d.y - dy/2.0;
		}

		for i in 0..10 {
			if key_states[glfw.KEY_0 + i32(i)] == 1 {
				draw_states[i] = !draw_states[i];
			}
		}

		mouse_x_prev, mouse_y_prev = mouse_x, mouse_y;
		scroll_x_prev, scroll_y_prev = scroll_x, scroll_y;
		for i in 0..5 do mouse_button_prev[i] = mouse_button[i];

		// clear screen
		if should_clear do gl.Clear(gl.COLOR_BUFFER_BIT);

		gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, buf_points);
		gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, buf_nodes);
		gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, buf_links);

		// setup shader program and uniforms
		gl.UseProgram(program);
		gl.Uniform1f(get_uniform_location(program, "time\x00"), f32(glfw.GetTime()));
		gl.Uniform1i(get_uniform_location(program, "chosen_link\x00"), cast(i32)(chosen_link));   
		gl.Uniform1i(get_uniform_location(program, "should_clear\x00"), cast(i32)(should_clear));   
		gl.Uniform1i(get_uniform_location(program, "should_highlight\x00"), cast(i32)(draw_states[9]));   
		gl.Uniform2f(get_uniform_location(program, "mouse_pos\x00"), cast(f32)(closest_point.x), cast(f32)(closest_point.y));   
		gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(closest_distance));   



		gl.BindVertexArray(vao); // empty

		files := [...]string{
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca1.6e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca1.6e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca1.6e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca2.9e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca2.9e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca2.9e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca5.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca5.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca5.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca9.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca9.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca9.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca1.6e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca1.6e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca1.6e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca2.9e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca2.9e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca2.9e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca5.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca5.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca5.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca9.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca9.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca9.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca1.6e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca1.6e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca1.6e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca2.9e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca2.9e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca2.9e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca5.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca5.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca5.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca9.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca9.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca9.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca1.6e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca1.6e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca1.6e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca2.9e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca2.9e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca2.9e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca5.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca5.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca5.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca9.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca9.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca9.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca1.6e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca1.6e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca1.6e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca2.9e+00-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca2.9e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca2.9e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca5.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca5.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca5.2e-03-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca9.2e-01-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca9.2e-02-0.bin",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca9.2e-03-0.bin",
		};
		output := [...]string{
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca1.6e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca1.6e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca1.6e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca2.9e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca2.9e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca2.9e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca5.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca5.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca5.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca9.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca9.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta120_Ca9.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca1.6e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca1.6e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca1.6e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca2.9e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca2.9e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca2.9e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca5.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca5.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca5.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca9.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca9.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta173_Ca9.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca1.6e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca1.6e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca1.6e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca2.9e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca2.9e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca2.9e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca5.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca5.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca5.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca9.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca9.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta30_Ca9.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca1.6e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca1.6e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca1.6e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca2.9e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca2.9e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca2.9e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca5.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca5.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca5.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca9.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca9.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta60_Ca9.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca1.6e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca1.6e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca1.6e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca2.9e+00-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca2.9e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca2.9e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca5.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca5.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca5.2e-03-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca9.2e-01-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca9.2e-02-0.bmp",
			"/home/vassvik/hg/flow_reboot/run_gather/states/theta90_Ca9.2e-03-0.bmp",
		};



		if (key_states[glfw.KEY_F] == 1) {
			data := make([]u8, 3*render_resx*render_resy);
			defer free(data);

			for filename, l in files {
				fmt.println("Reading file", filename);
				state_data, success_data := os.read_entire_file(filename);
				defer free(state_data);

				if !success_data {
					fmt.println("Could not read file", filename);
					continue;
				}


				state_header := (cast(^StateHeader)&state_data[0])^;

				num_bubbles := mem.slice_ptr(cast(^i32)&state_data[size_of(StateHeader)+3*8*num_links], num_links);
				bubble_positions := mem.slice_ptr(cast(^f64)&state_data[size_of(StateHeader)+3*8*num_links+4*num_links], int(state_header.total_bubbles*2));

				ctr := 0;
				for i in 0..num_links {
					links_dynamic[i].num_bubbles = num_bubbles[i];
					for j in 0..num_bubbles[i] {
						links_dynamic[i].bubbles_start[j] = cast(f32)bubble_positions[ctr];
						links_dynamic[i].bubbles_stop[j] = cast(f32)bubble_positions[ctr+1];
						ctr += 2;
					}
				}

				gl.NamedBufferSubData(buf_links_dynamic,  0, size_of(Links_Dynamic)*num_links,   &links_dynamic[0]);

				fmt.println("Rendering");

				t1 := glfw.GetTime();
				gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer);
				gl.Clear(gl.COLOR_BUFFER_BIT);
				gl.Viewport(0, 0, render_resx, render_resy);

				gl.Uniform2f(get_uniform_location(program, "resolution\x00"), f32(render_resx), f32(render_resy));
				gl.Uniform4f(get_uniform_location(program, "cam_box\x00"), x, y, x + dx, y + dy);   
		
				for i in 0..(should_clear ? 1 : 2) {
			        // light blue links (background)
			        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+0] ? 0 : -1));
			        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+0] ? 0 : -1));
			        if should_clear do gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);
			        
			        // green disks
			        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+1] ? 1 : -1));
			        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+1] ? 1 : -1));
			        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_points);
				}
				gl.Flush();
				t2 := glfw.GetTime();

				save_bmp :: proc(filename: string, render_width, render_height: i32, data: []u8) {
					BMP_Header :: struct #packed {
						signature:         u16 = 0x4D42,
						size_file:         u32,
						_:                 u16 = 0,
						_:                 u16 = 0,
						offset:            u32 = 54,
						header_size:       u32 = 40,
						width:             u32,
						height:            u32,
						planes:            u16 = 1,
						bits_per_pixel:    u16,
						compression:       u32 = 0,
						size_image:        u32,
						hppm:              u32 = 0,
						vppm:              u32 = 0,
						num_colors:        u32 = 0,
						important_colors:  u32 = 0,
					};

					using header: BMP_Header;
					width = cast(u32)render_width;
					height = cast(u32)render_height;
					bits_per_pixel = 24;
					size_image = width*height*u32(bits_per_pixel)/8;
					size_file = size_of(BMP_Header) + size_image;
					
					data_all := make([]u8, 54+size_image);
					(cast(^BMP_Header)&data[0])^ = header;

					copy(data_all[54..], data[..]);

					success := os.write_entire_file(filename, data[..]);
					fmt.println(success, size_of(BMP_Header), header);


				}

				fmt.println("Saving");
				//save_network(links, nodes, points);

				t3 := glfw.GetTime();
				

				gl.BindFramebuffer(gl.READ_FRAMEBUFFER, framebuffer);
				gl.ReadBuffer(gl.COLOR_ATTACHMENT0);
				gl.ReadPixels(0, 0, render_resx, render_resy, gl.BGR, gl.UNSIGNED_BYTE, &data[0]);
				gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0);
				t4 := glfw.GetTime();
				save_bmp(output[l], render_resx, render_resy, data[..]);
				t5 := glfw.GetTime();

	
				fmt.println("Calculating fractal dimensions");				

				for k in 0..uint(15) {
					d := 1 << k;
					n := int(render_resx)/d;

					count := 0;
					for j in 0..n {
						for i in 0..n {
							found := false;
							inner: for J in 0..d {
								for I in 0..d {
									z := (j*d + J)*int(render_resx) + (i*d + I);
									if data[3*z] > 250 && data[3*z] < 255 {
										found = true;
										break inner;
									}
								}
							}
							count += found ? 1 : 0;
						}
					}
					fmt.println(d, count);
				}

				t6 := glfw.GetTime();


				fmt.printf("Time to render = %.3f ms\n", 1000*(t2-t1));
				fmt.printf("Time to copy = %.3f ms\n", 1000*(t4-t3));
				fmt.printf("Time to save = %.3f ms\n", 1000*(t5-t4));
				fmt.printf("Time to calculate = %.3f ms\n", 1000*(t6-t5));
		        
			}
		}

		gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
		gl.Viewport(0, 0, cast(i32)resx, cast(i32)resy);

		gl.Uniform2f(get_uniform_location(program, "resolution\x00"), f32(resx), f32(resy));
		gl.Uniform4f(get_uniform_location(program, "cam_box\x00"), x, y, x + dx, y + dy);   

		for i in 0..(should_clear ? 1 : 2) {
	        // light blue links (background)
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+0] ? 0 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+0] ? 0 : -1));
	        if should_clear do gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);
	        
	        // green disks
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+1] ? 1 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+1] ? 1 : -1));
	        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_points);
			
	        // black link arc
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+2] ? 2 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+2] ? 2 : -1));
	        if should_clear do gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);
	        
	        // purple disk at edge connecting two green disks
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+3] ? 3 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+3] ? 3 : -1));
	        if should_clear do gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);

	        // blue disk at mouse cursor
			gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(closest_distance));   
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+5] ? 5 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+5] ? 5 : -1));
	        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)1); 

	        // purple disk at edges radius
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+7] ? 7 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+7] ? 7 : -1));
	        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);     

	        // yellow disk at mouse cursor
			gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(0.25));   
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+4] ? 5 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+4] ? 4 : -1));
	        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)1); 
	        
	        // yellow node center disks
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+4] ? 4 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+4] ? 4 : -1));
	        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_nodes);

	        
	        // blue disk at nodes
	        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(draw_states[1+6] ? 6 : -1));
	        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(draw_states[1+6] ? 6 : -1));
	        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_nodes); 

	  
			colors_font := font.get_colors();
			for i in 0..4 do colors_font[i] = font.Vec4{0.0, 0.0, 0.0, 1.0};
			
			font.update_colors(4);

			ypos : f32 = 0.0;
			for s in temp_log {
				if draw_states[0] do font.draw_string(0.0, ypos,   20.0, s);
				ypos += s == "" ? 10.0 : 20.0;
			}


		}
		glfw.SwapBuffers(window);

	}
}

flow_io_adler32 :: proc(data: []u8) -> u32 {
    MOD_ADLER  :: 65521;
    a, b: u32 = 1, 0;
    
    for d in data {
		a = (a + cast(u32)d) % MOD_ADLER;
    	b = (b + cast(u32)a) % MOD_ADLER;
    }
    return (b << 16) | a;
}



save_network :: proc(links: []Link, nodes: []Node, points: []Point) {
	min_x, min_y, min_z := +1.0e9, +1.0e9, +1.0e9;
	max_x, max_y, max_z := -1.0e9, -1.0e9, -1.0e9;
	for node in nodes {
		min_x, min_y, min_z = min(min_x, cast(f64)node.x), min(min_y, cast(f64)node.y), min(min_z, cast(f64)0.0);
		max_x, max_y, max_z = max(max_x, cast(f64)node.x), max(max_y, cast(f64)node.y), max(max_z, cast(f64)0.0);
	}
	Lx, Ly, Lz := (max_x - min_x)*(54.0/1000.0), (max_y - min_y)*(54.0/1000.0), (max_z - min_z)*(54.0/1000.0);

	num_links := len(links);
	num_nodes := len(nodes);

	num_neighbours := make([]i32, num_nodes); defer free(num_neighbours);
	
	node_neighbours2 := make([][3]i32, num_nodes); defer free(node_neighbours2);
	link_neighbours2 := make([][3]i32, num_nodes); defer free(link_neighbours2);

	for node, i in nodes {
		for j in 0..3 {
			node_neighbours2[i][j] = -1;
		}
	}

	max_neighbours := 3;
	total_neighbours : i32 = 0;
	for node, i in nodes {
		num_neighbours[i] = (node.t == 0 ? 3 : 1);
		total_neighbours += num_neighbours[i];

		for j in 0..num_neighbours[i] {
			link_neighbours2[i][j] = node.links[j];

			if links[node.links[j]].front == cast(i32)i {
				node_neighbours2[i][j] = links[node.links[j]].back;
			} else if links[node.links[j]].back == cast(i32)i {
				node_neighbours2[i][j] = links[node.links[j]].front;
			} else {
				assert(false);
			}
		}
	}

	used := make([]bool, num_nodes);
	queue := make([]int, num_nodes);
	old_to_new := make([]int, num_nodes);
	start := 0;
	stop := 0;



	num_inlets := 0;
	for node, i in nodes {
		if Node_t(node.t) == Node_t.Inlet {
			queue[stop] = i;
			old_to_new[i] = stop;
			used[i] = true;
			stop += 1;
			num_inlets += 1;
		}
	}

	for start != stop {
		i := queue[start];
		node := nodes[i];
		start += 1;

		// inlets special case
		if (Node_t(node.t) == Node_t.Inlet) {
			queue[stop] = cast(int)node_neighbours2[i][0];
			old_to_new[node_neighbours2[i][0]] = stop;
			used[node_neighbours2[i][0]] = true;
			stop += 1;
			//fmt.println(node_neighbours2[i]);
			continue;
		}

		//fmt.println(node_neighbours2[i]);
		for j in 0..3 {
			if used[node_neighbours2[i][j]] do continue;
			
			if Node_t(nodes[node_neighbours2[i][j]].t) == Node_t.Outlet do continue;
			
			queue[stop] = cast(int)node_neighbours2[i][j];
			old_to_new[node_neighbours2[i][j]] = stop;
			used[node_neighbours2[i][j]] = true;
			stop += 1;
		}
	}


	num_outlets := 0;
	for node, i in nodes {
		if Node_t(node.t) == Node_t.Outlet {
			num_outlets += 1;
			queue[stop] = i;
			old_to_new[i] = stop;
			used[i] = true;
			stop += 1;
		}
	}

	fmt.println(stop);
	fmt.println(num_nodes, num_inlets, num_outlets, num_links);

	for node, i in nodes {
		//fmt.println(i, queue[i], Node(nodes[queue[i]].t), Node(nodes[i].t), old_to_new[i]);
		//fmt.println(i, old_to_new[i]);
	}

	/*
	for i in 0..num_nodes {
		fmt.println("1", i);
		fmt.println("2", old_to_new[i]);
		fmt.println("3", queue[i]);
		fmt.println("4", old_to_new[queue[i]]);
		fmt.println("5", queue[old_to_new[i]]);
	}
	*/
	


	node_neighbours := make([]i32, total_neighbours); defer free(node_neighbours);
	link_neighbours := make([]i32, total_neighbours); defer free(link_neighbours);
	node_type       := make([]i32, num_nodes);        defer free(node_type);

	node_positions := make([]f64, 3*num_nodes); defer free(node_positions);

	total_neighbours = 0;
	
	for _, i in nodes {
		for j in 0..(nodes[queue[i]].t == 0 ? 3 : 1) {
			link_neighbours[total_neighbours] = nodes[queue[i]].links[j];

			if old_to_new[links[nodes[queue[i]].links[j]].front] == i {
				node_neighbours[total_neighbours] = cast(i32)old_to_new[links[nodes[queue[i]].links[j]].back];
			} else if old_to_new[links[nodes[queue[i]].links[j]].back] == i {
				node_neighbours[total_neighbours] = cast(i32)old_to_new[links[nodes[queue[i]].links[j]].front];
			} else {
				assert(false);
			}
			total_neighbours += 1;
		}
		node_type[i] = nodes[queue[i]].t;
		num_neighbours[i] = (nodes[queue[i]].t == 0 ? 3 : 1);
		node_positions[3*i+0], node_positions[3*i+1], node_positions[3*i+2] = cast(f64)nodes[queue[i]].x*(54.0/1000.0), cast(f64)nodes[queue[i]].y*(54.0/1000.0), 0.0;
	}
	
	//if true do return;


	node_front  := make([]i32, num_links); defer free(node_front);
	node_back   := make([]i32, num_links); defer free(node_back);
	link_type   := make([]i32, num_links); defer free(link_type);
	link_radius := make([]f64, num_links); defer free(link_radius);
	link_length := make([]f64, num_links); defer free(link_length);


	for link, i in links {
		front := cast(i32)link.front;
		back := cast(i32)link.back;
		node_front[i] = cast(i32)old_to_new[front];
		node_back[i] = cast(i32)old_to_new[back];
		link_type[i] = link.t;

		if i == 470 || i == 471 {
			fmt.println(i, links[i], nodes[front], nodes[back]);
		}

		dx := nodes[front].x - nodes[back].x;
		dy := nodes[front].y - nodes[back].y;
		dr := math.sqrt(dx*dx + dy*dy);
		link_length[i] = cast(f64)dr*(54.0/1000.0);

		A := math.Vec2{points[link.left].x, points[link.left].y};
		B := math.Vec2{nodes[front].x, nodes[front].y};
		C := math.Vec2{nodes[back].x, nodes[back].y};
		D := math.Vec2{points[link.right].x, points[link.right].y};

		rA := cast(f64)points[link.left].r;
		rD := cast(f64)points[link.right].r;

		A1 := f64(0.5*abs( (B.x - A.x)*(C.y - A.y) - (C.x - A.x)*(B.y - A.y) ));
		A2 := f64(0.5*abs( (B.x - D.x)*(C.y - D.y) - (C.x - D.x)*(B.y - D.y) ));

		c1 := cast(f64)math.dot(math.norm0(B - A), math.norm0(C - A));
		c2 := cast(f64)math.dot(math.norm0(B - D), math.norm0(C - D));

		{
			A1 = A1 - f64(math.PI*rA*rA)*(acos(c1)/(2.0*math.PI));
			A2 = A2 - f64(math.PI*rD*rD)*(acos(c2)/(2.0*math.PI));
			A := (A1 + A2)*(54.0/1000.0)*(54.0/1000.0);
			
			V := A*0.1;
			L := link_length[i];

			//fmt.println(i, math.sqrt(V/L/(math.PI)), A/L, A/L/0.1, L);
			link_radius[i] = A/L/2.0;

			

			//fmt.println(i, L, A/L);
		}
	}
	C := make([][6]f64, 2*num_links);
	c1 := C[..num_links];
	c2 := C[num_links..];
	//fmt.println("cR := [...][5]f64 {\n");
	for i in 0..num_links {
		ts, points_regression, coeffs, coeffs3 := coeffs_from_link(links, nodes, points, i);

		c1[i] = [6]f64 {coeffs[0]*(54/1000.0), coeffs[1]*(54/1000.0), coeffs[2]*(54/1000.0), coeffs[3]*(54/1000.0), coeffs[4]*(54/1000.0), 1.0e9};
		c2[i] = [6]f64 {coeffs3[0]*(54/1000.0), coeffs3[1]*(54/1000.0), coeffs3[2]*(54/1000.0), coeffs3[3]*(54/1000.0), coeffs3[4]*(54/1000.0), 0.0};

		for j in 0...100 {
			x := f64(j)/100.0;
			R := c1[i][0] + c1[i][1]*x + c1[i][2]*x*x + c1[i][3]*x*x*x + c1[i][4]*x*x*x*x;
			//fmt.println(i, c1[i], c2[i], x, R);
			c1[i][5] = min(R, c1[i][5]);
		}
		fmt.println(i, c1[i]);
		

		//fmt.printf("    {%.16f, %.16f, %.16f, %.16f, %.16f}, \n", coeffs[0]*(54/1000.0), coeffs[1]*(54/1000.0), coeffs[2]*(54/1000.0), coeffs[3]*(54/1000.0), coeffs[4]*(54/1000.0));
	}
	os.write_entire_file("coeffs.bin", mem.slice_ptr(cast(^u8)&C[0][0], 6*8*num_links*2));
	//fmt.println("};\n");

	/*
	fmt.println("cr := [...][5]f64 {\n");
	for i in 0..num_links {
		ts, points_regression, coeffs, coeffs3 := coeffs_from_link(links, nodes, points, i);
		fmt.printf("    {%.16f, %.16f, %.16f, %.16f, %.16f}, \n", coeffs3[0]*(54/1000.0), coeffs3[1]*(54/1000.0), coeffs3[2]*(54/1000.0), coeffs3[3]*(54/1000.0), coeffs3[4]*(54/1000.0));
	}
	fmt.println("};\n");
	*/

    o0  := size_of(NetworkHeader); // num_neighbours
    o1  := o0 + size_of(i32)*int(num_nodes);    // node_neighbours
    o2  := o1 + size_of(i32)*int(total_neighbours); // link_neighbours
    o3  := o2 + size_of(i32)*int(total_neighbours); // node_pos
    o4  := o3 + size_of(f64)*int(3*num_nodes);   // node_front
    o5  := o4 + size_of(i32)*int(num_links);        // node_back
    o6  := o5 + size_of(i32)*int(num_links);        // link_radius
    o7  := o6 + size_of(f64)*int(num_links);     // link_radius
    o8  := o7 + size_of(f64)*int(num_links);     // link_type
    o9  := o8 + size_of(i32)*int(num_links);    // node_type
    o10 := o9 + size_of(i32)*int(num_nodes);     // end

	data := make([]u8, o10);
	mem.copy(&data[o0], &num_neighbours[0],  o1-o0);
	mem.copy(&data[o1], &node_neighbours[0], o2-o1);
	mem.copy(&data[o2], &link_neighbours[0], o3-o2);
	mem.copy(&data[o3], &node_positions[0],  o4-o3);
	mem.copy(&data[o4], &node_front[0],      o5-o4);
	mem.copy(&data[o5], &node_back[0],       o6-o5);
	mem.copy(&data[o6], &link_length[0],     o7-o6);
	mem.copy(&data[o7], &link_radius[0],     o8-o7);
	mem.copy(&data[o8], &link_type[0],       o9-o8);
	mem.copy(&data[o9], &node_type[0],       o10-o9);

	(cast(^NetworkHeader)&data[0])^ = NetworkHeader{
		checksum = flow_io_adler32(data[o0..]),
		size = i32(o10 - o0),
		num_nodes = i32(num_nodes),
		num_links = i32(num_links),
		max_neighbours = i32(max_neighbours),
		total_neighbours = i32(total_neighbours),
		Lx = Lx,
		Ly = Ly,
		Lz = Lz,
	};

	//os.write_entire_file("test_network2.bin", data);

	//header := NetworkHeader{checksum = flow_io_adler32()}

	/*
	save_network("network_test.bin", 
			 num_links, num_nodes, total_neighbours, max_neighbours: i32,
			 Lx, Ly, Lz: f64, 
			 num_neighbours, node_neighbours, link_neighbours, node_front, node_back, node_type, link_type: []i32,
			 link_radius, link_length, node_positions: []f64);
	*/
}

NetworkHeader :: struct #ordered {
    checksum: u32,          // Adler32 checksum of raw binary network data
    size: i32,              // how many bytes of raw binary data after header
    num_nodes: i32,         
    num_links: i32,         
    max_neighbours: i32,    
    total_neighbours: i32,  
    Lx: f64,                // size of system in x, y and z direction
    Ly: f64,
    Lz: f64,
    // XX bytes
};

load_from_file :: proc(filename: string) -> (points: []Point, nodes: []Node, links: []Link) {
	data, success := os.read_entire_file(filename);
	if !success do return nil, nil, nil;
	defer free(data);

	points := make([]Point, (cast(^int)&data[0])^);
	nodes := make([]Node, (cast(^int)&data[8])^);
	links := make([]Link, (cast(^int)&data[16])^);

	s0 := 8*3;
	s1 := s0 + len(points)*size_of(Point);
	s2 := s1 + len(nodes)*size_of(Node);

	mem.copy(&points[0], &data[s0], len(points)*size_of(Point));
	mem.copy(&nodes[0], &data[s1], len(nodes)*size_of(Node));
	mem.copy(&links[0], &data[s2], len(links)*size_of(Link));

	return points, nodes, links;
}

Vec2f :: [vector 2]f32;
Vec2d :: [vector 2]f64;

Point :: struct #ordered { // 12 bytes
	using xy: Vec2f,
	r: f32,
	pad := f32(0.0), // pad, so we can use vec2 in shader
};

Node :: struct #ordered {
	links: [3]i32,
	t:     	i32,
	using xy: Vec2f,
};


Link :: struct #ordered {
	front:  i32,   // Node
	back:   i32,   // Node
	left:   i32,   // Disk
	right:  i32,   // Disk
	P:      Vec2f, // Center of link along arc
	O:      Vec2f, // Position of origin of arc
	U:      Vec2f, // Direction of center of arc
	c:      f64,   // Cosine of half angle of arc, needs the precision
	Cr:     f32,   // Radius of curvature of arc
	t:      i32,   // type: 0, 1 (inlet) or 2 (outlet)
};

Links_Dynamic :: struct #ordered {
	filled: i32,
	num_bubbles: i32,
	bubbles_start: [16]f32,
	bubbles_stop: [16]f32,
};


// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, &str[0]);;
}

when ODIN_OS == "linux" {
	foreign import m "system:m";
} else {
	foreign import m "system:libcmt.lib";
}

foreign m {
	log2 :: proc(x: f64) -> f64  #link_name "log2" ---;
	acos :: proc(x: f64) -> f64  #link_name "acos" ---;
	atan :: proc(x: f64) -> f64  #link_name "atan" ---;
	atan2 :: proc(y, x: f64) -> f64  #link_name "atan2" ---;
}


coeffs_from_link :: proc(links: []Link, nodes: []Node, points: []Point, chosen_link: int) -> ([5]f64, [5]Vec2d, [5]f64, [5]f64) {
	R := cast(f64)links[chosen_link].Cr;

	A := Vec2d{cast(f64)nodes[links[chosen_link].back].x, cast(f64)nodes[links[chosen_link].back].y};
	C := Vec2d{cast(f64)nodes[links[chosen_link].front].x, cast(f64)nodes[links[chosen_link].front].y};

	P1 := Vec2d{cast(f64)points[links[chosen_link].left].x, cast(f64)points[links[chosen_link].left].y};
	P2 := Vec2d{cast(f64)points[links[chosen_link].right].x, cast(f64)points[links[chosen_link].right].y};

	R1 := f64(points[links[chosen_link].left].r);
	R2 := f64(points[links[chosen_link].right].r);
	
	ts := [5]f64{0.0, 0.25, 0.50, 0.75, 1.00};
	ps: [5]Vec2d;
	rs: [5]f64;

	if R <= 6.6e4 {
		O := Vec2d{cast(f64)links[chosen_link].O.x, cast(f64)links[chosen_link].O.y};
		OA := math.norm0(A - O);
		OC := math.norm0(C - O);

		a2 := acos(OA.x*OC.x + OA.y*OC.y);
		aa := atan2(OA.y, OA.x);
		aa2 := atan2(OC.y, OC.x);

		if math.mag(O + R*Vec2d{math.cos(aa + a2), math.sin(aa + a2)} - C) > 0.01 do a2 *= -1;

		min_t := 2.0;
		min_r := 10000.0;
		for i in 0..100 {
			t := f64(i)/99.0;
			p := O + R*Vec2d{math.cos(aa + a2*t), math.sin(aa + a2*t)};
			r := max(math.mag(p - P2) - R2, math.mag(p - P1) - R1);

			if r < min_r {
				min_t = t;
				min_r = r;
			}
		}

		if min_t > 0.0001 && min_t < 0.9999 do ts[2] = min_t;

		for i in 0..5 {
			ps[i] = O + R*Vec2d{math.cos(aa + a2*ts[i]), math.sin(aa + a2*ts[i])};
			rs[i] = max(math.mag(ps[i] - P2) - R2, math.mag(ps[i] - P1) - R1);
		}

	} else {
		min_t := 2.0;
		min_r := 10000.0;
		for i in 0..100 {
			t := f64(i)/99.0;
			p := A + (C - A)*t;
			r := max(math.mag(p - P2) - R2, math.mag(p - P1) - R1);

			if r < min_r {
				min_t = t;
				min_r = r;
			}
		}

		if min_t > 0.0001 && min_t < 0.9999 do ts[2] = min_t;

		for i in 0..5 {
			ps[i] = A + (C - A)*ts[i];
			rs[i] = max(math.mag(ps[i] - P2) - R2, math.mag(ps[i] - P1) - R1);
		}
	}

	rs2: [5]f64;
	for i in 0..5 {
		p := ps[i];
		R := rs[i];

		p1 := P1;
		p2 := P2;

		q1 := p1 + math.norm0(p - p1)*(math.mag(p - p1) - rs[i]);
		q2 := p2 + math.norm0(p - p2)*(math.mag(p - p2) - rs[i]);

		rs2[i] = math.mag(q2 - q1)/2.0;
	}


	a := f32(rs[0]);
	a2 := f32(rs2[0]);
	M: math.Mat4;
	for j in 0..4 {
		for i in 0..4 {
			M[i][j] = cast(f32)math.pow(cast(f64)ts[i+1], f64(j)+1);
		}
	}

	/*
	M = math.Mat4{
		{1.0/4.0,  1.0/16.0,  1.0/64.0,   1.0/256.0},
		{2.0/4.0,  4.0/16.0,  8.0/64.0,  16.0/256.0},
		{3.0/4.0,  9.0/16.0, 27.0/64.0,  81.0/256.0},
		{4.0/4.0, 16.0/16.0, 64.0/64.0, 256.0/256.0},
	};
	*/
	b := math.Vec4{
		f32(rs[1]) - a, 
		f32(rs[2]) - a, 
		f32(rs[3]) - a, 
		f32(rs[4]) - a,
	};
	b2 := math.Vec4{
		f32(rs2[1]) - a2, 
		f32(rs2[2]) - a2, 
		f32(rs2[3]) - a2, 
		f32(rs2[4]) - a2,
	};

	coeffs := math.mul(math.inverse(M), b);
	coeffs2 := math.mul(math.inverse(M), b2);

	rs3: [5]f64;
	for i in 0..5 {
		A := cast(f64)a;
		B := cast(f64)coeffs[0];
		C := cast(f64)coeffs[1];
		D := cast(f64)coeffs[2];
		E := cast(f64)coeffs[3];

		A2 := cast(f64)a2;
		B2 := cast(f64)coeffs2[0];
		C2 := cast(f64)coeffs2[1];
		D2 := cast(f64)coeffs2[2];
		E2 := cast(f64)coeffs2[3];

		// r(x) = A + Bx + Cx² + Dx³ + Ex⁴
		// r'(x) = B + 2Cx + 3Dx² + 4Ex³
		// R(x) = r(x) / cos(0 - atan(r'(x)))
		// cos(alpha(x)) = r(x)/R(x)
		// R(x) = r(x) / cos(cos^-1(r(x)/R(x)))

		t := 0.25*f64(i);
		r := A2 + B2*t + C2*t*t + D2*t*t*t + E2*t*t*t*t;
		R := A + B*t + C*t*t + D*t*t*t + E*t*t*t*t;
		dr := r / math.cos(0 - acos(r/R));
		rs3[i] = dr;
	}

	append_to_log(&temp_log, "%s", "");
	append_to_log(&temp_log, "timesteps: %v", ts);
	append_to_log(&temp_log, "points:    %v", ps);
	append_to_log(&temp_log, "radii:     %v %v %v", rs, rs2, rs3);
	append_to_log(&temp_log, "coeffs:    %f %v  %f %v", a, coeffs, a2, coeffs2);
	append_to_log(&temp_log, "%s", "");



	return ts, ps, [5]f64{cast(f64)a, cast(f64)coeffs[0], cast(f64)coeffs[1], cast(f64)coeffs[2], cast(f64)coeffs[3]}, [5]f64{cast(f64)a2, cast(f64)coeffs2[0], cast(f64)coeffs2[1], cast(f64)coeffs2[2], cast(f64)coeffs2[3]};
}

inside_triangle :: proc(A, B, C: ^Point, p: ^Point) -> bool {
	alpha := ((B.y - C.y)*(p.x - C.x) + (C.x - B.x)*(p.y - C.y)) / ((B.y - C.y)*(A.x - C.x) + (C.x - B.x)*(A.y - C.y));
    beta  := ((C.y - A.y)*(p.x - C.x) + (A.x - C.x)*(p.y - C.y)) / ((B.y - C.y)*(A.x - C.x) + (C.x - B.x)*(A.y - C.y));
    gamma := 1.0 - alpha - beta;

    return (alpha >= -1e-9 && beta >= -1e-9 && gamma >= -1e-9);
}