#version 330 core

out vec3 fragment_position;

out vec2 uv;

void main() {
	int x = (gl_VertexID / 2) + (gl_InstanceID%3);
	int y = (gl_VertexID % 2) + (gl_InstanceID/3);
	vec2 p = vec2(x, y);

	gl_Position = vec4((2.0*p - 1.0), 0.0, 1.0);

    uv = vec2(x, y);
}