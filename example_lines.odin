import "core:fmt.odin";
import "core:math.odin";
import "core:mem.odin";
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

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5);
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

    resx, resy := 1600.0/2, 1600.0/2;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Shadertoy Lite Example, No Buffers", nil, nil);
    if window == nil do return;

    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);

    // setup opengl
    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(4, 5, set_proc_address);

    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_lines.vs", "shaders/shader_lines.fs");
    defer gl.DeleteProgram(program);

    // setup vao
    vao: u32;
    gl.GenVertexArrays(1, &vao);
    defer gl.DeleteVertexArrays(1, &vao);
    gl.BindVertexArray(vao);

    //
    MAX_BUFFER_SIZE :: 65536;
    generic_storage_buffer: u32;
    gl.CreateBuffers(1, &generic_storage_buffer);
    gl.NamedBufferData(generic_storage_buffer, MAX_BUFFER_SIZE, nil, gl.STATIC_DRAW);

    Data :: struct #ordered {
        position, tangent, normal: math.Vec2,
    };

    num := 40;
    data := mem.slice_ptr(cast(^Data)gl.MapNamedBuffer(generic_storage_buffer, gl.WRITE_ONLY), num+1);   
    for i in 0...num {
        t1 := -1.0 + 2.0*(f32(i-1)/f32(num));
        t2 := -1.0 + 2.0*(f32(i+0)/f32(num));
        t3 := -1.0 + 2.0*(f32(i+1)/f32(num));
        p1 := math.Vec2{t1, 0.9*math.sin(2.0*math.PI*t1 + f32(glfw.GetTime()))};
        p2 := math.Vec2{t2, 0.9*math.sin(2.0*math.PI*t2 + f32(glfw.GetTime()))};
        p3 := math.Vec2{t3, 0.9*math.sin(2.0*math.PI*t3 + f32(glfw.GetTime()))};
        tangent := (p3 - p1)/2.0;
        normal := math.norm(math.Vec2{-tangent[1], tangent[0]});

        data[i] = Data{p2, tangent, normal};
        fmt.println(i, data[i]);
    }
    gl.UnmapNamedBuffer(generic_storage_buffer);
    gl.BindBufferRange(gl.SHADER_STORAGE_BUFFER, 0, generic_storage_buffer, 0, (num+1)*size_of(Data));

    F5_prev := glfw.RELEASE;

    // main loop
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for glfw.WindowShouldClose(window) == glfw.FALSE {


        // show fps in window title
        glfw.calculate_frame_timings(window);
        
        // listen to inut
        glfw.PollEvents();

        if (glfw.GetKey(window, glfw.KEY_F5) == glfw.PRESS) {
            if  F5_prev == glfw.RELEASE {
                new_program, success := gl.load_shaders("shaders/shader_lines.vs", "shaders/shader_lines.fs");
                if success {
                    gl.DeleteProgram(program);
                    program = new_program;
                    fmt.println("Updated shaders");
                }
            }
            F5_prev = glfw.PRESS;
        } else {
            F5_prev = glfw.RELEASE;
        }

        // clear screen
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // setup shader program and uniforms
        gl.UseProgram(program);
        gl.Uniform1f(get_uniform_location(program, "iGlobalTime\x00"), f32(glfw.GetTime()));
        gl.Uniform3f(get_uniform_location(program, "iResolution\x00"), f32(resx), f32(resy), f32(0.0));
        gl.PointSize(5.0);
        // draw stuff
        gl.BindVertexArray(vao);
        gl.Uniform1i(get_uniform_location(program, "is_point\x00"), 0);
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 8, i32(num));
        gl.Uniform1i(get_uniform_location(program, "is_point\x00"), 1);
        gl.DrawArraysInstanced(gl.POINTS, 0, 8, i32(num));
        
        glfw.SwapBuffers(window);
    }
}

// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
    return gl.GetUniformLocation(program, &str[0]);;
}
