/*
    Odin OpenGL example: Subdivided spheres and cubemap texturing

    A unit icosahedron is recursively subdivided by splitting each triangle into four triangles, 
    and reprojecting the vertices onto the unit sphere. 

    6 images of the earth are used to create a cubemap texture that is sampled based on the vertex normals.

    Requires OpenGL 3.3 support.

    Dependencies: odin-glfw, odin-gl, stb_image
*/

import "core:fmt.odin";
import "core:math.odin";
import "core:strings.odin";

import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";

export "example_earth_common.odin"; // make_models and load_cubemap_images


model_init_and_upload :: proc(using model: ^Model) {
    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao);

    gl.GenBuffers(1, &vbo);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, size_of(Vertex)*num_vertices, &vertices[0], gl.STATIC_DRAW);

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), cast(rawptr)offset_of(Vertex, position)); // NOTE: change the signature of glVertexAttribpointer to use uintptr

    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), cast(rawptr)offset_of(Vertex, normal)); 
}

create_and_upload_cubemap :: proc(images: [6]Image) -> u32 {
    texture: u32;
    gl.GenTextures(1, &texture);
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, texture);

    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);  

    for _, i in images {
        using img := &images[i];
        gl.TexImage2D(u32(gl.TEXTURE_CUBE_MAP_POSITIVE_X + i), 0, gl.RGBA8, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, &data[0]);
    }

    gl.GenerateMipmap(gl.TEXTURE_CUBE_MAP); 

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
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    resx, resy := 1920.0, 1000.0;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Sphere subdivision and Cubemap texturing (OpenGL 3.3)", nil, nil);
    if window == nil do return;

    // setup glfw state
    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    // load opengl function pointers
    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(3, 3, set_proc_address);

    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_earth.vs", "shaders/shader_earth.fs");
    defer gl.DeleteProgram(program);
    gl.UseProgram(program);

    // get all active uniforms
    uniform_infos := gl.get_uniforms_from_program(program);
    fmt.println(uniform_infos);

    // Create base and subdivided models, and upload to gpu
    models := make_models(8);
    for _, i in models do model_init_and_upload(&models[i]);

    // load and setup images, upload texture
    images := load_cubemap_images();
    texture := create_and_upload_cubemap(images);
    gl.Uniform1f(uniform_infos["cubemap_sampler"].location, 0); // needs to explicitly tell the shader about the texture unit used

    // main loop
    gl.Enable(gl.DEPTH_TEST);
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for !glfw.WindowShouldClose(window) {
        // show fps in window title
        glfw.calculate_frame_timings(window);

        // listen to inut
        glfw.PollEvents();
        if glfw.GetKey(window, glfw.KEY_ESCAPE) do glfw.SetWindowShouldClose(window, true);

        // clear screen
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // setup shader program, constant uniforms and texture
        gl.UseProgram(program);
        gl.Uniform1f(uniform_infos["time"].location, f32(glfw.GetTime()));
        gl.Uniform2f(uniform_infos["resolution"].location, f32(resx), f32(resy));
        gl.BindTexture(gl.TEXTURE_CUBE_MAP, texture);

        M0 := math.mat4_rotate(math.Vec3{1.0, 0.0, 0.0}, math.PI);

        // draw each model
        for model, i in models {
            offset := math.Vec3{1.1*(-1.25 + 0.62*f32(i%5)), 0.5 - 1.0*f32(i/5), 0.0};
            R := math.mat4_rotate(offset, f32(glfw.GetTime())*(0.5 + math.cos(math.length(offset))));
            T := math.mat4_translate(offset);
            M := math.mul(T, math.mul(R, M0));
            gl.UniformMatrix4fv(uniform_infos["M"].location, 1, gl.FALSE, &M[0][0]);
            
            gl.BindVertexArray(model.vao);
            gl.DrawArrays(gl.TRIANGLES, 0, i32(model.num_vertices));
        }
        
        glfw.SwapBuffers(window);
    }
}
