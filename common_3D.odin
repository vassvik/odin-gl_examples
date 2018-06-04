/*
    Common routines used in a typical 3D render

    At the moment: a 1st person pivot camera
*/

import "core:math.odin"

Camera :: struct {
    p: math.Vec3, // camera position (aka. "eye")
    
    r: math.Vec3, // camera right vector (aka. "side")
    f: math.Vec3, // camera forward vector (aka. "dir")
    u: math.Vec3, // camera up vector (note: not the same as the global "up" vector, but perpendicular to r and f)

    theta, phi: f32, // spherical coordinate angles, used to calculate orientation vectors
}

rotate_camera :: proc(using cam: ^Camera, delta_x, delta_y: f32) {
    radiansPerPixel := f32(0.1 * math.π / 180.0);
    phi = phi - delta_x * radiansPerPixel;
    theta = clamp(theta + delta_y * radiansPerPixel, 1.0*math.π/180.0, 179.0*math.π/180.0);

    // calculate updated local camera coordinate system based on angles
    // Note: this assumes +Z is up and physicists spherical coordinates conventions (theta is up-down. phi is left-right)
    sinp, cosp := math.sin(phi),   math.cos(phi);
    sint, cost := math.sin(theta), math.cos(theta);

    f = math.Vec3{cosp*sint, sinp*sint, cost};
    r = math.Vec3{sinp, -cosp, 0.0};
    u = math.Vec3{-cosp*cost, -sinp*cost, sint};
}

move_camera :: proc(using cam: ^Camera, right_left, forward_backward, up_down : f32) {
    p += f*forward_backward;
    p += r*right_left;
    p += u*up_down;
} 

init_camera :: proc(using cam: ^Camera) {
    p = math.Vec3{-1.0, -1.0, 5.0};

    theta, phi = math.π/2.0, math.π/4.0;

    sinp, cosp := math.sin(phi),   math.cos(phi);
    sint, cost := math.sin(theta), math.cos(theta);

    f = math.Vec3{cosp*sint, sinp*sint, cost};
    r = math.Vec3{sinp, -cosp, 0.0};
    u = math.Vec3{-cosp*cost, -sinp*cost, sint};
}

// since i'm too stubborn to use math.look_at (since I already have the vectors for my camera)
view :: proc(r, u, f, p: math.Vec3) -> math.Mat4 { 
    return math.Mat4 {
        {+r[0], +u[0], -f[0], 0.0},
        {+r[1], +u[1], -f[1], 0.0},
        {+r[2], +u[2], -f[2], 0.0},
        {-math.dot(r,p), -math.dot(u,p), math.dot(f,p), 1.0},
    };
}
