#version 330 core

out vec4 color;

in vec3 normal;

void main() {
	color = vec4(0.5 + 0.5*normal, 1.0);
}