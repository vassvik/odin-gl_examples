#version 330 core

out vec3 normal;

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in vec3 instancedPosition;

uniform float time;
uniform mat4 MVP;

void main() {
    gl_Position = MVP*vec4(vec3(1.0 + 0.3*cos(gl_InstanceID + 3.0*time))*vertexPosition + instancedPosition, 1.0);

    normal = vertexNormal;
}