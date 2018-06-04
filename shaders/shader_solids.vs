#version 450 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexNormal;
layout(location = 2) in float triangleArea;

uniform float time;
uniform mat4 MVP;
uniform int vertex_mode;
uniform vec3 sphere_pos;
uniform vec3 r;
uniform vec3 u;

out vec3 spos;

out vec3 pos;
out vec3 normal;
out float area;
out vec2 uv;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
	if (vertex_mode == 0) {
	    gl_Position = MVP*vec4(vertexPosition, 1.0);
	    pos = vertexPosition;
	    normal = vertexNormal;
	    area = triangleArea;
	} else {
		float x = gl_VertexID>>1;
		float y = gl_VertexID&1;
		float r1 = rand(vec2(1.0*gl_InstanceID, 1.0));
		float r2 = rand(vec2(1.0*gl_InstanceID, 2.0));
		float r3 = rand(vec2(1.0*gl_InstanceID, 3.0));
		spos = vec3(100.0, 100.0, 100.0)*vec3(r1, r2, r3)+vec3(0.0, 0.0, 2.0);
		vec3 p = spos + 0.25*r*(2.0*x - 1.0) + 0.25*u*(2.0*y - 1.0);
		gl_Position = MVP*vec4(p, 1.0);
	    pos = p;
		uv = vec2(2.0*x-1.0, 2.0*y-1.0);
	}
}