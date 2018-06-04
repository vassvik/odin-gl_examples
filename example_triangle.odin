import "core:fmt.odin";
import "core:strings.odin";
import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";


main :: proc() {
    // setup glfw
    error_callback :: proc"c"(error: i32, desc: cstring) {
        fmt.printf("Error code %d:\n    %s\n", error, desc);
    }
    glfw.SetErrorCallback(error_callback);

    if glfw.Init() == 0 do return;
    defer glfw.Terminate();

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    resx, resy := 1600.0, 900.0;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Triangle Example Rendering", nil, nil);
    if window == nil do return;

    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    // setup opengl
    set_proc_address :: proc(p: rawptr, name: cstring) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name));
    }
    gl.load_up_to(3, 3, set_proc_address);

    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_triangle.vs", "shaders/shader_triangle.fs");
    defer gl.DeleteProgram(program);

    // setup vao
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    defer gl.DeleteVertexArrays(1, &vao);

    gl.BindVertexArray(vao);

    // setup vbo
    vertex_data := [?]f32{
        -0.3, -0.3,
         0.3, -0.3,
         0.0,  0.5,
    };

    vbo: u32;
    gl.GenBuffers(1, &vbo);
    defer gl.DeleteBuffers(1, &vbo);

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertex_data), &vertex_data[0], gl.STATIC_DRAW);

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, nil);
    
    // main loop
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    gl.Enable(gl.DEPTH_TEST);
    for !glfw.WindowShouldClose(window) {
        // show fps in window title
        glfw.calculate_frame_timings(window);
        
        // listen to inut
        glfw.PollEvents();

        // clear screen
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // setup shader program and uniforms
        gl.UseProgram(program);
        gl.Uniform1f(get_uniform_location(program, "time\x00"), f32(glfw.GetTime()));
        
        // draw stuff
        gl.BindVertexArray(vao);
        gl.DrawArraysInstanced(gl.TRIANGLES, 0, 3, 2);
        
        glfw.SwapBuffers(window);
    }
}

// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
    return gl.GetUniformLocation(program, &str[0]);;
}
