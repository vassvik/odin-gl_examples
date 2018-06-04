#version 330 core

in vec3 fragment_position;
flat in int instance;

uniform float time;

out vec4 color;

void main() {
	float R = 0.5 + 0.5*cos(2.0*fragment_position.x + 2.0*time);
	float G = 0.5 - 0.5*cos(3.0*fragment_position.y + 2.0*time);
	float B = 0.5 + 0.5*cos(5.0*fragment_position.z + 2.0*time);
    color = vec4(R, G, B, 1.0);

    if (instance == 1) color.xyz = 1.0 - color.xyz;
}