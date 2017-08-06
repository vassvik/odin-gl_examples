#version 450 core

in vec3 pos;
in vec3 normal;
uniform float time;
out vec4 color;

void main() {
    color = vec4(0.5 + 0.5*pos, 1.0);
    color = vec4(0.5 + 0.5*normal, 1.0);
}