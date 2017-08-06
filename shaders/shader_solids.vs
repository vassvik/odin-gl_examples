#version 450 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;

uniform float time;
uniform mat4 MVP;

out vec3 pos;
out vec3 normal;

void main() {
    gl_Position = MVP*vec4(vertexPosition, 1.0);
    pos = vertexPosition;
    normal = vertexNormal;
}