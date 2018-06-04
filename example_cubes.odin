/*
    OpenGL example: Rendering cubes arranged in a cubic lattice using instancing.

    A local time dependent scale transformation is applied in the vertex shader to 
    each cube using gl_InstanceID.
    
    Requires OpenGL 3.3 support.
*/

import "core:fmt.odin";
import "core:math.odin";

import "shared:odin-glfw/glfw.odin";
import "shared:odin-gl/gl.odin";

export "common_3D.odin" // for generic 3D camera stuff

cube_vertices := [...]math.Vec3 {
    {-0.5, -0.5, -0.5}, { 0.5, -0.5, -0.5}, { 0.5, -0.5,  0.5}, {-0.5, -0.5,  0.5},
    {-0.5, -0.5, -0.5}, {-0.5, -0.5,  0.5}, {-0.5,  0.5,  0.5}, {-0.5,  0.5, -0.5},
    {-0.5, -0.5,  0.5}, { 0.5, -0.5,  0.5}, { 0.5,  0.5,  0.5}, {-0.5,  0.5,  0.5},
    {-0.5,  0.5, -0.5}, {-0.5,  0.5,  0.5}, { 0.5,  0.5,  0.5}, { 0.5,  0.5, -0.5},
    { 0.5, -0.5, -0.5}, { 0.5,  0.5, -0.5}, { 0.5,  0.5,  0.5}, { 0.5, -0.5,  0.5},
    {-0.5, -0.5, -0.5}, {-0.5,  0.5, -0.5}, { 0.5,  0.5, -0.5}, { 0.5, -0.5, -0.5},
};

cube_normals := [...]math.Vec3 {
    { 0.0, -1.0,  0.0}, { 0.0, -1.0,  0.0}, { 0.0, -1.0,  0.0}, { 0.0, -1.0,  0.0},
    {-1.0,  0.0,  0.0}, {-1.0,  0.0,  0.0}, {-1.0,  0.0,  0.0}, {-1.0,  0.0,  0.0},
    { 0.0,  0.0,  1.0}, { 0.0,  0.0,  1.0}, { 0.0,  0.0,  1.0}, { 0.0,  0.0,  1.0},
    { 0.0,  1.0,  0.0}, { 0.0,  1.0,  0.0}, { 0.0,  1.0,  0.0}, { 0.0,  1.0,  0.0},
    { 1.0,  0.0,  0.0}, { 1.0,  0.0,  0.0}, { 1.0,  0.0,  0.0}, { 1.0,  0.0,  0.0},
    { 0.0,  0.0, -1.0}, { 0.0,  0.0, -1.0}, { 0.0,  0.0, -1.0}, { 0.0,  0.0, -1.0},
};

cube_elements := [...]u32 {
     0,  1,  2,   0,  2,  3,
     4,  5,  6,   4,  6,  7,
     8,  9, 10,   8, 10, 11,
    12, 13, 14,  12, 14, 15,
    16, 17, 18,  16, 18, 19,
    20, 21, 22,  20, 22, 23,
};

main :: proc() {
    // Init glfw
    resx, resy := 1600.0, 900.0;
    window := glfw.init_helper(int(resx), int(resy));
    if window == nil do return;
    defer glfw.Terminate();
    
    // get opengl function pointers
    gl.load_up_to(3, 3, glfw.set_proc_address);

    // load shaders
    program, shader_success := gl.load_shaders("shaders/shader_cubes.vs", "shaders/shader_cubes.fs");
    defer gl.DeleteProgram(program);
    
    // get all active uniforms for this program
    uniform_infos := gl.get_uniforms_from_program(program);

    // Define instanced position of each cube
    N :: 64;
    cube_positions := make([]math.Vec3, N*N*N);
    defer free(cube_positions);

    for k in 0..N do for j in 0..N do for i in 0..N {
        cube_positions[k*N*N + j*N + i] = math.Vec3{1.5*cast(f32)i, 1.5*cast(f32)j, 1.5*cast(f32)k};
    }

    // setup buffers and upload vertex attributes
    vao, vbo_position, vbo_normal, ebo, vbo_instanced: u32;
    gl.GenVertexArrays(1, &vao);
    gl.GenBuffers(1, &vbo_position);
    gl.GenBuffers(1, &vbo_normal);
    gl.GenBuffers(1, &vbo_instanced);
    gl.GenBuffers(1, &ebo);
    defer {   
        gl.DeleteVertexArrays(1, &vao);
        gl.DeleteBuffers(1, &vbo_position);
        gl.DeleteBuffers(1, &vbo_normal);
        gl.DeleteBuffers(1, &vbo_instanced);
        gl.DeleteBuffers(1, &ebo);
    }
    gl.BindVertexArray(vao);

    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);
    gl.EnableVertexAttribArray(2);
    gl.VertexAttribDivisor(0, 0);
    gl.VertexAttribDivisor(1, 0);
    gl.VertexAttribDivisor(2, 1); // instanced

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo_position);
    gl.BufferData(gl.ARRAY_BUFFER, size_of(cube_vertices), &cube_vertices[0], gl.STATIC_DRAW);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, nil);

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo_normal);
    gl.BufferData(gl.ARRAY_BUFFER, size_of(cube_normals), &cube_normals[0], gl.STATIC_DRAW);
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 0, nil);

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo_instanced);
    gl.BufferData(gl.ARRAY_BUFFER, size_of(math.Vec3)*len(cube_positions), &cube_positions[0], gl.STATIC_DRAW);
    gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 0, nil);

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(cube_elements), &cube_elements[0], gl.STATIC_DRAW);

    // define camera
    cam: Camera;
    init_camera(&cam);

    // for mouse movement
    mx_prev, my_prev := glfw.GetCursorPos(window);

    // for timings
    t_prev := glfw.GetTime();

    // Main loop
    gl.Enable(gl.DEPTH_TEST);
    gl.ClearColor(1.0, 1.0, 1.0, 1.0);
    for glfw.WindowShouldClose(window) == glfw.FALSE {
        glfw.calculate_frame_timings(window);
        
        // handle input
        glfw.PollEvents();
        if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS do glfw.SetWindowShouldClose(window, glfw.TRUE);

        // time calculations for fps-independent movement speed
        t_now := glfw.GetTime();
        dt := f32(t_now - t_prev);
        t_prev = t_now;

        if glfw.GetKey(window, glfw.KEY_LEFT_CONTROL) == glfw.PRESS do dt *= 10.0;
        if glfw.GetKey(window, glfw.KEY_LEFT_SHIFT)   == glfw.PRESS do dt /= 10.0;
        
        // get current mouse position
        mx, my := glfw.GetCursorPos(window);
        if glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_1) == glfw.PRESS do rotate_camera(&cam, f32(mx - mx_prev), f32(my - my_prev));
        mx_prev, my_prev = mx, my;
        
        // update camera position:
        // W: forward, S: back, A: left, D: right, E: up, Q: down
        dx := glfw.GetKey(window, glfw.KEY_D) - glfw.GetKey(window, glfw.KEY_A);
        dy := glfw.GetKey(window, glfw.KEY_W) - glfw.GetKey(window, glfw.KEY_S);
        dz := glfw.GetKey(window, glfw.KEY_E) - glfw.GetKey(window, glfw.KEY_Q);
        move_camera(&cam, f32(dx)*dt, f32(dy)*dt, f32(dz)*dt);
        
        // Calculate camera and perspective matrices
        V := view(cam.r, cam.u, cam.f, cam.p);
        P := math.perspective(math.to_radians(45), f32(resx/resy), 0.1, 1000.0);
        MVP := math.mul(P, V);

        // Main drawing part
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        
        // Set uniforms
        gl.UseProgram(program);
        gl.Uniform1f(uniform_infos["time"].location, f32(glfw.GetTime()));
        gl.UniformMatrix4fv(uniform_infos["MVP"].location, 1, gl.FALSE, &MVP[0][0]);

        // Draw
        gl.BindVertexArray(vao);
        gl.DrawElementsInstanced(gl.TRIANGLES, len(cube_elements), gl.UNSIGNED_INT, nil, N*N*N);

        glfw.SwapBuffers(window);
    }
}
