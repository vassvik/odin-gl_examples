#version 330 core

void main() {
	int x = gl_VertexID / 2;
	int y = gl_VertexID % 2;
	vec2 p = 2.0*vec2(gl_VertexID/2, gl_VertexID%2) - 1.0;
    gl_Position = vec4(2.0*p - 1.0, 0.0, 1.0);
}
