#version 450 core

out vec3 fragment_position;
out vec3 fragment_normal;

uniform mat4 M;
uniform float time;
uniform vec2 resolution;

struct Vertex {
    vec3 position;
    vec3 normal;
};

layout (std430, binding = 0) buffer vertex_buffer {
    Vertex vertices[];
};

void main() {
    Vertex vertex = vertices[gl_VertexID];

    gl_Position = M*vec4(0.33*vertex.position, 1.0);
    gl_Position.x /= resolution.x/resolution.y;  // aspect ratio correction

    fragment_position = vertex.position;
    fragment_normal = vertex.normal;
}
