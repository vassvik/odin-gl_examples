import "core:fmt.odin";
import "core:strings.odin";
import "core:math.odin";
import "core:os.odin";
import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";
import "shared:odin-gl_font/font.odin";
import "shared:parser.odin";

when ODIN_OS == "windows" {
	last_vertex_time := os.last_write_time_by_name("shaders/shader_delaunay.vs");
	last_fragment_time := os.last_write_time_by_name("shaders/shader_delaunay.fs");
}

scroll_x := 0.0;
scroll_y := 0.0;

A :: math.SQRT_TWO;
B :: 1.0/(6.0*A);
C :: 3.0/(80.0*A);
D :: 5.0/(448.0*A);
E :: 35.0/(9216.0*A);
F :: 63.0/(45056.0*A);
G :: 231.0/(425984.0*A);

acos_near_one_13 :: proc(x: $T) -> T #cc_c {
    y1 := math.sqrt(1.0 - x);
    y2 := y1*y1;
    return y1*(A + y2*(B + y2*(C + y2*(D + y2*(E + y2*(F + y2*G))))));
}

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

	//glfw.WindowHint(glfw.SAMPLES, 1);
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

	t1 := glfw.GetTime();
	// load triangulation
	table, success := parser.table_from_file("extra/triangulation.txt");
	if !success do return;
	defer {
		for _, i in table do for _, j in table[i] do free(table[i][j]);
		for _, i in table do free(table[i]);
		free(table);
	}

	// parse table
	num_points := parser.int_from_string(table[0][2]);
	points := make([]Point, num_points);

	for line, i in table[1..1+num_points] {
		points[i] = Point{parser.f32_from_string(line[0]), parser.f32_from_string(line[1]), parser.f32_from_string(line[2])};
	}

	num_triangles := parser.int_from_string(table[1+num_points][2]);
	num_elements := 3*num_triangles;
	elements := make([]i32, num_elements);

	for line, i in table[2+num_points..2+num_points+num_triangles] {
		elements[3*i+0], elements[3*i+1], elements[3*i+2] = parser.i32_from_string(line[0]), parser.i32_from_string(line[1]), parser.i32_from_string(line[2]);
	}

	t2 := glfw.GetTime();

	edges: [dynamic]Edge;
	triangles := make([]Triangle, num_triangles);
	for i in 0..num_triangles {
		using triangle := &triangles[i];

		A, B, C = elements[3*i + 0], elements[3*i + 1], elements[3*i + 2];
		
		found_edges := 0;
		for edge, j in edges {
			if found_edges == 3 do break;

			if AB == -1 && edge.i == min(A, B) && edge.j == max(A, B) {
				AB = cast(i32)j;
				found_edges += 1;
				continue;
			}

			if BC == -1 && edge.i == min(B, C) && edge.j == max(B, C) {
				BC = cast(i32)j;
				found_edges += 1;
				continue;
			}

			if CA == -1 && edge.i == min(C, A) && edge.j == max(C, A) {
				CA = cast(i32)j;
				found_edges += 1;
				continue;
			}
		}

		if AB == -1 {
			append(&edges, Edge{i = min(A, B), j = max(A, B), t1 = i32(i)});
			AB = i32(len(edges)-1);
		}  else {
			edges[AB].t2 = cast(i32)i;
		}
		if BC == -1 {
			append(&edges, Edge{i = min(B, C), j = max(B, C), t1 = i32(i)});
			BC = i32(len(edges)-1);
		}  else {
			edges[BC].t2 = cast(i32)i;
		}
		if CA == -1 {
			append(&edges, Edge{i = min(C, A), j = max(C, A), t1 = i32(i)});
			CA = i32(len(edges)-1);
		}  else {
			edges[CA].t2 = cast(i32)i;
		}
		
		a := points[A];
		b := points[B];
		c := points[C];

        D := (a.x - c.x)*(b.y - c.y) - (b.x - c.x)*(a.y - c.y);

        r1 := points[A].r;
        r2 := points[B].r;
        r3 := points[C].r;

        x1 := points[A].x - a.x;
        x2 := points[B].x - a.x;
        x3 := points[C].x - a.x;

        y1 := points[A].y - a.y;
        y2 := points[B].y - a.y;
        y3 := points[C].y - a.y;

        c1 := r1*r1 - x1*x1 - y1*y1;
        c2 := r2*r2 - x2*x2 - y2*y2;
        c3 := r3*r3 - x3*x3 - y3*y3;

        x12 := x1 - x2;
        x21 := x2 - x1;
        x13 := x1 - x3;
        x31 := x3 - x1;
        x23 := x2 - x3;
        x32 := x3 - x2;

        y12 := y1 - y2;
        y21 := y2 - y1;
        y13 := y1 - y3;
        y31 := y3 - y1;
        y23 := y2 - y3;
        y32 := y3 - y2;

        Dxy := x1 * y23 + x2*y31 + x3*y12;

        Ax := (c1*y32 + c2*y13 + c3*y21) / (2.0 * Dxy);
        Ay := (c1*x23 + c2*x31 + c3*x12) / (2.0 * Dxy);

        Bx := (r1*y32 + r2*y13 + r3*y21) / Dxy;
        By := (r1*x23 + r2*x31 + r3*x12) / Dxy;

        R1 := r1 + Bx*(x1 - Ax) + By*(y1 - Ay);

        r := (R1 - math.sqrt( R1*R1 - (Bx*Bx + By*By - 1) * ( (x1 - Ax)*(x1 - Ax) + (y1 - Ay)*(y1 - Ay) - r1*r1 ) )) / (Bx*Bx + By*By - 1);

        R.x = a.x + Ax + r*Bx;
        R.y = a.y + Ay + r*By;
        R.r =  1.0;

        if r < 0 {
        	status = 1;
        }

	}

	num_edges := len(edges);

	for _, i in triangles {
		using tt1 := &triangles[i];

		found := false;
		for _, j in triangles {
			tt2 := &triangles[j];

			if inside_triangle(&points[tt2.A], &points[tt2.B], &points[tt2.C], &tt1.R) {
				found = true;
				break;
			}
		}
		if !found {
			status = 1;
		}
	}

	for _, i in triangles {
		using tt1 := &triangles[i];

		found := false;
		for _, j in triangles {

			tt2 := &triangles[j];
			if tt2.status == 0 && inside_triangle(&points[tt2.A], &points[tt2.B], &points[tt2.C], &tt1.R) {
				found = true;
				break;
			}
		}
		if !found {
			status = 1;
		}
	}

	to_deactivate := [...]int{4214, 4216, 4217, 748, 195, 196, 751, 4215, 4211, 4218, 5567, 752, 5557, 43, 575, /*small outer edge 1861, 3817*/};

	for i in to_deactivate {
		triangles[i].status = 1;
	}

	for _, k in edges {
		using e := &edges[k];

		q1 := points[i];
		q2 := points[j];

		dq := Point{q2.x - q1.x, q2.y - q1.y, 0.0};
		dr := math.sqrt(dq.x*dq.x + dq.y*dq.y);
		dq.x /= dr;
		dq.y /= dr;

		t := ((dr - q2.r) + q1.r)/2.0;

		M = Point{q1.x + dq.x*t, q1.y + dq.y*t, 1.0};

		q3 := M;

		if t1 == -1 || t2 == -1 do continue;
		if triangles[t1].status == 1 || triangles[t2].status == 1 do continue;
		

		p1 := triangles[t1].R;
		p2 := triangles[t2].R;
		e.O, e.U, e.c, e.r = calc_arc(Point3{cast(f64)p1.x, cast(f64)p1.y}, Point3{cast(f64)q3.x, cast(f64)q3.y}, Point3{cast(f64)p2.x, cast(f64)p2.y});
	}

	t3 := glfw.GetTime();

	fmt.println(t2-t1, t3-t2);

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
	D_prev : i32 = 0;

	enable_vsync := true;
	glfw.SwapInterval(cast(i32)enable_vsync);

	links: [dynamic]Link;
	nodes: [dynamic]Node;

	edge_to_link := make([]i32, num_edges);
	triangle_to_node := make([]i32, num_triangles);

	/*
	for i in 0..num_triangles {
		if triangles[i].status == 0 {
			append(&nodes, Node{})
			triangle_to_node[i] = l;
			l += 1;
		}
	}*/

	l : i32 = 0;
	for i in 0..num_edges {
		edge_to_link[i] = -1;
		//if (edges[i].t1 == -1 && triangles[edges[i].t2].status == 1) || (edges[i].t2 == -1 && triangles[edges[i].t1].status == 1) {
		if (edges[i].t1 == -1 && edges[i].t2 == -1) {
			// Does not exist
		} else if (edges[i].t1 == -1) {
			// Does not exist
		} else if (edges[i].t2 == -1) {
			if (triangles[edges[i].t1].status == 0) {
				// outlet or inlet
				edge_to_link[i] = l;
				l += 1;
			} else {
				// Discarded edge
			}
		} else if (triangles[edges[i].t1].status == 1 && triangles[edges[i].t2].status == 1) {
			// Discarded edge
		} else {
			edge_to_link[i] = l;
			l += 1;
			//append(&links, Link{})
		}
	}

	l1 : i32 = 0;
	for i in 0..num_triangles {
		if triangles[i].status == 0 {
			triangle_to_node[i] = l1;
			l1 += 1;
			append(&nodes, Node{[3]i32{edge_to_link[triangles[i].AB], edge_to_link[triangles[i].BC], edge_to_link[triangles[i].CA]}, triangles[i].R.x, triangles[i].R.y, 0});
		}
	}

	l2 : i32 = 0;
	for k in 0..num_edges {
		using e := &edges[k];
		//if (edges[i].t1 == -1 && triangles[edges[i].t2].status == 1) || (edges[i].t2 == -1 && triangles[edges[i].t1].status == 1) {
		if (edges[k].t1 == -1 && edges[k].t2 == -1) {
			// Does not exist
		} else if (edges[k].t1 == -1) {
			// Does not exist
		} else if (edges[k].t2 == -1) {
			if (triangles[edges[k].t1].status == 0) {
				// outlet or inlet
				// create new node and make it position be reflected around i-j edge
				dx := points[j].x - points[i].x;
				dy := points[j].y - points[i].y;
				dr := math.sqrt(dx*dx + dy*dy);
				dx /= dr;
				dy /= dr;

				dx1, dy1: f32;
				
				dx1 = triangles[t1].R.x - points[i].x;
				dy1 = triangles[t1].R.y - points[i].y;
				
				d := dx1*dx + dy1*dy;
				xx := points[i].x + 2.0*d*dx - dx1;
				yy := points[i].y + 2.0*d*dy - dy1;
				//fmt.println(k, xx, yy, triangles[edges[]]);


				n : i32 = abs(xx - 1000) < 300 && abs(yy - 1000) < 300 ? 2 : 1;


				p1 := triangles[t1].R;
				p2 := Point{xx, yy, 1.0};
				q3 := M;
				e.O, e.U, e.c, e.r = calc_arc(Point3{cast(f64)p1.x, cast(f64)p1.y}, Point3{cast(f64)q3.x, cast(f64)q3.y}, Point3{cast(f64)p2.x, cast(f64)p2.y});


				append(&links, Link{cast(i32)len(nodes), triangle_to_node[t1],  i, j,  M.x, M.y,  c,  U.x, U.y, O.x, O.y,  r, n});
				append(&nodes, Node{[3]i32{cast(i32)len(links)-1, -1, -1}, xx, yy, n});
			} else {
				// Discarded edge
			}
		} else if (triangles[edges[k].t1].status == 1 && triangles[edges[k].t2].status == 1) {
			// Discarded edge
		} else {
			if (triangles[edges[k].t1].status != triangles[edges[k].t2].status) {
				dx := points[j].x - points[i].x;
				dy := points[j].y - points[i].y;
				dr := math.sqrt(dx*dx + dy*dy);
				dx /= dr;
				dy /= dr;

				dx1, dy1: f32;
				if triangles[edges[k].t1].status == 1 {
					dx1 = triangles[t2].R.x - points[i].x;
					dy1 = triangles[t2].R.y - points[i].y;
				} else {
					dx1 = triangles[t1].R.x - points[i].x;
					dy1 = triangles[t1].R.y - points[i].y;
				}
				d := dx1*dx + dy1*dy;
				xx := points[i].x + 2.0*d*dx - dx1;
				yy := points[i].y + 2.0*d*dy - dy1;

				n : i32 = abs(xx - 1000) < 300 && abs(yy - 1000) < 300 ? 2 : 1;

				p2 := triangles[t1].R;
				p1 := Point{xx, yy, 1.0};
				q3 := M;
				e.O, e.U, e.c, e.r = calc_arc(Point3{cast(f64)p1.x, cast(f64)p1.y}, Point3{cast(f64)q3.x, cast(f64)q3.y}, Point3{cast(f64)p2.x, cast(f64)p2.y});


				t := triangles[t1].status == 1 ? triangle_to_node[t2] : triangle_to_node[t1];
				append(&links, Link{cast(i32)len(nodes), t,  i, j,  M.x, M.y,  c,  U.x, U.y, O.x, O.y,  r, n});
				append(&nodes, Node{[3]i32{cast(i32)len(links)-1, -1, -1}, xx, yy, n});
			} else {
				append(&links, Link{triangle_to_node[t1], triangle_to_node[t2],  i, j,  M.x, M.y,  c, U.x, U.y, O.x, O.y,  r, 0});
				//fmt.println(k, t1, t2, triangles[t1].status, triangles[t2].status, triangle_to_node[t1], triangle_to_node[t2], 0);
			}
			//append(&links, Link{})
		}
	}

	m := 1.0e9;
	for l in links {
		fmt.printf("%.16f\n", l.c);
		m = min(m, l.c);
	}
	fmt.printf("%.15f\n", m);
	/*
	*/

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




	fmt.println(size_of([vector 2]f32));
	fmt.println(size_of(Vec2f));
	fmt.println(size_of(Vec2d));


	// main loop
	for glfw.WindowShouldClose(window) == glfw.FALSE {
		//break;
		// show fps in window title
		glfw.calculate_frame_timings(window);
		
		// listen to inut
		glfw.PollEvents();

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

		zoom_factor := cast(f32)math.pow(0.95, scroll_dy);

		xend := f32(f64(x) + mouse_x*f64(dx)/resx);           // convert screen position to world cooridnates
		yend := f32(f64(y) + (resy - mouse_y)*f64(dy)/resy);   
		x = (1.0-zoom_factor)*xend + zoom_factor*x;       // update lower left corner
		y = (1.0-zoom_factor)*yend + zoom_factor*y;

		dx *= zoom_factor;
		dy *= zoom_factor;

		
		chosen_triangle := -1;
		p := Point{xend, yend, 0.0};
		for t, i in triangles {
			if inside_triangle(&points[t.A], &points[t.B], &points[t.C], &p) {
				chosen_triangle = i;
				break;
			}
		}

		chosen_link := -1;
		for l, i in links {
			if l.front == -1 do continue;
			p1 := points[l.left];
			p2 := Point{nodes[l.front].x, nodes[l.front].y, 1.0};
			p3 := Point{nodes[l.back].x, nodes[l.back].y, 1.0};
			p4 := points[l.right];
			if inside_triangle(&p1, &p2, &p3, &p) || inside_triangle(&p2, &p3, &p4, &p) {
				chosen_link = i;
				break;
			}
		}

		approx_distance: f64;
		closest_distance: f64;
		closest_point: Vec2d;

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
				O := Vec2d{cast(f64)links[chosen_link].Cx, cast(f64)links[chosen_link].Cy};
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

			fmt.println(rA, rB, rC, closest_distance, math.mag(closest_point - P1) - R1, math.mag(closest_point - P2) - R2, R);

			if R <= 6.6e4 {
				O := Vec2d{cast(f64)links[chosen_link].Cx, cast(f64)links[chosen_link].Cy};
				P := closest_point;
				OA := math.norm0(A - O);
				OC := math.norm0(C - O);
				OP := math.norm0(P - O);

				a1 := acos_near_one_13(OA.x*OP.x + OA.y*OP.y);
				a2 := acos_near_one_13(OA.x*OC.x + OA.y*OC.y);
				fmt.println(a1*180.0/math.PI, a2*180.0/math.PI, a1/a2);
			} else {

			}
		}

		if (glfw.GetKey(window, glfw.KEY_TAB) == glfw.PRESS && TAB_prev == glfw.RELEASE) {
			enable_vsync = !enable_vsync;
			glfw.SwapInterval(cast(i32)enable_vsync);
		}

		if (glfw.GetKey(window, glfw.KEY_F5) == glfw.PRESS && F5_prev == glfw.RELEASE) {
			new_program, success := gl.load_shaders("shaders/shader_delaunay.vs", "shaders/shader_delaunay.fs");
			if success {
				gl.DeleteProgram(program);
				program = new_program;
			}
		}

		when ODIN_OS == "windows" {
			current_vertex_time := os.last_write_time_by_name("shaders/shader_delaunay.vs");
			current_fragment_time := os.last_write_time_by_name("shaders/shader_delaunay.fs");

			if (current_vertex_time != last_vertex_time || current_fragment_time != last_fragment_time) {
				new_program, success := gl.load_shaders("shaders/shader_delaunay.vs", "shaders/shader_delaunay.fs");
				if success {
					gl.DeleteProgram(program);
					program = new_program;
					fmt.println("Updated shaders");
				} else {
					fmt.println("Failed to update shaders");
				}
			}

			last_vertex_time = current_vertex_time;
			last_fragment_time = current_fragment_time;
		}


		if (glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS && D_prev == glfw.RELEASE) {
			


			fmt.println("D pressed");


			// Disk points
			fmt.println("disk_points float", num_points, 3);
			for i in 0..num_points {
				//fmt.printf("    %.10f %.10f %.10f\n", points[i].x, points[i].y, points[i].r);
			}
			fmt.println();

			fmt.println("disk_points float", num_points, 3);


			clear(&links);
			clear(&nodes);


		}


		// update old input state
		mouse_x_prev, mouse_y_prev = mouse_x, mouse_y;
		scroll_x_prev, scroll_y_prev = scroll_x, scroll_y;
		for i in 0..5 do mouse_button_prev[i] = mouse_button[i];
		F5_prev = glfw.GetKey(window, glfw.KEY_F5);
		TAB_prev = glfw.GetKey(window, glfw.KEY_TAB);
		D_prev = glfw.GetKey(window, glfw.KEY_D);

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
		//gl.Uniform2f(get_uniform_location(program, "mouse_pos\x00"), cast(f32)(links[chosen_link].Cx), cast(f32)(links[chosen_link].Cy));   
		gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(closest_distance));   
		//gl.Uniform1f(get_uniform_location(program, "mouse_radius\x00"), cast(f32)(links[chosen_link].Cr));   


		gl.BindVertexArray(vao);
        

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
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(5));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(5));
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, cast(i32)1);     

		
		colors_font := font.get_colors();
		for i in 0..4 do colors_font[i] = font.Vec4{0.0, 0.0, 0.0, 1.0};
		
		font.update_colors(4);

		//font.draw_format(0.0, 0.0, 16.0, "blehh %d %f: %s", 2, 3.14, "blah");
		//font.draw_format(0.0, 0.0, 20.0, "mousepos = (%f, %f)", xend, yend);
		//font.draw_format(0.0, 0.0, 20.0, "mousepos");

		glfw.SwapBuffers(window);
	}
	/*
	*/
}

calc_arc :: proc(a, b, c: Point3) -> (Point, Point, f64, f32) {
	if !is_ccw(Point{cast(f32)a.x, cast(f32)a.y, 1.0}, Point{cast(f32)b.x, cast(f32)b.y, 1.0}, Point{cast(f32)c.x, cast(f32)c.y, 1.0}) {
		//b, c = c, b;
	}

    D := (a.x - c.x)*(b.y - c.y) - (b.x - c.x)*(a.y - c.y);
    O: Point3;
    O.x = (((a.x - c.x) * (a.x + c.x) + (a.y - c.y) * (a.y + c.y)) / 2 * (b.y - c.y) -  ((b.x - c.x) * (b.x + c.x) + (b.y - c.y) * (b.y + c.y)) / 2 * (a.y - c.y)) / D;
    O.y = (((b.x - c.x) * (b.x + c.x) + (b.y - c.y) * (b.y + c.y)) / 2 * (a.x - c.x) -  ((a.x - c.x) * (a.x + c.x) + (a.y - c.y) * (a.y + c.y)) / 2 * (b.x - c.x)) / D;

    d1 := Point3{ a.x - O.x, a.y - O.y };
    //d1 := Point3{ f64(e.U.x), f64(e.U.y) };
    d1.x, d1.y = d1.x/math.sqrt(d1.x*d1.x + d1.y*d1.y), d1.y/math.sqrt(d1.x*d1.x + d1.y*d1.y);
    
    d2 := Point3{ c.x - O.x, c.y - O.y };
    d2.x, d2.y = d2.x/math.sqrt(d2.x*d2.x + d2.y*d2.y), d2.y/math.sqrt(d2.x*d2.x + d2.y*d2.y);
	
	U := Point{0.5*f32(d1.x + d2.x), 0.5*f32(d1.y + d2.y), 0.0};

	U.x, U.y = U.x/math.sqrt(U.x*U.x + U.y*U.y), U.y/math.sqrt(U.x*U.x + U.y*U.y);

    d := f64(U.x)*d2.x + f64(U.y)*d2.y;

    r := math.sqrt((O.x - a.x)*(O.x - a.x) + (O.y - a.y)*(O.y - a.y));

	Oo := Point{cast(f32)O.x, cast(f32)O.y, 1.0};
	cc := d;
	rr := cast(f32)r;

	return Oo, U, cc, rr;
}

// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, &str[0]);;
}


is_ccw :: proc(A, B, C: Point) -> bool {
	area : f32 = 0.0;
    area += (B.x - A.x)*(B.y + A.y);
    area += (C.x - B.x)*(C.y + B.y);
    area += (A.x - C.x)*(A.y + C.y);

    return area > 0.0;
}

inside_triangle :: proc(A, B, C: ^Point, p: ^Point) -> bool {

	alpha := ((B.y - C.y)*(p.x - C.x) + (C.x - B.x)*(p.y - C.y)) / ((B.y - C.y)*(A.x - C.x) + (C.x - B.x)*(A.y - C.y));
    beta  := ((C.y - A.y)*(p.x - C.x) + (A.x - C.x)*(p.y - C.y)) / ((B.y - C.y)*(A.x - C.x) + (C.x - B.x)*(A.y - C.y));
    gamma := 1.0 - alpha - beta;

    return (alpha >= -1e-9 && beta >= -1e-9 && gamma >= -1e-9);
}

Vec2f :: [vector 2]f32;
Vec2d :: [vector 2]f64;


Point :: struct #ordered { // 12 bytes
	x, y, r: f32;
};

Point3 :: struct #ordered {
	x, y: f64;
}

Edge :: struct #ordered { // 16 bytes
	i, j: i32;
	t1, t2: i32 = -1, -1;
	M: Point;
	O: Point;
	U: Point;
	a: f32;
	c: f64;
	r: f32;
};

Triangle :: struct #ordered { // 36 bytes
	A, B, C: i32;
	AB, BC, CA: i32 = -1, -1, -1;
	O: Point;
	CM: Point;
	R: Point;
	status: i32 = 0;
};

Disk :: struct #ordered {
	x, y, r: f32;
}

Node :: struct #ordered {
	links: [3]i32;
	x, y:     f32;
	t:     	i32;
};


Link :: struct #ordered {
	front:  i32; // Node
	back:   i32; // Node
	left:   i32; // Disk
	right:  i32; // Disk
	x, y:   f32; // Center of link along arc
	c:      f64; // Cosine of half angle of arc, needs the precision
	Ux, Uy: f32; // Direction of center of arc
	Cx, Cy: f32; // Position of origin of arc
	Cr:     f32; // Radius of curvature of arc
	t:   i32;
};

atan2 :: proc(y, x: f32) -> f32 {
    MASK :: u32(0x8000_0000);
    MAGIC :: f32(0.596227);

    ux_s := MASK & transmute(u32)x;
    uy_s := MASK & transmute(u32)y;

    q := transmute(f32)((~ux_s & uy_s) >> 29 | (ux_s >> 30));

    bxy_a := abs(MAGIC * x * y);
    num := bxy_a + y * y;
    atan_1q := num / (x * x + bxy_a + num);

    uatan_2q := (ux_s ~ uy_s) | transmute(u32)atan_1q;
    return (math.PI/2.0)*(q + transmute(f32)uatan_2q);
}

foreign_system_library m   "m";

foreign m {
	acos :: proc(x: f64) -> f64  #link_name "acos" ---;
}

acos_near_one :: proc(x: f64) -> f64 {
	A :: math.SQRT_TWO;
	B :: 1.0/(6.0*A);
	C :: 3.0/(80.0*A);
	D :: 5.0/(448.0*A);
	E :: 35.0/(9216.0*A);

	y1 := math.sqrt(1.0 - x);
	return A*y1;                             // max error 6.768e-03 degrees in interval [0.99, 1.00]
	/*
	y2 := y1*y1;
	y3 := y1*y2;
	return A*y1 + B*y3;                      // max error 1.524e-05 degrees in interval [0.99, 1.00]

	y5 := y3*y2;
	return A*y1 + B*y3 + C*y5;               // max error 4.537e-08 degrees in interval [0.99, 1.00]

	y7 := y5*y2;
	return A*y1 + B*y3 + C*y5 + D*y7;        // max error 1.544e-10 degrees in interval [0.99, 1.00]

	y9 := y7*y2;
	return A*y1 + B*y3 + C*y5 + D*y7 + E*y9; // max error 5.677e-13 degrees in interval [0.99, 1.00]
	*/
}
