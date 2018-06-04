#version 330 core

layout(location = 0) in vec3 vertex_position;

uniform float time;

out vec3 fragment_position;
flat out int instance;

void main() {
	instance = gl_InstanceID;
    vec3 p = vertex_position;
    fragment_position = p;

    if (gl_InstanceID == 1) {
    	p.z = -0.5;
    	p.xy += 0.3;
    }

    gl_Position = vec4(p, 1.0);



}