import "core:fmt.odin";
import "core:mem.odin";
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

temp_log: [dynamic]string;

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
		points[i] = Point{Vec2f{parser.f32_from_string(line[0]), parser.f32_from_string(line[1])}, parser.f32_from_string(line[2]), 0};
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

        D := f64(a.x - c.x)*f64(b.y - c.y) - f64(b.x - c.x)*f64(a.y - c.y);

        r1 := f64(points[A].r);
        r2 := f64(points[B].r);
        r3 := f64(points[C].r);

        x1 := f64(points[A].x - a.x);
        x2 := f64(points[B].x - a.x);
        x3 := f64(points[C].x - a.x);

        y1 := f64(points[A].y - a.y);
        y2 := f64(points[B].y - a.y);
        y3 := f64(points[C].y - a.y);

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

        R.x = f32(f64(a.x) + Ax + r*Bx);
        R.y = f32(f64(a.y) + Ay + r*By);
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

	to_deactivate := [...]int{4214, 4216, 4217, 748, 195, 196, 751, 4215, 4211, 4218, 5567, 752, 5557, 43, 575, /*small outer edge*/1861};

	for i in to_deactivate {
		triangles[i].status = 1;
	}

	for _, k in edges {
		using e := &edges[k];

		q1 := points[i];
		q2 := points[j];

		dq := Point{Vec2f{q2.x - q1.x, q2.y - q1.y}, 0.0, 0.0};
		dr := math.sqrt(dq.x*dq.x + dq.y*dq.y);
		dq.x /= dr;
		dq.y /= dr;

		t := ((dr - q2.r) + q1.r)/2.0;

		M = Point{Vec2f{q1.x + dq.x*t, q1.y + dq.y*t}, 1.0, 0.0};

		q3 := M;

		if t1 == -1 || t2 == -1 do continue;
		if triangles[t1].status == 1 || triangles[t2].status == 1 do continue;
		

		p1 := triangles[t1].R;
		p2 := triangles[t2].R;
		e.O, e.U, e.c, e.r = calc_arc(Vec3d{cast(f64)p1.x, cast(f64)p1.y}, Vec3d{cast(f64)q3.x, cast(f64)q3.y}, Vec3d{cast(f64)p2.x, cast(f64)p2.y});
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
			append(&nodes, Node{[3]i32{edge_to_link[triangles[i].AB], edge_to_link[triangles[i].BC], edge_to_link[triangles[i].CA]}, 0, Vec2f{triangles[i].R.x, triangles[i].R.y}});
		}
	}



	circle_circle_intersection :: proc(p0, p1: Vec2d, r0, r1: f64) -> (p3, p3_: Vec2d, success: bool) {
		dp := p1 - p0;
		d := math.mag(dp);
		if d > (r0 + r1) {
			return Vec2d{}, Vec2d{}, false;
		}

		if d < abs(r0 - r1) {
			return Vec2d{}, Vec2d{}, false;
		}

		a := ((r0*r0) - (r1*r1) + (d*d)) / (2.0 * d);

		p2 := p0 + dp*(a/d);

		h := math.sqrt(r0*r0 - a*a);

		r := Vec2d{-dp.y * (h/d), dp.x * (h/d)};

		return p2 + r, p2 - r, true;


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

				{
					P1 := Vec2d{cast(f64)triangles[t1].R.x, cast(f64)triangles[t1].R.y};
					P2 := Vec2d{cast(f64)xx, cast(f64)yy};

					p1 := Vec2d{cast(f64)points[i].x, cast(f64)points[i].y};
					p2 := Vec2d{cast(f64)points[j].x, cast(f64)points[j].y};
					r1 := math.mag(p2 - p1) - cast(f64)points[j].r;
					r2 := math.mag(p2 - p1) - cast(f64)points[i].r;

					p3, p3_, success := circle_circle_intersection(p1, p2, r1, r2);

					d1 := math.mag(p3 - P2);
					d2 := math.mag(p3_ - P2);

					if math.mag(Vec2d{cast(f64)xx, cast(f64)yy} - Vec2d{cast(f64)triangles[t1].R.x, cast(f64)triangles[t1].R.y}) < f64(dr - points[i].r - points[j].r)/2.0 {
						if d1 < d2 {
							xx, yy = cast(f32)p3.x, cast(f32)p3.y;
						} else {
							xx, yy = cast(f32)p3_.x, cast(f32)p3_.y;
						}
					}
					//fmt.println("qweqwe", p3, p3_, math.mag(p3_ - P2), math.mag(p3 - P2));

				}
				n : i32 = abs(xx - 1000) < 300 && abs(yy - 1000) < 300 ? 1 : 2;

				p1 := triangles[t1].R;
				p2 := Point{Vec2f{xx, yy}, 1.0, 0.0};
				q3 := M;
				e.O, e.U, e.c, e.r = calc_arc(Vec3d{cast(f64)p1.x, cast(f64)p1.y}, Vec3d{cast(f64)q3.x, cast(f64)q3.y}, Vec3d{cast(f64)p2.x, cast(f64)p2.y});


				append(&links, Link{cast(i32)len(nodes), triangle_to_node[t1],  i, j,  Vec2f{M.x, M.y}, Vec2f{O.x, O.y}, Vec2f{U.x, U.y}, c, r, n});
				append(&nodes, Node{[3]i32{cast(i32)len(links)-1, -1, -1}, n, Vec2f{xx, yy}});
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

				n : i32 = abs(xx - 1000) < 300 && abs(yy - 1000) < 300 ? 1 : 2;

				p2 := triangles[triangles[edges[k].t1].status == 1 ? t2 : t1].R;
				p1 := Point{Vec2f{xx, yy}, 1.0, 0.0};
				q3 := M;

				dr11 := math.mag(Vec2d{f64(p1.x - points[i].x), f64(p1.y - points[i].y)});
				dr12 := math.mag(Vec2d{f64(p1.x - points[j].x), f64(p1.y - points[j].y)});
				dr21 := math.mag(Vec2d{f64(p2.x - points[i].x), f64(p2.y - points[i].y)});
				dr22 := math.mag(Vec2d{f64(p2.x - points[j].x), f64(p2.y - points[j].y)});
				//fmt.println(dr11, dr12, dr21, dr22, p1, p2, points[i], points[j]);



				{
					t := triangles[edges[k].t1].status == 1 ? t2 : t1;
					P1 := Vec2d{cast(f64)triangles[t].R.x, cast(f64)triangles[t].R.y};
					P2 := Vec2d{cast(f64)xx, cast(f64)yy};

					p1 := Vec2d{cast(f64)points[i].x, cast(f64)points[i].y};
					p2 := Vec2d{cast(f64)points[j].x, cast(f64)points[j].y};
					r1 := math.mag(p2 - p1) - cast(f64)points[j].r;
					r2 := math.mag(p2 - p1) - cast(f64)points[i].r;

					p3, p3_, success := circle_circle_intersection(p1, p2, r1, r2);

					d1 := math.mag(p3 - P2);
					d2 := math.mag(p3_ - P2);

					if math.mag(Vec2d{cast(f64)xx, cast(f64)yy} - Vec2d{cast(f64)triangles[t].R.x, cast(f64)triangles[t].R.y}) < f64(dr - points[i].r - points[j].r)/2.0 {
						if d1 < d2 {
							xx, yy = cast(f32)p3.x, cast(f32)p3.y;
						} else {
							xx, yy = cast(f32)p3_.x, cast(f32)p3_.y;
						}
					}

					//fmt.println("asdasd", p3, p3_, math.mag(p3_ - P2), math.mag(p3 - P2));
				}

				e.O, e.U, e.c, e.r = calc_arc(Vec3d{cast(f64)p1.x, cast(f64)p1.y}, Vec3d{cast(f64)q3.x, cast(f64)q3.y}, Vec3d{cast(f64)p2.x, cast(f64)p2.y});


				t := triangles[t1].status == 1 ? triangle_to_node[t2] : triangle_to_node[t1];
				append(&links, Link{cast(i32)len(nodes), t,  i, j,  Vec2f{M.x, M.y}, Vec2f{O.x, O.y}, Vec2f{U.x, U.y}, c, r, n});
				append(&nodes, Node{[3]i32{cast(i32)len(links)-1, -1, -1}, n, Vec2f{xx, yy}});
			} else {
				append(&links, Link{triangle_to_node[t1], triangle_to_node[t2],  i, j,  Vec2f{M.x, M.y}, Vec2f{O.x, O.y}, Vec2f{U.x, U.y}, c, r, 0});
				//fmt.println(k, t1, t2, triangles[t1].status, triangles[t2].status, triangle_to_node[t1], triangle_to_node[t2], 0);
			}
			//append(&links, Link{})
		}
	}

	m := 1.0e9;
	for l in links {
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


	cx, cy := 1080.0, 1020.0;

	for i in 0..num_links {
		d1 := math.mag(Vec2d{cast(f64)nodes[links[i].back].x  - cx, cast(f64)nodes[links[i].back].y  - cy});
		d2 := math.mag(Vec2d{cast(f64)nodes[links[i].front].x - cx, cast(f64)nodes[links[i].front].y - cy});
		if d1 > d2 {
			links[i].back, links[i].front = links[i].front, links[i].back;
		}
	}


	append_to_log :: proc(log: ^$T/[dynamic]string, fmt_string: string, vals: ...any) {
		a := fmt.aprintf(fmt_string, ...vals);
		append(log, a);
	}

	t1 = glfw.GetTime();

	// main loop
	for glfw.WindowShouldClose(window) == glfw.FALSE {
		for _, i in temp_log {
			free(temp_log[i]);
		}
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

		x += f32(0.3*f64(dx)*dt * f64(glfw.GetKey(window, glfw.KEY_D) - glfw.GetKey(window, glfw.KEY_A)));
		y += f32(0.3*f64(dy)*dt * f64(glfw.GetKey(window, glfw.KEY_W) - glfw.GetKey(window, glfw.KEY_S)));

		zoom_factor := cast(f32)math.pow(0.95, scroll_dy);

		xend := f32(f64(x) + mouse_x*f64(dx)/resx);           // convert screen position to world cooridnates
		yend := f32(f64(y) + (resy - mouse_y)*f64(dy)/resy);   
		x = (1.0-zoom_factor)*xend + zoom_factor*x;       // update lower left corner
		y = (1.0-zoom_factor)*yend + zoom_factor*y;

		dx *= zoom_factor;
		dy *= zoom_factor;


		append_to_log(&temp_log, "mousepos = {%.1f, %.1f}", xend, yend);

		
		chosen_triangle := -1;
		p := Point{Vec2f{xend, yend}, 0.0, 0.0};
		for t, i in triangles {
			if inside_triangle(&points[t.A], &points[t.B], &points[t.C], &p) {
				chosen_triangle = i;
				break;
			}
		}
		if chosen_triangle != -1 {
			append_to_log(&temp_log, "chosen triangle =  %d, points = %d %d %d", chosen_triangle, triangles[chosen_triangle].A, triangles[chosen_triangle].B, triangles[chosen_triangle].C);

		}

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


		coeffs_from_link :: proc(links: [dynamic]Link, nodes: [dynamic]Node, points: []Point, chosen_link: int) -> [5]f64 {
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
 
 		approx_distance: f64;
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

			e := -1;
			for e, i in edges {
				if edge_to_link[i] == cast(i32)chosen_link {
					append_to_log(&temp_log, "link %d chosen, corresponding to edge %d", chosen_link, i);
					break;
				}
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




		if (glfw.GetKey(window, glfw.KEY_F) == glfw.PRESS && F_prev == glfw.RELEASE) {
			


			fmt.println("F pressed");

			data := make([]u8, 8*3 + len(points)*size_of(Point) + len(links)*size_of(Link) + len(nodes)*size_of(Node));
			defer free(data);

			(cast(^int)&data[0])^ = len(points);
			(cast(^int)&data[8])^ = len(nodes);
			(cast(^int)&data[16])^ = len(links);

			s0 := 8*3;
			s1 := s0 + len(points)*size_of(Point);
			s2 := s1 + len(nodes)*size_of(Node);
			points2 := mem.slice_ptr(cast(^Point)&data[s0], len(points));
			nodes2  := mem.slice_ptr(cast(^Node)&data[s1], len(nodes));
			links2  := mem.slice_ptr(cast(^Link)&data[s2], len(links));

			for p, i in points do points2[i] = p;
			for n, i in nodes do nodes2[i] = n;
			for l, i in links do links2[i] = l;

			fmt.println(os.write_entire_file("extra/stuff.bin", data));
			
			/*
			when ODIN_OS == "linux" {
				min_x, min_y, min_z := +1.0e9, +1.0e9, +1.0e9;
				max_x, max_y, max_z := -1.0e9, -1.0e9, -1.0e9;
				for node in nodes {
					min_x, min_y, min_z = min(min_x, cast(f64)node.x), min(min_y, cast(f64)node.y), min(min_z, cast(f64)0.0);
					max_x, max_y, max_z = max(max_x, cast(f64)node.x), max(max_y, cast(f64)node.y), max(max_z, cast(f64)0.0);
				}
				Lx, Ly, Lz := max_x - min_x, max_y - min_y, max_z - min_z;

				num_links := len(links);
				num_nodes := len(nodes);

				num_neighbours := make([]i32, num_nodes); defer free(num_neighbours);
				
				max_neighbours := 3;
				total_neighbours : i32 = 0;
				for node, i in nodes {
					num_neighbours[i] = (node.t == 0 ? 3 : 1);
					total_neighbours += num_neighbours[i];

				}

				node_neighbours := make([]i32, total_neighbours); defer free(node_neighbours);
				link_neighbours := make([]i32, total_neighbours); defer free(link_neighbours);
				node_type       := make([]i32, num_nodes);        defer free(node_type);

				node_positions := make([]f64, 3*num_nodes); defer free(node_positions);

				total_neighbours = 0;
				for node, i in nodes {
					for j in 0..(node.t == 0 ? 3 : 1) {
						link_neighbours[total_neighbours] = node.links[j];

						if links[node.links[j]].front == cast(i32)i {
							node_neighbours[total_neighbours] = links[node.links[j]].back;
						} else if links[node.links[j]].back == cast(i32)i {
							node_neighbours[total_neighbours] = links[node.links[j]].front;
						} else {
							assert(false);
						}

						total_neighbours += 1;
					}
					node_type[i] = node.t;
					node_positions[3*i+0], node_positions[3*i+1], node_positions[3*i+2] = cast(f64)node.x/1207.0, cast(f64)node.y/1207.0, 0.0;
				}


				node_front  := make([]i32, num_links); defer free(node_front);
				node_back   := make([]i32, num_links); defer free(node_back);
				link_type   := make([]i32, num_links); defer free(link_type);
				link_radius := make([]f64, num_links); defer free(link_radius);
				link_length := make([]f64, num_links); defer free(link_length);


				for link, i in links {
					node_front[i] = link.front;
					node_back[i] = link.back;
					link_type[i] = link.t;

					dx := nodes[link.front].x - nodes[link.back].x;
					dy := nodes[link.front].y - nodes[link.back].y;
					dr := math.sqrt(dx*dx + dy*dy);
					link_length[i] = cast(f64)dr*(54.0/1000.0);

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
						L := link_length[i];

						fmt.println(i, math.sqrt(V/L/(math.PI)), A/L, A/L/0.1);
						link_radius[i] = A/L/2.0;
					}
				}
				/*
				save_network("network_test.bin", 
						 num_links, num_nodes, total_neighbours, max_neighbours: i32,
						 Lx, Ly, Lz: f64, 
						 num_neighbours, node_neighbours, link_neighbours, node_front, node_back, node_type, link_type: []i32,
						 link_radius, link_length, node_positions: []f64);
				*/
			}
			*/	

		}


		// update old input state

		mouse_x_prev, mouse_y_prev = mouse_x, mouse_y;
		scroll_x_prev, scroll_y_prev = scroll_x, scroll_y;
		for i in 0..5 do mouse_button_prev[i] = mouse_button[i];
		F5_prev = glfw.GetKey(window, glfw.KEY_F5);
		TAB_prev = glfw.GetKey(window, glfw.KEY_TAB);
		F_prev = glfw.GetKey(window, glfw.KEY_F);

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
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), i32(5));
        gl.Uniform1i(get_uniform_location(program, "shade_mode\x00"), i32(5));
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


NetworkHeader :: struct #ordered {
    checksum: u32,       // Adler32 checksum of raw binary network data
    size: i32,            // how many bytes of raw binary data after header
    num_nodes: i32,
    num_links: i32,
    max_neighbours: i32,
    total_neighbours: i32,
    Lx: f64,                // size of system in x, y and z direction
    Ly: f64,
    Lz: f64,
    // XX bytes
};


save_network :: proc(filename: string, 
					 num_links, num_nodes, total_neighbours, max_neighbours: i32,
					 Lx, Ly, Lz: f64, 
					 num_neighbours, node_neighbours, link_neighbours, node_front, node_back, node_type, link_type: []i32,
					 link_radius, link_length, node_positions: []f64) {

}


calc_arc :: proc(a, b, c: Vec3d) -> (Point, Point, f64, f32) {
	if !is_ccw(Point{Vec2f{cast(f32)a.x, cast(f32)a.y}, 1.0, 0.0}, Point{Vec2f{cast(f32)b.x, cast(f32)b.y}, 1.0, 0.0}, Point{Vec2f{cast(f32)c.x, cast(f32)c.y}, 1.0, 0.0}) {
		//b, c = c, b;
	}

    D := (a.x - c.x)*(b.y - c.y) - (b.x - c.x)*(a.y - c.y);
    O: Vec3d;
    O.x = (((a.x - c.x) * (a.x + c.x) + (a.y - c.y) * (a.y + c.y)) / 2 * (b.y - c.y) -  ((b.x - c.x) * (b.x + c.x) + (b.y - c.y) * (b.y + c.y)) / 2 * (a.y - c.y)) / D;
    O.y = (((b.x - c.x) * (b.x + c.x) + (b.y - c.y) * (b.y + c.y)) / 2 * (a.x - c.x) -  ((a.x - c.x) * (a.x + c.x) + (a.y - c.y) * (a.y + c.y)) / 2 * (b.x - c.x)) / D;

    d1 := Vec3d{ a.x - O.x, a.y - O.y };
    d1.x, d1.y = d1.x/math.sqrt(d1.x*d1.x + d1.y*d1.y), d1.y/math.sqrt(d1.x*d1.x + d1.y*d1.y);
    
    d2 := Vec3d{ c.x - O.x, c.y - O.y };
    d2.x, d2.y = d2.x/math.sqrt(d2.x*d2.x + d2.y*d2.y), d2.y/math.sqrt(d2.x*d2.x + d2.y*d2.y);
	
	U := Vec3d{0.5*(d1.x + d2.x), 0.5*(d1.y + d2.y)};

	U.x, U.y = U.x/math.sqrt(U.x*U.x + U.y*U.y), U.y/math.sqrt(U.x*U.x + U.y*U.y);

    d := f64(U.x)*d2.x + f64(U.y)*d2.y;

    r := math.sqrt((O.x - a.x)*(O.x - a.x) + (O.y - a.y)*(O.y - a.y));

	Oo := Point{Vec2f{cast(f32)O.x, cast(f32)O.y}, 1.0, 0.0};
	cc := d;
	rr := cast(f32)r;

	return Oo, Point{Vec2f{f32(U.x), f32(U.y)}, 1.0, 0.0}, cc, rr;
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
	using xy: Vec2f,
	r: f32,
	pad := f32(0.0), // pad, so we can use vec2 in shader
};


Vec3d :: [vector 2]f64;

Edge :: struct #ordered { // 16 bytes
	i, j: i32,
	t1: i32 = -1,
	t2: i32 = -1,
	M: Point,
	O: Point,
	U: Point,
	a: f32,
	c: f64,
	r: f32,
};

Triangle :: struct #ordered { // 36 bytes
	A, B, C: i32,
	AB: i32 = -1,
	BC: i32 = -1,
	CA: i32 = -1,
	O: Point,
	CM: Point,
	R: Point,
	status: i32 = 0,
};

Disk :: struct #ordered {
	x, y, r: f32,
}

Node :: struct #ordered {
	links: [3]i32,
	t:     	i32,
	using xy: Vec2f,
};


Link :: struct #ordered {
	front:  i32, // Node
	back:   i32, // Node
	left:   i32, // Disk
	right:  i32, // Disk
	P: Vec2f, // Center of link along arc
	O: Vec2f, // Position of origin of arc
	U: Vec2f, // Direction of center of arc
	c:      f64, // Cosine of half angle of arc, needs the precision
	Cr:     f32, // Radius of curvature of arc
	t:   i32,
};

when ODIN_OS == "linux" {
	foreign_system_library m "m";
} else {
	foreign_system_library m "libcmt.lib";
}

foreign m {
	acos :: proc(x: f64) -> f64  #link_name "acos" ---;
}

