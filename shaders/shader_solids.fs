#version 450 core

in vec3 pos;
in vec3 normal;
uniform float time;
uniform vec3 camera_pos;
uniform vec3 sphere_pos;
out vec4 color;

void main() {
    color = vec4(0.5 + 0.5*pos, 1.0);
	color = vec4(0.5 + 0.5*normal, 1.0);
	float s = smoothstep(0.0, 0.05, dot(normalize(camera_pos-(sphere_pos+pos)), pos)-0.1);
	color = vec4(0.0, 0.0, 0.0, 1.0)*(1.0 - s) + color*s;

}