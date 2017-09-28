import "core:fmt.odin";
import "core:os.odin";
import "core:mem.odin";
import "core:strings.odin";
import "core:math.odin";
import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";
import "shared:odin-gl_font/font.odin";


scroll_x := 0.0;
scroll_y := 0.0;


append_to_log :: proc(log: ^$T/[dynamic]string, fmt_string: string, vals: ...any) {
	a := fmt.aprintf(fmt_string, ...vals);
	append(log, a);
}
temp_log: [dynamic]string;


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

	resx, resy := 1600.0, 900.0;
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

	if !font.init("extra/font_3x1.bin", "shaders/shader_font.vs", "shaders/shader_font.fs", set_proc_address) do return;  

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
		glfw.KEY_LEFT,
		glfw.KEY_RIGHT,
		glfw.KEY_SPACE,
		glfw.KEY_F5,
		glfw.KEY_TAB,
		glfw.KEY_ESCAPE,
	};

	enable_vsync := true;
	glfw.SwapInterval(cast(i32)enable_vsync);

	num_points := len(points);
	num_nodes := len(nodes);
	num_links := len(links);

	buf_points, buf_links, buf_nodes: u32;
	gl.CreateBuffers(1, &buf_points);
	gl.CreateBuffers(1, &buf_nodes);
	gl.CreateBuffers(1, &buf_links);
	defer {
		gl.DeleteBuffers(1, &buf_points);
		gl.DeleteBuffers(1, &buf_nodes);
		gl.DeleteBuffers(1, &buf_links);
	}

	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, buf_points);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, buf_nodes);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, buf_links);

	gl.NamedBufferData(buf_points, size_of(Point)*num_points, &points[0], gl.STATIC_DRAW);
	gl.NamedBufferData(buf_nodes,  size_of(Node)*num_nodes,   &nodes[0],  gl.STATIC_DRAW);
	gl.NamedBufferData(buf_links,  size_of(Link)*num_links,   &links[0],  gl.STATIC_DRAW);

	lengths := make([]f64, len(links));
	sorted_by_length := make([]int, len(links));

	for link, i in links {
		/*
		dx := nodes[link.front].x - nodes[link.back].x;
		dy := nodes[link.front].y - nodes[link.back].y;
		dr := math.sqrt(dx*dx + dy*dy);
		L := cast(f64)dr*(54.0/1000.0);

		A := math.Vec2{points[link.left].x, points[link.left].y};
		B := math.Vec2{nodes[link.front].x, nodes[link.front].y};
		C := math.Vec2{nodes[link.back].x, nodes[link.back].y};
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
			//L := link_length[i];

			fmt.println(i, math.sqrt(V/L/(math.PI)), A/L, A/L/0.1, L);
			lengths[i] = A/L/2.0;
		}
		*/

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

	//fmt.println(lengths);
	fmt.println(lengths[len(lengths)-1]);

	current_link := 0;

	t1 := glfw.GetTime();

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

		mouse_button: [5]i32;
		for i in 0..5 do mouse_button[i] = glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_1 + cast(i32)i);

		// handle input
		if mouse_button[0] == 1 {
			x -= f32(mouse_dx/resx*f64(dx));
			y += f32(mouse_dy/resy*f64(dy));
		}	

		x += f32(0.3*f64(dx)*dt * f64((key_states[glfw.KEY_D]&1) - key_states[glfw.KEY_A]&1));
		y += f32(0.3*f64(dy)*dt * f64((key_states[glfw.KEY_W]&1) - key_states[glfw.KEY_S]&1));

		zoom_factor := cast(f32)math.pow(0.95, scroll_dy);

		xend := f32(f64(x) + mouse_x*f64(dx)/resx);           // convert screen position to world cooridnates
		yend := f32(f64(y) + (resy - mouse_y)*f64(dy)/resy);   
		x = (1.0-zoom_factor)*xend + zoom_factor*x;       // update lower left corner
		y = (1.0-zoom_factor)*yend + zoom_factor*y;

		dx *= zoom_factor;
		dy *= zoom_factor;

		for key in polled_keys {
			key_states[key] = ((key_states[key] & 1) << 1) | (glfw.GetKey(window, key) << 0);
		}


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
			
			coeffs := coeffs_from_link(links, nodes, points, chosen_link);
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
						t := 0.25*f64(i);
						points_regression[i] = O + R*Vec2d{math.cos(min(aa, aaa) + a2*t), math.sin(min(aa, aaa) + a2*t)};
					}

					if math.mag(points_regression[0] - a) < 1.0e-0 {

					} else if math.mag(points_regression[0] - b) < 1.0e-0 {
						points_regression[0], points_regression[1], points_regression[3], points_regression[4] = points_regression[4], points_regression[3], points_regression[1], points_regression[0];
					} else {
						fmt.println("ERROR");
					}

					for i in 0..5 {
						t := 0.25*f64(i);
						append_to_log(&temp_log, "P(%.2f) = {%.2f, %.2f}, r = %.6f, %.6f", t, points_regression[i].x, points_regression[i].y, math.mag(points_regression[i] - P1) - R1, math.mag(points_regression[i] - P2) - R2);
					}

					A1 = a1;
					A2 = a2;
					A3 = min(aa, aaa);
				}

			} else {
				for i in 0..5 {
					t := 0.25*f64(i);
					points_regression[i] = A + (C - A)*t;
					append_to_log(&temp_log, "P(%.2f) = {%.2f, %.2f}, r = %.6f, %.6f", t, points_regression[i].x, points_regression[i].y, math.mag(points_regression[i] - P1) - R1, math.mag(points_regression[i] - P2) - R2);
				}
				p := P;
				n := math.norm0(b - a);
				d := (p - a) - math.dot(p - a, n)*n;
				closest_point = a + math.dot(p - a, n)*n;
				B = 0.5*(A + C);
				tt = math.mag(closest_point - a)/math.mag(b - a);
			}
			
			p := cast(f64)coeffs[0] + cast(f64)coeffs[1]*tt + cast(f64)coeffs[2]*tt*tt + cast(f64)coeffs[3]*tt*tt*tt + cast(f64)coeffs[4]*tt*tt*tt*tt;
			append_to_log(&temp_log, "P(%.2f) = {%.2f, %.2f}, r = %.6f, %.6f", tt, closest_point.x, closest_point.y, math.mag(closest_point - P1) - R1, math.mag(closest_point - P2) - R2);
			append_to_log(&temp_log, "%s", "");
			append_to_log(&temp_log, "R = %f",        chosen_link != -1 ? links[chosen_link].Cr : 0.0);
			append_to_log(&temp_log, "O = {%f, %f}",     chosen_link != -1 ? links[chosen_link].O.x : 0.0, chosen_link != -1 ? links[chosen_link].O.y : 0.0);

		}


		if (key_states[glfw.KEY_TAB] == 1) {
			enable_vsync = !enable_vsync;
			glfw.SwapInterval(cast(i32)enable_vsync);
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


		

		if (key_states[glfw.KEY_F] == 1) {
			fmt.println("Saving");
			save_network(links, nodes, points);
		}

		mouse_x_prev, mouse_y_prev = mouse_x, mouse_y;
		scroll_x_prev, scroll_y_prev = scroll_x, scroll_y;
		for i in 0..5 do mouse_button_prev[i] = mouse_button[i];

		// clear screen
		gl.Clear(gl.COLOR_BUFFER_BIT);

		gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, buf_points);
		gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, buf_nodes);
		gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, buf_links);

		// setup shader program and uniforms
		gl.UseProgram(program);
		gl.Uniform1f(get_uniform_location(program, "time\x00"), f32(glfw.GetTime()));
		gl.Uniform2f(get_uniform_location(program, "resolution\x00"), f32(resx), f32(resy));
		gl.Uniform4f(get_uniform_location(program, "cam_box\x00"), x, y, x + dx, y + dy);   
		gl.Uniform1i(get_uniform_location(program, "chosen_link\x00"), cast(i32)(chosen_link));   
		gl.Uniform2f(get_uniform_location(program, "mouse_pos\x00"), cast(f32)(closest_point.x), cast(f32)(closest_point.y));   
		gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(closest_distance));   


		gl.BindVertexArray(vao); // empty

        // light blue links (background)
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(0));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(0));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);
        
        // green disks
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(1));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(1));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_points);
		
        // black link arc
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(2));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(2));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);
        
        // purple disk at edge connecting two green disks
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(3));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(3));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_links);

        // yellow node center disks
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(4));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(4));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)num_nodes);
  
        // blue disk at mouse cursor
		gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(closest_distance));   
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(5));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(5));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)1);     

		gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(0.25));   
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(5));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(4));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)1); 
		
		colors_font := font.get_colors();
		for i in 0..4 do colors_font[i] = font.Vec4{0.0, 0.0, 0.0, 1.0};
		
		font.update_colors(4);

		ypos : f32 = 0.0;
		for s in temp_log {
			font.draw_string(0.0, ypos,   20.0, s);
			ypos += s == "" ? 10.0 : 20.0;
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

	Node :: enum {
	    Inside  = 0,
	    Inlet   = 1,
	    Outlet  = 2,
	    Outside = 3,
	};

	for node, i in nodes {
		if Node(node.t) == Node.Inlet {
			queue[stop] = i;
			old_to_new[i] = stop;
			used[i] = true;
			stop += 1;
		}
	}

	for start != stop {
		i := queue[start];
		node := nodes[i];
		start += 1;

		// inlets special case
		if (Node(node.t) == Node.Inlet) {
			queue[stop] = cast(int)node_neighbours2[i][0];
			old_to_new[node_neighbours2[i][0]] = stop;
			used[node_neighbours2[i][0]] = true;
			stop += 1;
			continue;
		}

		for j in 0..3 {
			if used[node_neighbours2[i][j]] do continue;
			
			if Node(nodes[node_neighbours2[i][j]].t) == Node.Outlet do continue;
			
			queue[stop] = cast(int)node_neighbours2[i][j];
			old_to_new[node_neighbours2[i][j]] = stop;
			used[node_neighbours2[i][j]] = true;
			stop += 1;
		}
	}

	for node, i in nodes {
		if Node(node.t) == Node.Outlet {
			queue[stop] = i;
			old_to_new[i] = stop;
			used[i] = true;
			stop += 1;
		}
	}

	for node, i in nodes {
		fmt.println(i, queue[i], Node(nodes[queue[i]].t), Node(nodes[i].t), old_to_new[i]);
	}

	for i in 0..num_nodes {
		fmt.println(i, old_to_new[i], queue[i], old_to_new[queue[i]], queue[old_to_new[i]]);
	}

	//if true do return;
	


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
		}
	}

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

	os.write_entire_file("test_network.bin", data);

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


// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, &str[0]);;
}

when ODIN_OS == "linux" {
	foreign_system_library m "m";
} else {
	foreign_system_library m "libcmt.lib";
}

foreign m {
	acos :: proc(x: f64) -> f64  #link_name "acos" ---;
}


coeffs_from_link :: proc(links: []Link, nodes: []Node, points: []Point, chosen_link: int) -> [5]f64 {
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
		aa := acos(OA.x*1.0 + OA.y*0.0);
		aaa := acos(OC.x*1.0 + OC.y*0.0);
		if OA.y < 0 do aa = 2.0*math.PI - aa;
		if OC.y < 0 do aaa = 2.0*math.PI - aaa;

		for i in 0..5 {
			ps[i] = O + R*Vec2d{math.cos(min(aa, aaa) + a2*ts[i]), math.sin(min(aa, aaa) + a2*ts[i])};
			rs[i] = ((math.mag(ps[i] - P2) - R2) + (math.mag(ps[i] - P1) - R1))/2.0;
		}

		if math.mag(ps[0] - A) < 1.0e-0 {

		} else if math.mag(ps[0] - C) < 1.0e-0 {
			ps[0], ps[1], ps[3], ps[4] = ps[4], ps[3], ps[1], ps[0];
			rs[0], rs[1], rs[3], rs[4] = rs[4], rs[3], rs[1], rs[0];
		} else {
			assert(true);
			fmt.println("ERROR");
		}
	} else {
		for i in 0..5 {
			ps[i] = A + (C - A)*ts[i];
			rs[i] = ((math.mag(ps[i] - P2) - R2) + (math.mag(ps[i] - P1) - R1))/2.0;
		}
	}

	a := f32(rs[0]);
	M := math.Mat4{
		{1.0/4.0,  1.0/16.0,  1.0/64.0,   1.0/256.0},
		{2.0/4.0,  4.0/16.0,  8.0/64.0,  16.0/256.0},
		{3.0/4.0,  9.0/16.0, 27.0/64.0,  81.0/256.0},
		{4.0/4.0, 16.0/16.0, 64.0/64.0, 256.0/256.0},
	};
	b := math.Vec4{
		f32(rs[1]) - a, 
		f32(rs[2]) - a, 
		f32(rs[3]) - a, 
		f32(rs[4]) - a,
	};

	coeffs := math.mul(math.inverse(M), b);
	append_to_log(&temp_log, "%s", "");
	append_to_log(&temp_log, "timesteps: %v", ts);
	append_to_log(&temp_log, "points:    %v", ps);
	append_to_log(&temp_log, "radii:     %v", rs);
	append_to_log(&temp_log, "coeffs:    %v", coeffs);
	append_to_log(&temp_log, "%s", "");

	return [5]f64{cast(f64)a, cast(f64)coeffs[0], cast(f64)coeffs[1], cast(f64)coeffs[2], cast(f64)coeffs[3]};
}

inside_triangle :: proc(A, B, C: ^Point, p: ^Point) -> bool {
	alpha := ((B.y - C.y)*(p.x - C.x) + (C.x - B.x)*(p.y - C.y)) / ((B.y - C.y)*(A.x - C.x) + (C.x - B.x)*(A.y - C.y));
    beta  := ((C.y - A.y)*(p.x - C.x) + (A.x - C.x)*(p.y - C.y)) / ((B.y - C.y)*(A.x - C.x) + (C.x - B.x)*(A.y - C.y));
    gamma := 1.0 - alpha - beta;

    return (alpha >= -1e-9 && beta >= -1e-9 && gamma >= -1e-9);
}