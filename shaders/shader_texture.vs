#version 330 core

uniform float time;

out vec2 fragment_position;
out vec2 fragment_uv;

void main() {
	// unit square
	vec2 p = vec2(gl_VertexID >> 1, gl_VertexID & 1);
    fragment_position = p;

    // calculate UV based on instance
    fragment_uv = 0.5*(p + vec2(gl_InstanceID >> 1, gl_InstanceID & 1));

    // half the size
    p *= 0.5;

    // move into position depending on instance ID, like so:
    //
    //  1   3
    //
    //  0   2
    //
    p += vec2(-0.75) + vec2(1.0)*vec2(gl_InstanceID >> 1, gl_InstanceID & 1);

    // slight offset based on time
    p += 0.1*vec2(cos((1.0 + gl_InstanceID)*time), sin((2.0 - gl_InstanceID)*time));

    gl_Position = vec4(p, 0.0, 1.0);
}