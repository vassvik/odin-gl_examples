import "core:fmt.odin";
import "core:os.odin";

import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";

main :: proc() {
    error_callback :: proc"c"(error: i32, desc: cstring) {
        fmt.printf("Error code %d:\n    %s\n", error, desc);
    }
    glfw.SetErrorCallback(error_callback);

    // init glfw
    if glfw.Init() == 0 do return;
    defer glfw.Terminate();

    // create window
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    resx, resy := 1600.0, 900.0;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Triangle Example Rendering", nil, nil);
    if window == nil do return;

    // setup glfw state
    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    // load opengl function pointers
    gl.load_up_to(3, 3, glfw.set_proc_address);

    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_texture.vs", "shaders/shader_texture.fs");
    defer gl.DeleteProgram(program);

    // get all active uniforms
    uniform_infos := gl.get_uniforms_from_program(program);

    // setup vao
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    gl.BindVertexArray(vao);
    defer gl.DeleteVertexArrays(1, &vao);

    // setup texture
    // create 2D texture
    texture_width :: 4;
    texture_height :: 4;
    texture_data := [?]u8 {
        255, 152,   0, // orange
        156,  39, 176, // purple
          3, 169, 244, // light blue
        139, 195,  74, // light green

        255,  87,  34, // deep orange
        103,  58, 183, // deep purple
          0, 188, 212, // cyan
        205, 220,  57, // lime

        244,  67,  54, // red
         63,  81, 181, // indigo
          0, 150, 137, // teal
        255, 235,  59, // yellow
        
        233,  30,  99, // pink
         33, 150, 243, // blue
         76, 175,  80, // green
        255, 193,   7, // amber
    };

    texture: u32;
    gl.GenTextures(1, &texture);
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, texture);

    // upload texture
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, texture_width, texture_height, 0, gl.RGB, gl.UNSIGNED_BYTE, &texture_data[0]);

    // main loop
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for !glfw.WindowShouldClose(window) {
        // show fps in window title
        glfw.calculate_frame_timings(window);
        
        // listen to inut
        glfw.PollEvents();

        if glfw.GetKey(window, glfw.KEY_ESCAPE) do glfw.SetWindowShouldClose(window, true);

        // clear screen
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // setup shader program and uniforms
        gl.UseProgram(program);
        gl.Uniform1f(uniform_infos["time"].location, f32(glfw.GetTime()));
        
        // draw stuff
        gl.BindVertexArray(vao);
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, 4);
        
        glfw.SwapBuffers(window);
    }
}
