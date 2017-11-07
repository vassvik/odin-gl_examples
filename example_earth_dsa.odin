/*
    Odin OpenGL example: Subdivided spheres and cubemap texturing using Direct State Access functions

    A unit icosahedron is recursively subdivided by splitting each triangle into four triangles, 
    and reprojecting the vertices onto the unit sphere. 

    6 images of the earth are used to create a cubemap texture that is sampled based on the vertex normals.

    This example is slightly different from example_earth.odin due to using the recent Direct State Access functionality.
    DSA is in particular used to reduce the overhead from changing OpenGL state.
    
    The major changes is that, for the most part, instead of binding to a buffer, the buffer is passed directly to a function instead.

    In this example, this concerns vertex array objects, vertex buffer objects, texture and passing uniforms. 
    
    Requires OpenGL 4.5 support.

    Dependencies: odin-glfw, odin-gl, stb_image
*/

import "core:fmt.odin";
import "core:strings.odin";

import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";

export "example_earth_common.odin"; // make_models and load_cubemap_images


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

create_and_upload_cubemap :: proc(images: [6]Image) -> u32 {
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

    return texture;
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
    glfw.WindowHint(glfw.SAMPLES, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    resx, resy := 1920.0, 1000.0;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Sphere subdivision and Cubemap texturing, using Direct State Access (OpenGL 4.5)", nil, nil);
    if window == nil do return;

    // setup glfw state
    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    // load opengl function pointers
    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(4, 5, set_proc_address);

    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_earth_dsa.vs", "shaders/shader_earth_dsa.fs");
    defer gl.DeleteProgram(program);
    gl.UseProgram(program);

    // get all active uniforms
    uniform_infos := gl.get_uniforms_from_program(program);
    fmt.println(uniform_infos);

    // Create base and subdivided models, and upload to gpu
    models := make_models(6);
    for _, i in models {
        model_init_and_upload(&models[i]);
    }

    // load and setup images, upload texture
    images := load_cubemap_images();
    texture := create_and_upload_cubemap(images);

    // main loop
    gl.Enable(gl.DEPTH_TEST);
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for glfw.WindowShouldClose(window) == glfw.FALSE {
        // show fps in window title
        glfw.calculate_frame_timings(window);

        // listen to inut
        glfw.PollEvents();
        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do glfw.SetWindowShouldClose(window, glfw.TRUE);

        // clear screen
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // setup shader program and uniforms
        gl.UseProgram(program);
        gl.ProgramUniform1f(program, uniform_infos["time"].location, f32(glfw.GetTime()));
        gl.ProgramUniform2f(program, uniform_infos["resolution"].location, f32(resx), f32(resy));

        // draw each model
        gl.BindTextureUnit(0, texture);
        for model, i in models {
            gl.ProgramUniform3f(program, uniform_infos["offset"].location, 1.1*(-1.0 + 1.0*f32(i%3)), 0.5 - 1.0*f32(i/3), 0.0);
            gl.BindVertexArray(model.vao);
            gl.DrawArrays(gl.TRIANGLES, 0, i32(model.num_vertices));
        }
        
        glfw.SwapBuffers(window);
    }
}
