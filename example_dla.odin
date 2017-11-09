
import "core:fmt.odin";
import "core:strings.odin";
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

    resx, resy := 900, 900;
    window := glfw.CreateWindow(i32(resx), i32(resy), "Odin Triangle Example Rendering", nil, nil);
    if window == nil do return;

    glfw.MakeContextCurrent(window);
    glfw.SwapInterval(0);


    set_proc_address :: proc(p: rawptr, name: string) { 
        (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(&name[0]));
    }
    gl.load_up_to(3, 3, set_proc_address);


    program, shader_success := gl.load_shaders("shaders/shader_dla.vs", "shaders/shader_dla.fs");
    defer gl.DeleteProgram(program);


    vao: u32;
    gl.GenVertexArrays(1, &vao);
    defer gl.DeleteVertexArrays(1, &vao);


    screen_texture: u32;
    gl.GenTextures(1, &screen_texture);
    gl.BindTexture(gl.TEXTURE_2D, screen_texture);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    Nx := resx/2;
    Ny := resy/2;
    grid := make([]f32, Nx*Ny);

    num_solids := 1;

    if true {
        /*
        for i in 0..Nx {
            grid[i] = 1;
        }
        for j in 0..Ny {
            grid[Nx*j] = 1;
        }
        */

        grid[(Nx/2) + Nx*(Ny/2)] = 1;
        min_x, max_x := Nx/2, Nx/2;
        min_y, max_y := Ny/2, Ny/2;

        // spawn walkers until the structures touches the "walls"
        for min_x > 0 && max_x < Nx-1 && min_y > 0 && max_y < Ny-1 && num_solids < Nx*Ny { 
        //for min_y > 0 && max_y < Ny-1 && num_solids < Nx*Ny { 
        //for grid[Nx/2 + Nx*(Ny/2)] == 0 {
            // initialize walker
            x0 := cast(int)max(f32(min_x - 10), 0.0);
            x1 := cast(int)min(f32(max_x + 10), f32(Nx)-1);

            y0 := cast(int)max(f32(min_y - 10), 0.0);
            y1 := cast(int)min(f32(max_y + 10), f32(Ny)-1);

            walker_x: int;
            walker_y: int;

            r := int(4.0*rng());
            switch r {
            case 0:
                walker_y = y0;
                walker_x = x0 + int(f64(x1-x0)*rng());
            case 1:
                walker_y = y1;
                walker_x = x0 + int(f64(x1-x0)*rng());
            case 2:
                walker_x = x0;
                walker_y = y0 + int(f64(y1-y0)*rng());
            case 3:
                walker_x = x1;
                walker_y = y0 + int(f64(y1-y0)*rng());
            }
            //walker_x = Nx/2;
            //walker_y = Ny/2;

            // do the walk
            for {
                r := int(4.0*rng());
                dx := r < 2 ? 2*r - 1 : 0;
                dy := r < 2 ? 0 : 2 * (r - 2) - 1;

                if grid[((walker_x+dx)%%Nx) + Nx*((walker_y+dy)%%Ny)] > 0 {
                    grid[walker_x + Nx*walker_y] = f32(num_solids+1.0);
                    break;
                } else {
                    walker_x = (walker_x+dx)%%Nx;
                    walker_y = (walker_y+dy)%%Ny;
                }
            }

            // check bounds
            min_x = min(min_x, walker_x);
            max_x = max(max_x, walker_x);
            min_y = min(min_y, walker_y);
            max_y = max(max_y, walker_y);
            num_solids += 1;
            if num_solids % 10 == 0 do fmt.println(num_solids);
        }
        fmt.println(num_solids, "solids");
    } else {
        // invasion percolation
        /*
        for i in 0..Nx {
            grid[i] = 1;
            grid[i+Nx*(Ny-1)] = 1;
        }
        for j in 0..Ny {
            grid[Nx*j] = 1;
            grid[Nx-1 + Nx*j] = 1;
        }
        */
        for i in 0..Nx {
            //grid[i+Nx*(Ny/2)] = 1;
        }
        grid[Nx/2 + Nx*(Ny/2)] = 1;

        filled := 2*(Nx-2) + 2*Ny;
        filled = 1;
        filled = Nx;

        values := make([]f32, Nx*Ny);
        for i in 0..Nx*Ny {
            values[i] = cast(f32)rng();
        }


        for filled < Nx*Ny {
            weakest := f32(10.0);
            weakest_id := -1;
            for i in 0..Nx*Ny {
                if grid[i] > 0 do continue;

                x := i % Nx;
                y := i / Nx;

                if grid[((x+1)%%Nx) + Nx*y] > 0 || grid[((x-1)%%Nx) + Nx*y] > 0 || grid[x + Nx*((y+1)%%Ny)] > 0 || grid[x + Nx*((y-1)%%Ny)] > 0 {
                    if values[i] < weakest {
                        weakest = values[i];
                        weakest_id = i;
                    }
                }
            }
            if weakest_id == -1 do break;
            grid[weakest_id] = f32(num_solids+1.0);
            num_solids += 1;
            filled += 1;
            fmt.println(filled, Nx*Ny);
        }
    }





    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.R32F, i32(Nx), i32(Ny), 0, gl.RED, gl.FLOAT, &grid[0]);


    get_uniform_location :: proc(program: u32, str: string) -> i32 {
        return gl.GetUniformLocation(program, &str[0]);;
    }

    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for glfw.WindowShouldClose(window) == glfw.FALSE {
        glfw.calculate_frame_timings(window);

        glfw.PollEvents();

        gl.UseProgram(program);
        gl.BindVertexArray(vao);
        gl.ActiveTexture(gl.TEXTURE0);

        gl.Uniform1f(get_uniform_location(program, "time"), f32(glfw.GetTime()));
        gl.Uniform1i(get_uniform_location(program, "num"), i32(num_solids));

        gl.Clear(gl.COLOR_BUFFER_BIT);
        gl.BindTexture(gl.TEXTURE_2D, screen_texture);
        gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, 1);

        glfw.SwapBuffers(window);
    }
}


seed : u32 = 12342311;
rng :: proc() -> f64 {
    seed *= 16807;
    return f64(seed) / f64(0x100000000);
}