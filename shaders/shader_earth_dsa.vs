#version 450 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;

out vec3 fragment_position;
out vec3 fragment_normal;

uniform vec3 offset;
uniform float time;
uniform vec2 resolution;

mat4 rotationMatrix(vec3 axis, float angle)
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

void main() {
    fragment_position = vertexPosition;
    fragment_normal = vertexNormal;

    gl_Position = rotationMatrix(offset, time*(0.5 + cos(length(offset))))*rotationMatrix(vec3(1.0, 0.0, 0.0), 3.1415)*vec4(0.45*vertexPosition, 1.0);
    gl_Position.xyz += offset;
    gl_Position.x /= resolution.x/resolution.y;
}