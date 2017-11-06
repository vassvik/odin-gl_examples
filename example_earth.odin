import "core:fmt.odin";
import "core:math.odin";
import "core:os.odin";
import "core:mem.odin";
import "core:strings.odin";

import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";
import stbi "shared:stb_image.odin";


Image :: struct {
    width, height, channels: i32,
    filename: string,
    data: []u8,
}


// Unit isocahedron vertex positions. 
// From http://paulbourke.net/geometry/platonic/
ai :: 0.5;
bi :: 1.0/(1.0 + math.SQRT_FIVE);
icosahedron_vertices := [...]math.Vec3 {
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

Vertex :: struct #ordered {
    position, normal: math.Vec3,
};

Model :: struct {
    vertices: []Vertex,
    
    num_vertices: int,
    num_triangles: int,
    
    vao: u32,
    vbo: u32,
};

model_init_and_upload :: proc(using model: ^Model) {
    gl.CreateBuffers(1, &vbo);
    gl.NamedBufferData(vbo, size_of(Vertex)*num_vertices, &vertices[0], gl.STATIC_DRAW);
    
    gl.CreateVertexArrays(1, &vao);
    gl.VertexArrayVertexBuffer(vao, 0, vbo, 0, size_of(Vertex));

    gl.EnableVertexArrayAttrib(vao, 0);
    gl.EnableVertexArrayAttrib(vao, 1);
    
    gl.VertexArrayAttribFormat(vao, 0, 3, gl.FLOAT, gl.FALSE, cast(u32)offset_of(Vertex, position));
    gl.VertexArrayAttribFormat(vao, 1, 3, gl.FLOAT, gl.FALSE, cast(u32)offset_of(Vertex, normal));

    gl.VertexArrayAttribBinding(vao, 0, 0);
    gl.VertexArrayAttribBinding(vao, 1, 0);
}

main :: proc() {
    error_callback :: proc"c"(error: i32, desc: ^u8) {
        fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
    }
    glfw.SetErrorCallback(error_callback);

    // init glfw
    if glfw.Init() == 0 do return;
    defer glfw.Terminate();

    // create window
    glfw.WindowHint(glfw.SAMPLES, 16);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    resx, resy := 1920.0, 1000.0;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Triangle Example Rendering", nil, nil);
    if window == nil do return;

    // setup glfw state
    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);


    // load opengl function pointers
    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(4, 5, set_proc_address);


    // Read cubemap textures
    filenames := [...]string { // @NOTE: This order is wrong! The normal is flipped inside the shader to correct for this as a quick hack
        "earth-cubemap/earth-cubemap-0.png",
        "earth-cubemap/earth-cubemap-1.png",
        "earth-cubemap/earth-cubemap-2.png",
        "earth-cubemap/earth-cubemap-3.png",
        "earth-cubemap/earth-cubemap-4.png",
        "earth-cubemap/earth-cubemap-5.png",
    };
    fmt.println(size_of(Vertex), size_of(math.Vec3));

    images: [6]Image;
    for _, i in filenames {
        using img := &images[i];
        filename = filenames[i];
        data = mem.slice_ptr(stbi.load(&filename[0], &width, &height, &channels, 3), int(width*height*3));
        fmt.printf("Read file `%s`: width = %d, height = %d, channels = %d\n", filename, width, height, channels);
    }


    models: [6]Model;

    // Create base model out of icosahedron vertices
    models[0].num_vertices = len(icosahedron_vertices);
    models[0].num_triangles = models[0].num_vertices/3;
    models[0].vertices = make([]Vertex, models[0].num_vertices);
    for vertex, i in icosahedron_vertices {
        models[0].vertices[i] = Vertex{math.norm(vertex), math.norm(vertex)};
    }

    // subdivide 5 times, each subdivision takes a triangle and splits it into 4 pieces, 
    // and re-projecting each position onto the surface of the unit sphere
    for j in 0..5 {
        models[j+1].num_vertices = models[j].num_vertices*4;
        models[j+1].num_triangles = models[j].num_triangles*4;
        models[j+1].vertices = make([]Vertex, models[j+1].num_vertices);

        for i in 0..models[j].num_triangles {
            v1 := models[j].vertices[3*i+0].position;
            v2 := models[j].vertices[3*i+1].position;
            v3 := models[j].vertices[3*i+2].position;
            v12 := math.norm0((v1 + v2)/2.0);
            v23 := math.norm0((v3 + v2)/2.0);
            v13 := math.norm0((v1 + v3)/2.0);

            models[j+1].vertices[12*i+0].position = v1;
            models[j+1].vertices[12*i+1].position = v12;
            models[j+1].vertices[12*i+2].position = v13;

            models[j+1].vertices[12*i+3].position = v2;
            models[j+1].vertices[12*i+4].position = v23;
            models[j+1].vertices[12*i+5].position = v12;

            models[j+1].vertices[12*i+6].position = v3;
            models[j+1].vertices[12*i+7].position = v13;
            models[j+1].vertices[12*i+8].position = v23;

            models[j+1].vertices[12*i+9].position  = v12;
            models[j+1].vertices[12*i+10].position = v23;
            models[j+1].vertices[12*i+11].position = v13;
        }

        // normal is equal to position for a sphere!
        for i in 0..models[j+1].num_vertices {
            models[j+1].vertices[i].normal = math.norm0(models[j+1].vertices[i].position);
        }

        fmt.printf("Created model of %d vertices by subdivided model of %d vertices\n", models[j+1].num_vertices, models[j].num_vertices);
    }

    // create and initialize vaos and upload the data
    for _, i in models {
        model_init_and_upload(&models[i]);
    }


    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_earth.vs", "shaders/shader_earth.fs");
    defer gl.DeleteProgram(program);
    gl.UseProgram(program);

    // get all active uniforms
    uniform_infos := gl.get_uniforms_from_program(program);
    fmt.println(uniform_infos);

    // create textures and upload data
    texture: u32;
    gl.CreateTextures(gl.TEXTURE_CUBE_MAP, 1, &texture);
    gl.BindTextureUnit(0, texture);

    gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.TextureParameteri(texture, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);  

    gl.TextureStorage2D(texture, 9, gl.RGBA8, images[0].width, images[0].height);
    for _, i in images {
        using img := &images[i];
        gl.TextureSubImage3D(texture, 0, 0, 0, i32(i), width, height, 1, gl.RGB, gl.UNSIGNED_BYTE, &data[0]);
    }

    gl.GenerateTextureMipmap(texture); 


    when ODIN_OS == "windows" {
        // get the current time stamp of shaders
        last_vertex_time := os.last_write_time_by_name("shaders/shader_earth.vs");
        last_fragment_time := os.last_write_time_by_name("shaders/shader_earth.fs");
    }
    
    // main loop
    gl.Enable(gl.DEPTH_TEST);
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for glfw.WindowShouldClose(window) == glfw.FALSE {
        // show fps in window title
        glfw.calculate_frame_timings(window);
        
        // listen to inut
        glfw.PollEvents();
        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do glfw.SetWindowShouldClose(window, glfw.TRUE);

        when ODIN_OS == "windows" {
            // update the shaders if they've changed (saved)
            program, last_vertex_time, last_fragment_time = gl.update_shader_if_changed("shaders/shader_earth.vs", "shaders/shader_earth.fs", program, last_vertex_time, last_fragment_time);
        }

        // clear screen
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // setup shader program and uniforms
        gl.UseProgram(program);
        gl.ProgramUniform1f(program, uniform_infos["time"].location, f32(glfw.GetTime()));
        gl.ProgramUniform2f(program, uniform_infos["resolution"].location, f32(resx), f32(resy));

        // draw each model
        gl.BindTextureUnit(0, texture);
        for model, i in models {
            gl.BindVertexArray(model.vao);
            gl.ProgramUniform3f(program, uniform_infos["offset"].location, 1.1*(-1.0 + 1.0*f32(i%3)), 0.5 - 1.0*f32(i/3), 0.0);
            gl.DrawArrays(gl.TRIANGLES, 0, i32(model.num_vertices));
        }
        
        glfw.SwapBuffers(window);
    }
}
