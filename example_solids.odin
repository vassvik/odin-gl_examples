    
import    "core:fmt.odin";
import    "core:strings.odin";
import    "core:math.odin";
import    "shared:odin-glfw/glfw.odin";
import    "shared:odin-gl/gl.odin";
import    "shared:odin-gl_font/font.odin";

// from www.paulbourke.net/geometry/platonic/
at :: 0.5;
tetrahedron_vertices := [...]Vec3 {
    { at,  at,  at},   {-at,  at, -at},   { at, -at, -at},
    {-at,  at, -at},   {-at, -at,  at},   { at, -at, -at},
    { at,  at,  at},   { at, -at, -at},   {-at, -at,  at},
    { at,  at,  at},   {-at, -at,  at},   {-at,  at, -at},
}; 

ao :: 1.0/(2.0*math.SQRT_TWO);
bo :: 0.5;
octahedron_vertices := [...]Vec3 {
    {-ao,  0,  ao},   {-ao,  0, -ao},    {0,  bo,  0},
    {-ao,  0, -ao},   { ao,  0, -ao},    {0,  bo,  0},
    { ao,  0, -ao},   { ao,  0,  ao},    {0,  bo,  0},
    { ao,  0,  ao},   {-ao,  0,  ao},    {0,  bo,  0},
    { ao,  0, -ao},   {-ao,  0, -ao},    {0, -bo,  0},
    {-ao,  0, -ao},   {-ao,  0,  ao},    {0, -bo,  0},
    { ao,  0,  ao},   { ao,  0, -ao},    {0, -bo,  0},
    {-ao,  0,  ao},   { ao,  0,  ao},    {0, -bo,  0},
};

ah :: 0.5;
hexahedron_vertices := [...]Vec3 {
    {-ah, -ah, -ah},   { ah, -ah, -ah},   { ah, -ah,  ah},   {-ah, -ah,  ah},
    {-ah, -ah, -ah},   {-ah, -ah,  ah},   {-ah,  ah,  ah},   {-ah,  ah, -ah},
    {-ah, -ah,  ah},   { ah, -ah,  ah},   { ah,  ah,  ah},   {-ah,  ah,  ah},
    {-ah,  ah, -ah},   {-ah,  ah,  ah},   { ah,  ah,  ah},   { ah,  ah, -ah},
    { ah, -ah, -ah},   { ah,  ah, -ah},   { ah,  ah,  ah},   { ah, -ah,  ah},
    {-ah, -ah, -ah},   {-ah,  ah, -ah},   { ah,  ah, -ah},   { ah, -ah, -ah},
};

ai :: 0.5;
bi :: 1.0/(1.0 + math.SQRT_FIVE);
icosahedron_vertices := [...]Vec3 {
    { 0,   bi, -ai},   { bi,  ai,  0 },   {-bi,  ai,  0 },
    { 0,   bi,  ai},   {-bi,  ai,  0 },   { bi,  ai,  0 },
    { 0,   bi,  ai},   { 0,  -bi,  ai},   {-ai,  0,   bi},
    { 0,   bi,  ai},   { ai,  0,   bi},   { 0,  -bi,  ai},
    { 0,   bi, -ai},   { 0,  -bi, -ai},   { ai,  0,  -bi},
    { 0,   bi, -ai},   {-ai,  0,  -bi},   { 0,  -bi, -ai},
    { 0,  -bi,  ai},   { bi, -ai,  0 },   {-bi, -ai,  0 },
    { 0,  -bi, -ai},   {-bi, -ai,  0 },   { bi, -ai,  0 },
    {-bi,  ai,  0 },   {-ai,  0,   bi},   {-ai,  0,  -bi},
    {-bi, -ai,  0 },   {-ai,  0,  -bi},   {-ai,  0,   bi},
    { bi,  ai,  0 },   { ai,  0,  -bi},   { ai,  0,   bi},
    { bi, -ai,  0 },   { ai,  0,   bi},   { ai,  0,  -bi},
    { 0,   bi,  ai},   {-ai,  0,   bi},   {-bi,  ai,  0 },
    { 0,   bi,  ai},   { bi,  ai,  0 },   { ai,  0,   bi},
    { 0,   bi, -ai},   {-bi,  ai,  0 },   {-ai,  0,  -bi},
    { 0,   bi, -ai},   { ai,  0,  -bi},   { bi,  ai,  0 },
    { 0,  -bi, -ai},   {-ai,  0,  -bi},   {-bi, -ai,  0 },
    { 0,  -bi, -ai},   { bi, -ai,  0 },   { ai,  0,  -bi},
    { 0,  -bi,  ai},   {-bi, -ai,  0 },   {-ai,  0,   bi},
    { 0,  -bi,  ai},   { ai,  0,   bi},   { bi, -ai,  0 },
};

bd :: 2.0/(1.0 + math.SQRT_FIVE);
cd :: 2.0 - (1.0 + math.SQRT_FIVE)/2.0;
dodecahedron_vertices := [...]Vec3 {
    { cd,  0,  1},   {-cd,  0,  1},   {-bd,  bd,  bd},   { 0,  1,  cd},   { bd,  bd,  bd},
    {-cd,  0,  1},   { cd,  0,  1},   { bd, -bd,  bd},   { 0, -1,  cd},   {-bd, -bd,  bd},
    { cd,  0, -1},   {-cd,  0, -1},   {-bd, -bd, -bd},   { 0, -1, -cd},   { bd, -bd, -bd},
    {-cd,  0, -1},   { cd,  0, -1},   { bd,  bd, -bd},   { 0,  1, -cd},   {-bd,  bd, -bd},
    { 0,  1, -cd},   { 0,  1,  cd},   { bd,  bd,  bd},   { 1,  cd,  0},   { bd,  bd, -bd},
    { 0,  1,  cd},   { 0,  1, -cd},   {-bd,  bd, -bd},   {-1,  cd,  0},   {-bd,  bd,  bd},
    { 0, -1, -cd},   { 0, -1,  cd},   {-bd, -bd,  bd},   {-1, -cd,  0},   {-bd, -bd, -bd},
    { 0, -1,  cd},   { 0, -1, -cd},   { bd, -bd, -bd},   { 1, -cd,  0},   { bd, -bd,  bd},
    { 1,  cd,  0},   { 1, -cd,  0},   { bd, -bd,  bd},   { cd,  0,  1},   { bd,  bd,  bd},
    { 1, -cd,  0},   { 1,  cd,  0},   { bd,  bd, -bd},   { cd,  0, -1},   { bd, -bd, -bd},
    {-1,  cd,  0},   {-1, -cd,  0},   {-bd, -bd, -bd},   {-cd,  0, -1},   {-bd,  bd, -bd},
    {-1, -cd,  0},   {-1,  cd,  0},   {-bd,  bd,  bd},   {-cd,  0,  1},   {-bd, -bd,  bd},
};

Vec3 :: struct #ordered {
    x, y, z: f32,
};

Vertex :: struct #ordered {
    position, normal: Vec3,
    area: f32,
};

Model :: struct {
    vertices: []Vertex,
    
    num_vertices: int,
    num_triangles: int,
    
    base_name: string,
    subdivision: int,

    vao: u32,
    vbo: u32,

    min_area: f32 = 1.0e9,
    max_area : f32 = -1.0e9,
};

model_get_base_name :: proc(vertices_per_face, num_platonic_faces: int) -> string {
    switch vertices_per_face {
    case 3:
        switch num_platonic_faces {
        case 4:
            return "tetrahedron";
        case 8:
            return "octahedron";
        case 20:
            return "icosahedron";
        }
    case 4:
        return "hexahedron";
    case 5:
        return "dodecahedron";
    }

    return "unknown";
}

model_init_and_upload :: proc(using model: ^Model) {
    gl.CreateBuffers(1, &vbo);
    gl.NamedBufferData(vbo, size_of(Vertex)*num_vertices, &vertices[0], gl.STATIC_DRAW);
    
    gl.CreateVertexArrays(1, &vao);
    gl.VertexArrayVertexBuffer(vao, 0, vbo, 0, size_of(Vertex));

    gl.EnableVertexArrayAttrib(vao, 0);
    gl.EnableVertexArrayAttrib(vao, 1);
    gl.EnableVertexArrayAttrib(vao, 2);
    
    gl.VertexArrayAttribFormat(vao, 0, 3, gl.FLOAT, gl.FALSE, 0);
    gl.VertexArrayAttribFormat(vao, 1, 3, gl.FLOAT, gl.FALSE, 12);
    gl.VertexArrayAttribFormat(vao, 2, 1, gl.FLOAT, gl.FALSE, 24);

    gl.VertexArrayAttribBinding(vao, 0, 0);
    gl.VertexArrayAttribBinding(vao, 1, 0);
    gl.VertexArrayAttribBinding(vao, 2, 0);
}

normal_from_vertices :: proc(v: []Vec3) -> Vec3 {
    x, y, z: f32;
    for i in 0..len(v) {
        x += v[i].x;
        y += v[i].y;
        z += v[i].z;
    }
    l := math.sqrt(x*x + y*y + z*z);

    return Vec3{x/l, y/l, z/l};
}

normal_from_vertices :: proc(v: []Vertex) -> Vec3 {
    x, y, z: f32;
    for i in 0..len(v) {
        x += v[i].position.x;
        y += v[i].position.y;
        z += v[i].position.z;
    }
    l := math.sqrt(x*x + y*y + z*z);

    return Vec3{x/l, y/l, z/l};
}

normalize :: proc(using v: Vec3) -> Vec3 {
    l := math.sqrt(x*x + y*y + z*z);
    return Vec3{x/l, y/l, z/l};
}

subdivide_model :: proc(model_in: Model) -> Model {
    using model_out: Model;

    num_vertices  = model_in.num_vertices*4;
    num_triangles = model_in.num_triangles*4;
    base_name     = model_in.base_name;
    subdivision   = model_in.subdivision+1;

    vertices = make([]Vertex, num_vertices);

    // subdivide the old model. 
    // each triangle subdivided into 4 triangles
    ctr := 0;
    for i in 0..model_in.num_triangles {
        v1 := model_in.vertices[3*i+0].position;
        v2 := model_in.vertices[3*i+1].position;
        v3 := model_in.vertices[3*i+2].position;
        v12 := normalize(Vec3{(v1.x + v2.x)/2.0, (v1.y + v2.y)/2.0, (v1.z + v2.z)/2.0});
        v23 := normalize(Vec3{(v3.x + v2.x)/2.0, (v3.y + v2.y)/2.0, (v3.z + v2.z)/2.0});
        v13 := normalize(Vec3{(v1.x + v3.x)/2.0, (v1.y + v3.y)/2.0, (v1.z + v3.z)/2.0});

        vertices[ctr+0].position = v1;
        vertices[ctr+1].position = v12;
        vertices[ctr+2].position = v13;

        vertices[ctr+3].position = v2;
        vertices[ctr+4].position = v23;
        vertices[ctr+5].position = v12;

        vertices[ctr+6].position = v3;
        vertices[ctr+7].position = v13;
        vertices[ctr+8].position = v23;

        vertices[ctr+9].position  = v12;
        vertices[ctr+10].position = v23;
        vertices[ctr+11].position = v13;
        ctr += 12;
    }

    // each triangle shares the same normal, for flat shading
    for i in 0..num_triangles {
        normal := normal_from_vertices(vertices[3*i..3*i+3]);
        for j in 0..3 do vertices[3*i+j].normal = normal;
    }
    acos :: proc(x: f32) -> f32 {
       return (-0.69813170079773212 * x * x - 0.87266462599716477) * x + 1.5707963267948966;
    }

    for i in 0..num_triangles {
        v1 := vertices[3*i + 0].position;
        v2 := vertices[3*i + 1].position;
        v3 := vertices[3*i + 2].position;

        a := math.length(math.Vec3{v2.x - v1.x, v2.y - v1.y, v2.z - v1.z});
        b := math.length(math.Vec3{v3.x - v1.x, v3.y - v1.y, v3.z - v1.z});
        c := math.length(math.Vec3{v2.x - v3.x, v2.y - v3.y, v2.z - v3.z});

        u1 := math.Vec3{v2.x - v1.x, v2.y - v1.y, v2.z - v1.z};
        u2 := math.Vec3{v3.x - v1.x, v3.y - v1.y, v3.z - v1.z};
        u3 := math.Vec3{v2.x - v3.x, v2.y - v3.y, v2.z - v3.z};

        s := (a+b+c)/2.0;
        T := math.sqrt(s*(s-a)*(s-b)*(s-c));
        a1 := acos(math.dot(math.Vec3{v2.x - v1.x, v2.y - v1.y, v2.z - v1.z}, math.Vec3{v3.x - v1.x, v3.y - v1.y, v3.z - v1.z}) / (a*b))*180.0/3.1416;
        a2 := acos(math.dot(math.Vec3{v1.x - v2.x, v1.y - v2.y, v1.z - v2.z}, math.Vec3{v3.x - v2.x, v3.y - v2.y, v3.z - v2.z}) / (a*c))*180.0/3.1416;
        a3 := acos(math.dot(math.Vec3{v1.x - v3.x, v1.y - v3.y, v1.z - v3.z}, math.Vec3{v2.x - v3.x, v2.y - v3.y, v2.z - v3.z}) / (b*c))*180.0/3.1416;
        mina := min(min(a1,a2), a3);
        T = mina;
        //fmt.println(a1,a2,a3);
        model_out.min_area = min(model_out.min_area, T);
        model_out.max_area = max(model_out.max_area, T);

        vertices[3*i + 0].area = T;
        vertices[3*i + 1].area = T;
        vertices[3*i + 2].area = T;
    }
    model_init_and_upload(&model_out);

    fmt.printf("Subdivided model: %s %d %d %.8f %.8f\n", base_name, subdivision, num_triangles, model_out.min_area, model_out.max_area);
    
    return model_out;
}

subdivide_base_model_platonic :: proc(verts: []Vec3, vertices_per_face: int) -> Model {
    using model: Model;

    num_platonic_vertices := len(verts);
    num_platonic_faces := num_platonic_vertices/vertices_per_face;
    
    if vertices_per_face == 3 do num_triangles = 4*num_platonic_faces;    
    else do                      num_triangles = (vertices_per_face)*num_platonic_faces;
    
    num_vertices = 3*num_triangles;
    subdivision = 1;
    base_name = model_get_base_name(vertices_per_face, num_platonic_faces);

    vertices = make([]Vertex, num_vertices);

    ctr := 0;
    for i in 0..num_platonic_faces {
        // triangulate the platonic face, in a triangle fan or splitting a triangle into 4
        switch vertices_per_face {
        case 3: // tetrahedron, octahedron, icosahedron
            v1 := verts[3*i+0];
            v2 := verts[3*i+1];
            v3 := verts[3*i+2];
            v12 := normalize(Vec3{(v1.x + v2.x)/2.0, (v1.y + v2.y)/2.0, (v1.z + v2.z)/2.0});
            v23 := normalize(Vec3{(v3.x + v2.x)/2.0, (v3.y + v2.y)/2.0, (v3.z + v2.z)/2.0});
            v13 := normalize(Vec3{(v1.x + v3.x)/2.0, (v1.y + v3.y)/2.0, (v1.z + v3.z)/2.0});

            vertices[ctr+0].position = v1;
            vertices[ctr+1].position = v12;
            vertices[ctr+2].position = v13;

            vertices[ctr+3].position = v2;
            vertices[ctr+4].position = v23;
            vertices[ctr+5].position = v12;

            vertices[ctr+6].position = v3;
            vertices[ctr+7].position = v13;
            vertices[ctr+8].position = v23;

            vertices[ctr+9].position  = v12;
            vertices[ctr+10].position = v23;
            vertices[ctr+11].position = v13;
            ctr += 12;
        case 4, 5: // hexahedron, dodecahedron
            vm := normal_from_vertices(verts[vertices_per_face*i..vertices_per_face*(i+1)]);
            for j in 0..vertices_per_face {
                v1 := verts[vertices_per_face*i+((j+0)%vertices_per_face)];
                v2 := verts[vertices_per_face*i+((j+1)%vertices_per_face)];

                vertices[ctr+3*j+0].position = v1;
                vertices[ctr+3*j+1].position = v2;
                vertices[ctr+3*j+2].position = vm;

            }
            ctr += vertices_per_face*3;
        }
    }

    for i in 0..num_vertices {
        vertices[i].position = normalize(vertices[i].position);
    }

    for i in 0..num_triangles {
        normal := normal_from_vertices(vertices[3*i..3*i+3]);
        for j in 0..3 do vertices[3*i + j].normal = normal;

        v1 := vertices[3*i + 0].position;
        v2 := vertices[3*i + 1].position;
        v3 := vertices[3*i + 2].position;

        a := math.length(math.Vec3{v2.x - v1.x, v2.y - v1.y, v2.z - v1.z});
        b := math.length(math.Vec3{v3.x - v1.x, v3.y - v1.y, v3.z - v1.z});
        c := math.length(math.Vec3{v2.x - v3.x, v2.y - v3.y, v2.z - v3.z});
        s := (a+b+c)/2.0;
        T := math.sqrt(s*(s-a)*(s-b)*(s-c));
       
        model.min_area = min(model.min_area, T);
        model.max_area = max(model.max_area, T);

        vertices[3*i + 0].area = T;
        vertices[3*i + 1].area = T;
        vertices[3*i + 2].area = T;
    }

    model_init_and_upload(&model);
    
    fmt.println("Subdivided base solid:", base_name, subdivision, num_triangles);

    return model;
}



create_base_model_platonic :: proc(verts: []Vec3, vertices_per_face: int) -> Model {
    using model: Model;

    num_platonic_vertices := len(verts);
    num_platonic_faces := num_platonic_vertices/vertices_per_face;
    
    base_name = model_get_base_name(vertices_per_face, num_platonic_faces);
    subdivision = 0;

    num_triangles = num_platonic_faces*(vertices_per_face - 2);
    num_vertices = num_triangles*3;
    vertices = make([]Vertex, num_vertices);

    ctr := 0;
    for i in 0..num_platonic_faces {
        // triangulate the platonic face, in a triangle fan
        for j in 0..(vertices_per_face - 2) {
            vertices[ctr + j*3 + 0].position = verts[vertices_per_face*i        ];
            vertices[ctr + j*3 + 1].position = verts[vertices_per_face*i + j + 1];
            vertices[ctr + j*3 + 2].position = verts[vertices_per_face*i + j + 2];
        }

        // all triangles of the platonic face share the same normal, for flat shading
        normal := normal_from_vertices(verts[vertices_per_face*i..vertices_per_face*(i + 1)]);
        for j in 0..(3*vertices_per_face - 6) do vertices[ctr + j].normal = normal;
        
        // advance counter
        ctr += (vertices_per_face - 2)*3;
    }

    // make sure that the vertices are on the unit sphere
    for i in 0..num_vertices do vertices[i].position = normalize(vertices[i].position);
    
    for i in 0..num_triangles {
        v1 := vertices[3*i + 0].position;
        v2 := vertices[3*i + 1].position;
        v3 := vertices[3*i + 2].position;

        a := math.length(math.Vec3{v2.x - v1.x, v2.y - v1.y, v2.z - v1.z});
        b := math.length(math.Vec3{v3.x - v1.x, v3.y - v1.y, v3.z - v1.z});
        c := math.length(math.Vec3{v2.x - v3.x, v2.y - v3.y, v2.z - v3.z});
        s := (a+b+c)/2.0;
        T := math.sqrt(s*(s-a)*(s-b)*(s-c));
       
        model.min_area = min(model.min_area, T);
        model.max_area = max(model.max_area, T);

        vertices[3*i + 0].area = T;
        vertices[3*i + 1].area = T;
        vertices[3*i + 2].area = T;
    }

    // initialize vao and vbo, and upload the vertex data
    model_init_and_upload(&model);
    
    fmt.println("Created base solid:", base_name, subdivision, num_triangles);

    return model;
}

main :: proc() {
    resx, resy := 1600.0, 900.0;
    window, success := init_glfw(i32(resx), i32(resy), "Odin Font Rendering");
    if !success {
        glfw.Terminate();
        return;
    }
    defer glfw.Terminate();

    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(4, 5, set_proc_address);

    gl.ClearColor(1.0, 1.0, 1.0, 1.0);

    if !font.init("extra/font_3x1.bin", "shaders/shader_font.vs", "shaders/shader_font.fs") do return;  
    
    defer font.cleanup();

    program, shader_success := gl.load_shaders("shaders/shader_solids.vs", "shaders/shader_solids.fs");
    defer gl.DeleteProgram(program);
    
    num_subdivisions :: 7;
    all_models: [num_subdivisions][5]Model;

    all_models[0] = [5]Model{
        create_base_model_platonic(tetrahedron_vertices[...], 3),
        create_base_model_platonic(octahedron_vertices[...], 3),
        create_base_model_platonic(hexahedron_vertices[...], 4),
        create_base_model_platonic(icosahedron_vertices[...], 3),
        create_base_model_platonic(dodecahedron_vertices[...], 5),
    };
    fmt.println();

    all_models[1] = [5]Model{
        subdivide_base_model_platonic(tetrahedron_vertices[...], 3),
        subdivide_base_model_platonic(octahedron_vertices[...], 3),
        subdivide_base_model_platonic(hexahedron_vertices[...], 4),
        subdivide_base_model_platonic(icosahedron_vertices[...], 3),
        subdivide_base_model_platonic(dodecahedron_vertices[...], 5),
    };
    fmt.println();

    for j in 2..num_subdivisions {
        all_models[j] = [5]Model{
            subdivide_model(all_models[j-1][0]),
            subdivide_model(all_models[j-1][1]),
            subdivide_model(all_models[j-1][2]),
            subdivide_model(all_models[j-1][3]),
            subdivide_model(all_models[j-1][4]),
        };
        fmt.println();
    }

    total_triangles := 0;
    for model_slice in all_models do for model in model_slice do total_triangles += model.num_triangles;
    fmt.println(total_triangles);

    p := math.Vec3{0.0, 0.0, 5.0};

    // @NOTE: The camera directions use spherical coordianates, 
    //        in particular, physics conventions are used: 
    //        theta is up-down, phi is left-right
    theta, phi := f32(math.π), f32(math.π/2.0);

    sinp, cosp := math.sin(phi),   math.cos(phi);
    sint, cost := math.sin(theta), math.cos(theta);

    f := math.Vec3{cosp*sint, sinp*sint, cost};                   // forward vector, normalized, spherical coordinates
    r := math.Vec3{sinp, -cosp, 0.0};                             // right vector, relative to forward
    u := math.Vec3{-cosp*cost, -sinp*cost, sint};                 // "up" vector, u = r x f

    // for mouse movement
    mx_prev, my_prev := glfw.GetCursorPos(window);

    // for timings
    t_prev := glfw.GetTime();
    frame := 0;


    gl.Enable(gl.DEPTH_TEST);
    //gl.Enable(gl.BLEND);
    //gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    for glfw.WindowShouldClose(window) == glfw.FALSE {
        glfw.calculate_frame_timings(window);
        
        glfw.PollEvents();


        // time delta for fps-independent movement speed
        t_now := glfw.GetTime();
        dt := f32(t_now - t_prev);
        t_prev = t_now;

        // get current mouse position
        mx, my: f64;
        glfw.GetCursorPos(window, &mx, &my);

        // update camera direction
        if glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_1) == glfw.PRESS {
            radiansPerPixel := f32(0.1 * math.π / 180.0);
            phi = phi - f32(mx - mx_prev) * radiansPerPixel;
            theta = clamp(theta + f32(my - my_prev) * radiansPerPixel, 1.0*math.π/180.0, 179.0*math.π/180.0);
        }

        mx_prev = mx;
        my_prev = my;

        // calculate updated local camera coordinate system
        sinp, cosp = math.sin(phi),   math.cos(phi);
        sint, cost = math.sin(theta), math.cos(theta);

        f = math.Vec3{cosp*sint, sinp*sint, cost};                   // forward vector, normalized, spherical coordinates
        r = math.Vec3{sinp, -cosp, 0.0};                             // right vector, relative to forward
        u = math.Vec3{-cosp*cost, -sinp*cost, sint};                 // "up" vector, u = r x f

        if glfw.GetKey(window, glfw.KEY_LEFT_CONTROL) == glfw.PRESS {
            dt *= 10.0;
        }
        if glfw.GetKey(window, glfw.KEY_LEFT_SHIFT) == glfw.PRESS {
            dt /= 10.0;
        }

        // update camera position:
        // W: forward, S: back, A: left, D: right, E: up, Q: down
        p += f*f32(glfw.GetKey(window, glfw.KEY_W) - glfw.GetKey(window, glfw.KEY_S))*dt;
        p += r*f32(glfw.GetKey(window, glfw.KEY_D) - glfw.GetKey(window, glfw.KEY_A))*dt;
        p += u*f32(glfw.GetKey(window, glfw.KEY_E) - glfw.GetKey(window, glfw.KEY_Q))*dt;

        if glfw.GetKey(window, glfw.KEY_F5) == glfw.PRESS {
            old_program := program;
            new_program, success := gl.load_shaders("shaders/shader_solids.vs", "shaders/shader_solids.fs");
            if success {
                program = new_program;
                gl.DeleteProgram(old_program);
                fmt.println("Updated shaders");
            }
        }

        // Main drawing part
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.UseProgram(program);
        gl.Uniform1f(get_uniform_location(program, "time\x00"), f32(glfw.GetTime()));
        gl.Uniform3f(get_uniform_location(program, "camera_pos\x00"), f32(p[0]), f32(p[1]), f32(p[2]));
        gl.Uniform2f(get_uniform_location(program, "resolution\x00"), f32(resx), f32(resy));

        V := view(r, u, f, p);
        near : f32 = 0.01;
        far : f32 = 1000.0;
        P := math.perspective(45.0*math.PI/180.0, f32(resx/resy), near, far);

        gl.BindVertexArray(all_models[0][0].vao);
        /*
        seed = 12345;
        gl.PolygonMode(  gl.FRONT_AND_BACK, gl.FILL);
        gl.Uniform1i(get_uniform_location(program, "draw_mode\x00"), 0);
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), 0);
        //gl.DepthRange(0.0, 1000.0);
        for j in 0..num_subdivisions {
            for model, i in all_models[j] {
                M := math.mat4_translate(math.Vec3{f32(i)*2.2, f32(j)*2.2, 0.0});
                M = math.mul(M, math.mat4_rotate(math.norm(math.Vec3{cast(f32)rng(), cast(f32)rng(), cast(f32)rng()}), 0.25*cast(f32)glfw.GetTime()) );
                M = math.mul(M, math.mat4_rotate(math.norm(math.Vec3{cast(f32)rng(), cast(f32)rng(), cast(f32)rng()}), 0.25*cast(f32)glfw.GetTime()) );
                MV := math.mul(V, M);
                MVP := math.mul(P, MV);
                gl.Uniform1f(get_uniform_location(program, "min_area\x00"), model.min_area);
                gl.Uniform1f(get_uniform_location(program, "max_area\x00"), model.max_area);
                gl.Uniform3f(get_uniform_location(program, "sphere_pos\x00"), f32(i)*2.2, f32(j)*2.2, 0.0);
                gl.UniformMatrix4fv(get_uniform_location(program, "MVP\x00"), 1, gl.FALSE, &MVP[0][0]);
                
                gl.BindVertexArray(model.vao);
                gl.DrawArrays(gl.TRIANGLES, 0, i32(model.num_vertices));
            }
        }
        */

        /*
        gl.PolygonMode(  gl.FRONT_AND_BACK, gl.LINE);
        gl.Uniform1i(get_uniform_location(program, "draw_mode\x00"), 1);

        for j in 0..num_subdivisions {
            for model, i in all_models[j] {
                M := math.mat4_translate(math.Vec3{f32(i)*2.2, f32(j)*2.2, 0.0});
                M = math.mul(M, math.mat4_rotate(math.norm(math.Vec3{cast(f32)rng(), cast(f32)rng(), cast(f32)rng()}), 0.0*cast(f32)glfw.GetTime()) );
                M = math.mul(M, math.mat4_rotate(math.norm(math.Vec3{cast(f32)rng(), cast(f32)rng(), cast(f32)rng()}), 0.0*cast(f32)glfw.GetTime()) );
                MV := math.mul(V, M);
                MVP := math.mul(P, MV);
                gl.Uniform1f(get_uniform_location(program, "min_area\x00"), model.min_area);
                gl.Uniform1f(get_uniform_location(program, "max_area\x00"), model.max_area);
                gl.Uniform3f(get_uniform_location(program, "sphere_pos\x00"), f32(i)*2.2, f32(j)*2.2, 0.0);
                gl.UniformMatrix4fv(get_uniform_location(program, "MVP\x00"), 1, gl.FALSE, &MVP[0][0]);
                
                gl.BindVertexArray(model.vao);
                gl.DrawArrays(gl.TRIANGLES, 0, i32(model.num_vertices));
            }
        }
        */

        seed = 12345;

        //gl.PolygonMode(  gl.FRONT_AND_BACK, gl.FILL);
        gl.Uniform3f(get_uniform_location(program, "r\x00"), r[0], r[1], r[2]);
        gl.Uniform3f(get_uniform_location(program, "u\x00"), u[0], u[1], u[2]);
        gl.Uniform1i(get_uniform_location(program, "vertex_mode\x00"), 1);
        gl.Uniform1i(get_uniform_location(program, "draw_mode\x00"), 2);
        gl.Uniform1f(get_uniform_location(program, "near\x00"), near);
        gl.Uniform1f(get_uniform_location(program, "far\x00"), far);
        
        M := math.mat4_translate(math.Vec3{0.0, 0.0, 0.0});
        MV := math.mul(V, M);
        MVP := math.mul(P, MV);
        gl.UniformMatrix4fv(get_uniform_location(program, "MVP\x00"), 1, gl.FALSE, &MVP[0][0]);

        //gl.Uniform3f(get_uniform_location(program, "sphere_pos\x00"), 100*cast(f32)rng(), 50*cast(f32)rng(), 4.0 + 50.0*cast(f32)rng());
        gl.Uniform3f(get_uniform_location(program, "sphere_pos\x00"), 0.0, 0.0, 0.0);
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, i32(4), 1000000);
        /*
        for i in 0..10000 {
        }
        */

        glfw.SwapBuffers(window);
    }
}

// Right handed view matrix, defined from camera position and a local 
// camera coordinate system, namely right (X), up (Y) and forward (-Z).
// Hopefully this one gets added to core/math.odin eventually.
view :: proc(r, u, f, p: math.Vec3) -> math.Mat4 { 
    return math.Mat4 {
        {+r[0], +u[0], -f[0], 0.0},
        {+r[1], +u[1], -f[1], 0.0},
        {+r[2], +u[2], -f[2], 0.0},
        {-math.dot(r,p), -math.dot(u,p), math.dot(f,p), 1.0},
    };
}

// wrapper to use GetUniformLocation with an Odin string
// @NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
    return gl.GetUniformLocation(program, &str[0]);;
}

error_callback :: proc "c" (error: i32, desc: ^u8) {
    fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
}

init_glfw :: proc(resx, resy: i32, title: string) -> (glfw.Window_Handle, bool) {
    glfw.SetErrorCallback(error_callback);

    if glfw.Init() == 0 do return nil, false;

    //glfw.WindowHint(glfw.SAMPLES, 8);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    window := glfw.CreateWindow(resx, resy, title, nil, nil);
    if window == nil do return nil, false;
    
    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    return window, true;
}

// Minimal Standard LCG
seed : u32 = 12345;
rng :: proc() -> f64 {
    seed *= 16807;
    return f64(seed) / f64(0x100000000);
}
