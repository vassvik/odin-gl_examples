#version 330 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;

out vec3 fragment_position;
out vec3 fragment_normal;

uniform mat4 M;
uniform float time;
uniform vec2 resolution;

void main() {
    gl_Position = M*vec4(0.33*vertexPosition, 1.0);
    gl_Position.x /= resolution.x/resolution.y; // aspect ratio correction

    fragment_position = vertexPosition;
    fragment_normal = vertexNormal;
}
