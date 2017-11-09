import "core:fmt.odin";
import "core:strings.odin";
import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";


main :: proc() {
    // setup glfw
    error_callback :: proc "c" (error: i32, desc: ^u8) {
        fmt.printf("Error code %d:\n    %s\n", error, strings.to_odin_string(desc));
    }
    glfw.SetErrorCallback(error_callback);

    if glfw.Init() == 0 do return;
    defer glfw.Terminate();

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    resx, resy := 1600.0, 900.0;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Shadertoy Lite Example, No Buffers", nil, nil);
    if window == nil do return;

    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    // setup opengl
    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(3, 3, set_proc_address);

    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_shaderboy_nobuffer.vs", "shaders/shader_shaderboy.fs");
    defer gl.DeleteProgram(program);

    // setup vao
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    defer gl.DeleteVertexArrays(1, &vao);
    gl.BindVertexArray(vao);

    // main loop
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for glfw.WindowShouldClose(window) == glfw.FALSE {
        // show fps in window title
        glfw.calculate_frame_timings(window);
        
        // listen to inut
        glfw.PollEvents();

        // clear screen
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // setup shader program and uniforms
        gl.UseProgram(program);
        gl.Uniform1f(get_uniform_location(program, "iGlobalTime\x00"), f32(glfw.GetTime()));
        gl.Uniform3f(get_uniform_location(program, "iResolution\x00"), f32(resx), f32(resy), f32(0.0));
        
        // draw stuff
        gl.BindVertexArray(vao);
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4);
        
        glfw.SwapBuffers(window);
    }
}

// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
    return gl.GetUniformLocation(program, &str[0]);;
}
