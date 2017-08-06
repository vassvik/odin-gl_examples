import (
    "fmt.odin";
    "strings.odin";
    "math.odin";
    "external/odin-glfw/glfw.odin";
    "external/odin-gl/gl.odin";
    "external/odin-gl_font/font.odin";
)

at :: 0.5;

tetrahedron_vertices := [...]f32 {
     at,  at,  at,   -at,  at, -at,    at, -at, -at,
    -at,  at, -at,   -at, -at,  at,    at, -at, -at,
     at,  at,  at,    at, -at, -at,   -at, -at,  at,
     at,  at,  at,   -at, -at,  at,   -at,  at, -at,
}; 

ao :: 1.0/(2.0*math.SQRT_TWO);
bo :: 0.5;

octahedron_vertices := [...]f32 {
    -ao,  0,  ao,   -ao,  0, -ao,    0,  bo,  0,
    -ao,  0, -ao,    ao,  0, -ao,    0,  bo,  0,
     ao,  0, -ao,    ao,  0,  ao,    0,  bo,  0,
     ao,  0,  ao,   -ao,  0,  ao,    0,  bo,  0,
     ao,  0, -ao,   -ao,  0, -ao,    0, -bo,  0,
    -ao,  0, -ao,   -ao,  0,  ao,    0, -bo,  0,
     ao,  0,  ao,    ao,  0, -ao,    0, -bo,  0,
    -ao,  0,  ao,    ao,  0,  ao,    0, -bo,  0,
};

ah :: 0.5;

hexahedron_vertices := [...]f32 {
    -ah, -ah, -ah,    ah, -ah, -ah,    ah, -ah,  ah,   -ah, -ah,  ah,
    -ah, -ah, -ah,   -ah, -ah,  ah,   -ah,  ah,  ah,   -ah,  ah, -ah,
    -ah, -ah,  ah,    ah, -ah,  ah,    ah,  ah,  ah,   -ah,  ah,  ah,
    -ah,  ah, -ah,   -ah,  ah,  ah,    ah,  ah,  ah,    ah,  ah, -ah,
     ah, -ah, -ah,    ah,  ah, -ah,    ah,  ah,  ah,    ah, -ah,  ah,
    -ah, -ah, -ah,   -ah,  ah, -ah,    ah,  ah, -ah,    ah, -ah, -ah,
};

ai :: 0.5;
bi :: 1.0/(1.0 + math.SQRT_FIVE);
icosahedron_vertices := [...]f32 {
     0,   bi, -ai,    bi,  ai,  0,    -bi,  ai,  0,
     0,   bi,  ai,   -bi,  ai,  0,     bi,  ai,  0,
     0,   bi,  ai,    0,  -bi,  ai,   -ai,  0,   bi,
     0,   bi,  ai,    ai,  0,   bi,    0,  -bi,  ai,
     0,   bi, -ai,    0,  -bi, -ai,    ai,  0,  -bi,
     0,   bi, -ai,   -ai,  0,  -bi,    0,  -bi, -ai,
     0,  -bi,  ai,    bi, -ai,  0,    -bi, -ai,  0,
     0,  -bi, -ai,   -bi, -ai,  0,     bi, -ai,  0,
    -bi,  ai,  0,    -ai,  0,   bi,   -ai,  0,  -bi,
    -bi, -ai,  0,    -ai,  0,  -bi,   -ai,  0,   bi,
     bi,  ai,  0,     ai,  0,  -bi,    ai,  0,   bi,
     bi, -ai,  0,     ai,  0,   bi,    ai,  0,  -bi,
     0,   bi,  ai,   -ai,  0,   bi,   -bi,  ai,  0,
     0,   bi,  ai,    bi,  ai,  0,     ai,  0,   bi,
     0,   bi, -ai,   -bi,  ai,  0,    -ai,  0,  -bi,
     0,   bi, -ai,    ai,  0,  -bi,    bi,  ai,  0,
     0,  -bi, -ai,   -ai,  0,  -bi,   -bi, -ai,  0,
     0,  -bi, -ai,    bi, -ai,  0,     ai,  0,  -bi,
     0,  -bi,  ai,   -bi, -ai,  0,    -ai,  0,   bi,
     0,  -bi,  ai,    ai,  0,   bi,    bi, -ai,  0,
};

b :: 2.0/(1.0 + math.SQRT_FIVE);
c :: 2.0 - (1.0 + math.SQRT_FIVE)/2.0;

dodecahedron_vertices := [...]f32 {
     c,  0,  1,   -c,  0,  1,   -b,  b,  b,    0,  1,  c,    b,  b,  b,
    -c,  0,  1,    c,  0,  1,    b, -b,  b,    0, -1,  c,   -b, -b,  b,
     c,  0, -1,   -c,  0, -1,   -b, -b, -b,    0, -1, -c,    b, -b, -b,
    -c,  0, -1,    c,  0, -1,    b,  b, -b,    0,  1, -c,   -b,  b, -b,
     0,  1, -c,    0,  1,  c,    b,  b,  b,    1,  c,  0,    b,  b, -b,
     0,  1,  c,    0,  1, -c,   -b,  b, -b,   -1,  c,  0,   -b,  b,  b,
     0, -1, -c,    0, -1,  c,   -b, -b,  b,   -1, -c,  0,   -b, -b, -b,
     0, -1,  c,    0, -1, -c,    b, -b, -b,    1, -c,  0,    b, -b,  b,
     1,  c,  0,    1, -c,  0,    b, -b,  b,    c,  0,  1,    b,  b,  b,
     1, -c,  0,    1,  c,  0,    b,  b, -b,    c,  0, -1,    b, -b, -b,
    -1,  c,  0,   -1, -c,  0,   -b, -b, -b,   -c,  0, -1,   -b,  b, -b,
    -1, -c,  0,   -1,  c,  0,   -b,  b,  b,   -c,  0,  1,   -b, -b,  b,
};

Vec3 :: struct #ordered {
    x, y, z: f32;
};

Vertex :: struct #ordered {
    position, normal: Vec3;
};


Model :: struct {
    vertices: []Vertex;
    num_vertices: int;
    num_triangles: int;
    vao: u32;
    vbo: u32;
    base_name: string;
    subdivision: int;
};

normal_from_vertices :: proc(v: []f32) -> Vec3 {
    x, y, z: f32;
    for i in 0..len(v)/3 {
        x += v[3*i+0];
        y += v[3*i+1];
        z += v[3*i+2];
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

normalize :: proc(v: Vec3) -> Vec3 {
    l := math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
    return Vec3{v.x/l, v.y/l, v.z/l};
}

subdivide_model :: proc(model_in: Model) -> Model {
    model_out: Model;

    model_out.num_vertices = model_in.num_vertices*4;
    model_out.num_triangles = model_in.num_triangles*4;
    model_out.base_name = model_in.base_name;
    model_out.subdivision = model_in.subdivision+1;

    model_out.vertices = make([]Vertex, model_out.num_vertices);

    ctr := 0;
    for i in 0..model_in.num_triangles {
        v1 := model_in.vertices[3*i+0].position;
        v2 := model_in.vertices[3*i+1].position;
        v3 := model_in.vertices[3*i+2].position;
        v12 := normalize(Vec3{(v1.x + v2.x)/2.0, (v1.y + v2.y)/2.0, (v1.z + v2.z)/2.0});
        v23 := normalize(Vec3{(v3.x + v2.x)/2.0, (v3.y + v2.y)/2.0, (v3.z + v2.z)/2.0});
        v13 := normalize(Vec3{(v1.x + v3.x)/2.0, (v1.y + v3.y)/2.0, (v1.z + v3.z)/2.0});

        model_out.vertices[ctr+0].position = v1;
        model_out.vertices[ctr+1].position = v12;
        model_out.vertices[ctr+2].position = v13;

        model_out.vertices[ctr+3].position = v2;
        model_out.vertices[ctr+4].position = v23;
        model_out.vertices[ctr+5].position = v12;

        model_out.vertices[ctr+6].position = v3;
        model_out.vertices[ctr+7].position = v13;
        model_out.vertices[ctr+8].position = v23;

        model_out.vertices[ctr+9].position = v12;
        model_out.vertices[ctr+10].position = v23;
        model_out.vertices[ctr+11].position = v13;
        ctr += 12;
    }

    using model_out;
    for i in 0..num_vertices {
        vertices[i].position = normalize(vertices[i].position);
    }

    for i in 0..model_out.num_triangles {
        model_out.vertices[3*i+0].normal = normal_from_vertices(model_out.vertices[3*i..3*i+3]);
        model_out.vertices[3*i+1].normal = normal_from_vertices(model_out.vertices[3*i..3*i+3]);
        model_out.vertices[3*i+2].normal = normal_from_vertices(model_out.vertices[3*i..3*i+3]);
    }

    fmt.println(base_name, subdivision, num_triangles);

    using gl;

    CreateBuffers(1, &vbo);      // @TODO: defer
    NamedBufferStorage(vbo, size_of(Vertex)*model_out.num_vertices, &model_out.vertices[0], DYNAMIC_STORAGE_BIT);
    
    CreateVertexArrays(1, &vao); // @TODO: defer
    VertexArrayVertexBuffer(vao, 0, vbo, 0, size_of(Vertex));    

    EnableVertexArrayAttrib(vao, 0);
    EnableVertexArrayAttrib(vao, 1);
    
    VertexArrayAttribFormat(vao, 0, 3, FLOAT, FALSE, 0);
    VertexArrayAttribFormat(vao, 1, 3, FLOAT, FALSE, 12);

    VertexArrayAttribBinding(vao, 0, 0);
    VertexArrayAttribBinding(vao, 1, 0);


    return model_out;
}

subdivide_base_model_platonic :: proc(verts: []f32, vertices_per_face: int) -> Model {
    num_platonic_vertices := len(verts)/3;
    num_platonic_faces := num_platonic_vertices/vertices_per_face;

    using model: Model;
    if vertices_per_face == 3 {
        num_triangles = 4*num_platonic_faces;    
    } else {
        num_triangles = (vertices_per_face)*num_platonic_faces;
    }
    num_vertices = 3*num_triangles;
    subdivision = 1;
    match vertices_per_face {
    case 3:
        match num_platonic_faces {
        case 4:
            base_name = "tetrahedron";
        case 8:
            base_name = "octahedron";
        case 20:
            base_name = "icosahedron";
        }
    case 4:
        base_name = "hexahedron";
    case 5:
        base_name = "dodecahedron";
    }

    vertices = make([]Vertex, num_vertices);

    ctr := 0;
    for i in 0..num_platonic_faces {
        match vertices_per_face {
        case 3: // tetrahedron, octahedron, icosahedron
            v1 := Vec3{verts[9*i+0], verts[9*i+1], verts[9*i+2]};
            v2 := Vec3{verts[9*i+3], verts[9*i+4], verts[9*i+5]};
            v3 := Vec3{verts[9*i+6], verts[9*i+7], verts[9*i+8]};
            v12 := normalize(Vec3{(verts[9*i+0] + verts[9*i+3])/2.0, (verts[9*i+1] + verts[9*i+4])/2.0, (verts[9*i+2] + verts[9*i+5])/2.0});
            v23 := normalize(Vec3{(verts[9*i+3] + verts[9*i+6])/2.0, (verts[9*i+4] + verts[9*i+7])/2.0, (verts[9*i+5] + verts[9*i+8])/2.0});
            v13 := normalize(Vec3{(verts[9*i+0] + verts[9*i+6])/2.0, (verts[9*i+1] + verts[9*i+7])/2.0, (verts[9*i+2] + verts[9*i+8])/2.0});
            vm := normal_from_vertices(verts[9*i+0..9*i+9]);

            vertices[ctr+0].position = v1;
            vertices[ctr+1].position = v12;
            vertices[ctr+2].position = v13;

            vertices[ctr+3].position = v2;
            vertices[ctr+4].position = v23;
            vertices[ctr+5].position = v12;

            vertices[ctr+6].position = v3;
            vertices[ctr+7].position = v13;
            vertices[ctr+8].position = v23;

            vertices[ctr+9].position = v12;
            vertices[ctr+10].position = v23;
            vertices[ctr+11].position = v13;
            ctr += 12;
        case 4: // hexahedron (cube)
            v1 := Vec3{verts[12*i+0], verts[12*i+1], verts[12*i+2]};
            v2 := Vec3{verts[12*i+3], verts[12*i+4], verts[12*i+5]};
            v3 := Vec3{verts[12*i+6], verts[12*i+7], verts[12*i+8]};
            v4 := Vec3{verts[12*i+9], verts[12*i+10], verts[12*i+11]};
            vm := normal_from_vertices(verts[12*i+0..12*i+12]);
            vertices[ctr+0].position = v1;
            vertices[ctr+1].position = v2;
            vertices[ctr+2].position = vm;

            vertices[ctr+3].position = v2;
            vertices[ctr+4].position = v3;
            vertices[ctr+5].position = vm;

            vertices[ctr+6].position = v3;
            vertices[ctr+7].position = v4;
            vertices[ctr+8].position = vm;

            vertices[ctr+9].position = v4;
            vertices[ctr+10].position = v1;
            vertices[ctr+11].position = vm;
            ctr += 12;
        case 5: // dodecahedron
            v1 := Vec3{verts[15*i+0], verts[15*i+1], verts[15*i+2]};
            v2 := Vec3{verts[15*i+3], verts[15*i+4], verts[15*i+5]};
            v3 := Vec3{verts[15*i+6], verts[15*i+7], verts[15*i+8]};
            v4 := Vec3{verts[15*i+9], verts[15*i+10], verts[15*i+11]};
            v5 := Vec3{verts[15*i+12], verts[15*i+13], verts[15*i+14]};
            vm := normal_from_vertices(verts[15*i+0..15*i+15]);
            vertices[ctr+0].position = v1;
            vertices[ctr+1].position = v2;
            vertices[ctr+2].position = vm;

            vertices[ctr+3].position = v2;
            vertices[ctr+4].position = v3;
            vertices[ctr+5].position = vm;

            vertices[ctr+6].position = v3;
            vertices[ctr+7].position = v4;
            vertices[ctr+8].position = vm;

            vertices[ctr+9].position = v4;
            vertices[ctr+10].position = v5;
            vertices[ctr+11].position = vm;

            vertices[ctr+12].position = v5;
            vertices[ctr+13].position = v1;
            vertices[ctr+14].position = vm;

            ctr += 15;
        }
    }

    for i in 0..num_vertices {
        vertices[i].position = normalize(vertices[i].position);
    }

    for i in 0..num_triangles {
        vertices[3*i+0].normal = normal_from_vertices(vertices[3*i..3*i+3]);
        vertices[3*i+1].normal = normal_from_vertices(vertices[3*i..3*i+3]);
        vertices[3*i+2].normal = normal_from_vertices(vertices[3*i..3*i+3]);
    }



    fmt.println(base_name, subdivision, num_triangles);

    using gl;

    CreateBuffers(1, &vbo);      // @TODO: defer
    NamedBufferStorage(vbo, size_of(Vertex)*num_vertices, &vertices[0], DYNAMIC_STORAGE_BIT);
    
    CreateVertexArrays(1, &vao); // @TODO: defer
    VertexArrayVertexBuffer(vao, 0, vbo, 0, size_of(Vertex));    

    EnableVertexArrayAttrib(vao, 0);
    EnableVertexArrayAttrib(vao, 1);
    
    VertexArrayAttribFormat(vao, 0, 3, FLOAT, FALSE, 0);
    VertexArrayAttribFormat(vao, 1, 3, FLOAT, FALSE, 12);

    VertexArrayAttribBinding(vao, 0, 0);
    VertexArrayAttribBinding(vao, 1, 0);

   return model;
}

create_base_model_platonic :: proc(verts: []f32, vertices_per_face: int) -> Model {
    using model: Model;


    num_platonic_vertices := len(verts)/3;
    num_platonic_faces := num_platonic_vertices/vertices_per_face;

    for i in 0..num_platonic_vertices {
        v := normal_from_vertices(verts[3*i..3*i+3]);
        verts[3*i+0] = v.x;
        verts[3*i+1] = v.y;
        verts[3*i+2] = v.z;
    }
    
    num_triangles = num_platonic_faces*(vertices_per_face-2);
    num_vertices = num_triangles*3;
    

    vertices = make([]Vertex, num_triangles*3);

    match vertices_per_face {
    case 3:
        match num_platonic_faces {
        case 4:
            base_name = "tetrahedron";
        case 8:
            base_name = "octahedron";
        case 20:
            base_name = "icosahedron";
        }
    case 4:
        base_name = "hexahedron";
    case 5:
        base_name = "dodecahedron";
    }
    subdivision = 0;




    ctr := 0;
    for i in 0..num_platonic_faces {
        match vertices_per_face {
        case 3: // tetrahedron, octahedron, icosahedron
            vertices[ctr+0].position = Vec3{verts[9*i+0], verts[9*i+1], verts[9*i+2]};
            vertices[ctr+1].position = Vec3{verts[9*i+3], verts[9*i+4], verts[9*i+5]};
            vertices[ctr+2].position = Vec3{verts[9*i+6], verts[9*i+7], verts[9*i+8]};

            vertices[ctr+0].normal = normal_from_vertices(verts[9*i..9*(i+1)]);
            vertices[ctr+1].normal = vertices[ctr+0].normal;
            vertices[ctr+2].normal = vertices[ctr+0].normal;
            ctr += 3;
        case 4: // hexahedron (cube)
            vertices[ctr+0].position = Vec3{verts[12*i+0], verts[12*i+1], verts[12*i+2]};
            vertices[ctr+1].position = Vec3{verts[12*i+3], verts[12*i+4], verts[12*i+5]};
            vertices[ctr+2].position = Vec3{verts[12*i+6], verts[12*i+7], verts[12*i+8]};

            vertices[ctr+3].position = Vec3{verts[12*i+0], verts[12*i+1], verts[12*i+2]};
            vertices[ctr+4].position = Vec3{verts[12*i+6], verts[12*i+7], verts[12*i+8]};
            vertices[ctr+5].position = Vec3{verts[12*i+9], verts[12*i+10], verts[12*i+11]};

            vertices[ctr+0].normal = normal_from_vertices(verts[12*i..12*(i+1)]);
            vertices[ctr+1].normal = vertices[ctr+0].normal;
            vertices[ctr+2].normal = vertices[ctr+0].normal;
            
            vertices[ctr+3].normal = vertices[ctr+0].normal;
            vertices[ctr+4].normal = vertices[ctr+0].normal;
            vertices[ctr+5].normal = vertices[ctr+0].normal;
            ctr += 6;
        case 5: // dodecahedron
            vertices[ctr+0].position = Vec3{verts[15*i+0], verts[15*i+1], verts[15*i+2]};
            vertices[ctr+1].position = Vec3{verts[15*i+3], verts[15*i+4], verts[15*i+5]};
            vertices[ctr+2].position = Vec3{verts[15*i+6], verts[15*i+7], verts[15*i+8]};

            vertices[ctr+3].position = Vec3{verts[15*i+0], verts[15*i+1], verts[15*i+2]};
            vertices[ctr+4].position = Vec3{verts[15*i+6], verts[15*i+7], verts[15*i+8]};
            vertices[ctr+5].position = Vec3{verts[15*i+9], verts[15*i+10], verts[15*i+11]};

            vertices[ctr+6].position = Vec3{verts[15*i+0], verts[15*i+1], verts[15*i+2]};
            vertices[ctr+7].position = Vec3{verts[15*i+9], verts[15*i+10], verts[15*i+11]};
            vertices[ctr+8].position = Vec3{verts[15*i+12], verts[15*i+13], verts[15*i+14]};

            vertices[ctr+0].normal = normal_from_vertices(verts[15*i..15*(i+1)]);
            vertices[ctr+1].normal = vertices[ctr+0].normal;
            vertices[ctr+2].normal = vertices[ctr+0].normal;
            
            vertices[ctr+3].normal = vertices[ctr+0].normal;
            vertices[ctr+4].normal = vertices[ctr+0].normal;
            vertices[ctr+5].normal = vertices[ctr+0].normal;

            vertices[ctr+6].normal = vertices[ctr+0].normal;
            vertices[ctr+7].normal = vertices[ctr+0].normal;
            vertices[ctr+8].normal = vertices[ctr+0].normal;

            ctr += 9;
        }
    }

    for i in 0..num_vertices {
        vertices[i].position = normalize(vertices[i].position);
    }



    fmt.println(base_name, subdivision, num_triangles);
    

    using gl;

    CreateBuffers(1, &vbo);      // @TODO: defer
    NamedBufferStorage(vbo, size_of(Vertex)*num_vertices, &vertices[0], DYNAMIC_STORAGE_BIT);
    
    CreateVertexArrays(1, &vao); // @TODO: defer
    VertexArrayVertexBuffer(vao, 0, vbo, 0, size_of(Vertex));    

    EnableVertexArrayAttrib(vao, 0);
    EnableVertexArrayAttrib(vao, 1);
    
    VertexArrayAttribFormat(vao, 0, 3, FLOAT, FALSE, 0);
    VertexArrayAttribFormat(vao, 1, 3, FLOAT, FALSE, 12);

    VertexArrayAttribBinding(vao, 0, 0);
    VertexArrayAttribBinding(vao, 1, 0);
    

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

    if !font.init("extra/font_3x1.bin", "shaders/shader_font.vs", "shaders/shader_font.fs", set_proc_address) do return;  
    
    defer font.cleanup();

    using gl;

    program, shader_success := load_shaders("shaders/shader_solids.vs", "shaders/shader_solids.fs");
    // @TODO: defer
    
    model_tetrahedron := create_base_model_platonic(tetrahedron_vertices[...], 3);
    model_octahedron := create_base_model_platonic(octahedron_vertices[...], 3);
    model_hexahedron := create_base_model_platonic(hexahedron_vertices[...], 4);
    model_icosahedron := create_base_model_platonic(icosahedron_vertices[...], 3);
    model_dodecahedron := create_base_model_platonic(dodecahedron_vertices[...], 5);
    models := [5]Model{model_tetrahedron, model_octahedron, model_hexahedron, model_icosahedron, model_dodecahedron};
    fmt.println();

    sub1_tetrahedron := subdivide_base_model_platonic(tetrahedron_vertices[...], 3);
    sub1_octahedron := subdivide_base_model_platonic(octahedron_vertices[...], 3);
    sub1_hexahedron := subdivide_base_model_platonic(hexahedron_vertices[...], 4);
    sub1_icosahedron := subdivide_base_model_platonic(icosahedron_vertices[...], 3);
    sub1_dodecahedron := subdivide_base_model_platonic(dodecahedron_vertices[...], 5);
    models_sub1 := [5]Model{sub1_tetrahedron, sub1_octahedron, sub1_hexahedron, sub1_icosahedron, sub1_dodecahedron};
    fmt.println();
    
    sub2_tetrahedron := subdivide_model(sub1_tetrahedron);
    sub2_octahedron := subdivide_model(sub1_octahedron);
    sub2_hexahedron := subdivide_model(sub1_hexahedron);
    sub2_icosahedron := subdivide_model(sub1_icosahedron);
    sub2_dodecahedron := subdivide_model(sub1_dodecahedron);
    models_sub2 := [5]Model{sub2_tetrahedron, sub2_octahedron, sub2_hexahedron, sub2_icosahedron, sub2_dodecahedron};
    fmt.println();
    
    sub3_tetrahedron := subdivide_model(sub2_tetrahedron);
    sub3_octahedron := subdivide_model(sub2_octahedron);
    sub3_hexahedron := subdivide_model(sub2_hexahedron);
    sub3_icosahedron := subdivide_model(sub2_icosahedron);
    sub3_dodecahedron := subdivide_model(sub2_dodecahedron);
    models_sub3 := [5]Model{sub3_tetrahedron, sub3_octahedron, sub3_hexahedron, sub3_icosahedron, sub3_dodecahedron};
    fmt.println();

    sub4_tetrahedron := subdivide_model(sub3_tetrahedron);
    sub4_octahedron := subdivide_model(sub3_octahedron);
    sub4_hexahedron := subdivide_model(sub3_hexahedron);
    sub4_icosahedron := subdivide_model(sub3_icosahedron);
    sub4_dodecahedron := subdivide_model(sub3_dodecahedron);
    models_sub4 := [5]Model{sub4_tetrahedron, sub4_octahedron, sub4_hexahedron, sub4_icosahedron, sub4_dodecahedron};
    fmt.println();


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
    mx_prev, my_prev: f64;
    glfw.GetCursorPos(window, &mx_prev, &my_prev);

    // for timings
    t_prev := glfw.GetTime();
    frame := 0;


    Enable(DEPTH_TEST);

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

        // update camera position:
        // W: forward, S: back, A: left, D: right, E: up, Q: down
        p += f*f32(glfw.GetKey(window, glfw.KEY_W) - glfw.GetKey(window, glfw.KEY_S))*dt;
        p += r*f32(glfw.GetKey(window, glfw.KEY_D) - glfw.GetKey(window, glfw.KEY_A))*dt;
        p += u*f32(glfw.GetKey(window, glfw.KEY_E) - glfw.GetKey(window, glfw.KEY_Q))*dt;

        // Main drawing part
        Clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);

        UseProgram(program);
        Uniform1f(GetUniformLocation_(program, "time\x00"), f32(glfw.GetTime()));

        V := view(r, u, f, p);
        P := math.perspective(3.1415926*45.0/180.0, 1280/720.0, 0.001, 100.0);

        for model, i in models {
            M := math.mat4_translate(math.Vec3{f32(i)*2.2, 0.0, 0.0});
            MV := math.mul(V, M);
            MVP := math.mul(P, MV);
            UniformMatrix4fv(GetUniformLocation_(program, "MVP\x00"), 1, FALSE, &MVP[0][0]);
            
            BindVertexArray(model.vao);
            DrawArrays(TRIANGLES, 0, i32(model.num_vertices));
        }

        for model, i in models_sub1 {
            M := math.mat4_translate(math.Vec3{f32(i)*2.2, 2.2, 0.0});
            MV := math.mul(V, M);
            MVP := math.mul(P, MV);
            UniformMatrix4fv(GetUniformLocation_(program, "MVP\x00"), 1, FALSE, &MVP[0][0]);
            
            BindVertexArray(model.vao);
            DrawArrays(TRIANGLES, 0, i32(model.num_vertices));
        }

        for model, i in models_sub2 {
            M := math.mat4_translate(math.Vec3{f32(i)*2.2, 4.4, 0.0});
            MV := math.mul(V, M);
            MVP := math.mul(P, MV);
            UniformMatrix4fv(GetUniformLocation_(program, "MVP\x00"), 1, FALSE, &MVP[0][0]);
            
            BindVertexArray(model.vao);
            DrawArrays(TRIANGLES, 0, i32(model.num_vertices));
        }

        for model, i in models_sub3 {
            M := math.mat4_translate(math.Vec3{f32(i)*2.2, 6.6, 0.0});
            MV := math.mul(V, M);
            MVP := math.mul(P, MV);
            UniformMatrix4fv(GetUniformLocation_(program, "MVP\x00"), 1, FALSE, &MVP[0][0]);
            
            BindVertexArray(model.vao);
            DrawArrays(TRIANGLES, 0, i32(model.num_vertices));
        }

        for model, i in models_sub4 {
            M := math.mat4_translate(math.Vec3{f32(i)*2.2, 8.8, 0.0});
            MV := math.mul(V, M);
            MVP := math.mul(P, MV);
            UniformMatrix4fv(GetUniformLocation_(program, "MVP\x00"), 1, FALSE, &MVP[0][0]);
            
            BindVertexArray(model.vao);
            DrawArrays(TRIANGLES, 0, i32(model.num_vertices));
        }

        
        {
            seed = 123;
            for i in 0..int(3.0*glfw.GetTime()) do rng();

            colors_font := font.get_colors();
            for i in 0..4 do colors_font[i] = font.Vec4{f32(rng()), f32(rng()), f32(rng()), 1.0};
            
            font.update_colors(4);

            str :: "The quick brown fox jumps over the lazy dog";
            str_colors: [len(str)]u16;
            for i in 0..len(str) do str_colors[i] = u16(i)&3;

            y_pos : f32 = 0.0;
            font.draw_string(0.0, y_pos, 20.0, str);                               y_pos += 20.0; // unformatted string with implicit palette index passing (implicit 0)
            font.draw_string(0.0, y_pos, 28.0, 3, str);                            y_pos += 28.0; // unformatted string with explicit palette index passing
            font.draw_string(0.0, y_pos, 24.0, str_colors[..], str);               y_pos += 24.0; // unformatted string with explicit palette index passing for the whole string
            font.draw_string(0.0, y_pos, 32.0, 2, str);                            y_pos += 32.0; // unformatted string with explicit palette index passing
            font.draw_format(0.0, y_pos, 16.0, "blehh %d %f: %s", 2, 3.14, str);   y_pos += 16.0; //   formatted string with implicit palette index passing (implicit 0)
            font.draw_format(0.0, y_pos, 20.0, 1, "blah %d %f: %s", 4, 6.28, str); y_pos += 20.0; //   formatted string with explicit palette index passing
        }
        
        
        glfw.SwapBuffers(window);
    }
}

// Right handed view matrix, defined from camera position and a local 
// camera coordinate system, namely right (X), up (Y) and forward (-Z).
// Hopefully this one gets added to core/math.odin eventually.
view :: proc(r, u, f, p: math.Vec3) -> math.Mat4 { 
    return math.Mat4 { // HERE
        {+r.x, +u.x, -f.x, 0.0},
        {+r.y, +u.y, -f.y, 0.0},
        {+r.z, +u.z, -f.z, 0.0},
        {-math.dot(r,p), -math.dot(u,p), math.dot(f,p), 1.0},
    };
}

// wrapper to use GetUniformLocation with an Odin string
// @NOTE: str has to be zero-terminated, so add a \x00 at the end
GetUniformLocation_ :: proc(program: u32, str: string) -> i32 {
    return gl.GetUniformLocation(program, &str[0]);;
}


error_callback :: proc(error: i32, desc: ^u8) #cc_c {
    fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
}

init_glfw :: proc(resx, resy: i32, title: string) -> (^glfw.window, bool) {
    glfw.SetErrorCallback(error_callback);

    if glfw.Init() == 0 {
        return nil, false;
    }

    glfw.WindowHint(glfw.SAMPLES, 0);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    window := glfw.CreateWindow(resx, resy, title, nil, nil);
    if window == nil {
        return nil, false;
    }

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
