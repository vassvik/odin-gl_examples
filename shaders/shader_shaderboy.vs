#version 330 core

layout(location = 0) in vec2 vertex_position;

void main() {
    gl_Position = vec4(vertex_position, 0.0, 1.0);
}
