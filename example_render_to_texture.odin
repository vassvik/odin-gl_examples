
import "core:fmt.odin";
import "core:strings.odin";
import "core:os.odin";
import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";


main :: proc() {
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
    window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Triangle Example Rendering", nil, nil);
    if window == nil do return;

    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(1);


    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(3, 3, set_proc_address);


    program, shader_success := gl.load_shaders("shaders/shader_render_to_texture.vs", "shaders/shader_render_to_texture.fs");
    defer gl.DeleteProgram(program);


    vao: u32;
    gl.GenVertexArrays(1, &vao);
    defer gl.DeleteVertexArrays(1, &vao);


    screen_texture: u32;
    gl.GenTextures(1, &screen_texture);
    gl.BindTexture(gl.TEXTURE_2D, screen_texture);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, i32(resx), i32(resy), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);


    screen_texture2: u32;
    gl.GenTextures(1, &screen_texture2);
    gl.BindTexture(gl.TEXTURE_2D, screen_texture2);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, i32(resx), i32(resy), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil);


    pick_texture: u32;
    gl.GenTextures(1, &pick_texture);
    gl.BindTexture(gl.TEXTURE_2D, pick_texture);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, i32(resx), i32(resy), 0, gl.RGBA, gl.FLOAT, nil);


    fbo: u32;
    gl.GenFramebuffers(1, &fbo);
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, screen_texture, 0);
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, pick_texture, 0);

    buffers := [...]u32{ gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1 };
    gl.DrawBuffers(2, &buffers[0]);

    /*
    depthrenderbuffer: u32;
    gl.GenRenderbuffers(1, &depthrenderbuffer);
    gl.BindRenderbuffer(gl.RENDERBUFFER, depthrenderbuffer);
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, i32(resx), i32(resy));
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depthrenderbuffer);
    */
    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE do fmt.printf("Error setting up framebuffer\n");


    fbo2: u32;
    gl.GenFramebuffers(1, &fbo2);
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo2);
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, screen_texture2, 0);
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, pick_texture, 0);

    buffers2 := [...]u32{ gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1 };
    gl.DrawBuffers(2, &buffers2[0]);

    /*
    depthrenderbuffer: u32;
    gl.GenRenderbuffers(1, &depthrenderbuffer);
    gl.BindRenderbuffer(gl.RENDERBUFFER, depthrenderbuffer);
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, i32(resx), i32(resy));
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depthrenderbuffer);
    */
    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE do fmt.printf("Error setting up framebuffer\n");


    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);


    get_uniform_location :: proc(program: u32, str: string) -> i32 {
        return gl.GetUniformLocation(program, &str[0]);;
    }
    when ODIN_OS == "windows" {
        last_vertex_time := os.last_write_time_by_name("shaders/shader_texture.vs");
        last_fragment_time := os.last_write_time_by_name("shaders/shader_texture.fs");
    }
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for !glfw.WindowShouldClose(window) {
        glfw.calculate_frame_timings(window);

        glfw.PollEvents();

        when ODIN_OS == "windows" {
            current_vertex_time := os.last_write_time_by_name("shaders/shader_texture.vs");
            current_fragment_time := os.last_write_time_by_name("shaders/shader_texture.fs");

            if (current_vertex_time != last_vertex_time || current_fragment_time != last_fragment_time) {
                new_program, success := gl.load_shaders("shaders/shader_render_to_texture.vs", "shaders/shader_render_to_texture.fs");
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

        gl.UseProgram(program);
        gl.BindVertexArray(vao);
        gl.ActiveTexture(gl.TEXTURE0);

        // render to texture
        gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.Uniform1i(get_uniform_location(program, "mode\x00"), 0);
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, 9);

        // display texture and optionally do some post-processing
        /*
        gl.BindFramebuffer(gl.FRAMEBUFFER, fbo2 );
        gl.Clear(gl.COLOR_BUFFER_BIT);
        gl.BindTexture(gl.TEXTURE_2D, screen_texture);
        gl.Uniform1i(get_uniform_location(program, "mode\x00"), 1);
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, 9);
        */

        gl.BindFramebuffer(gl.FRAMEBUFFER, 0 );
        gl.Clear(gl.COLOR_BUFFER_BIT);
        gl.BindTexture(gl.TEXTURE_2D, screen_texture);
        gl.Uniform1i(get_uniform_location(program, "mode\x00"), 1);
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, 1);
        
        glfw.SwapBuffers(window);
    }
}
