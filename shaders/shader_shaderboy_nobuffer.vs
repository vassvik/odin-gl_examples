#version 330 core

void main() {
	int x = gl_VertexID / 2;
	int y = gl_VertexID % 2;
    gl_Position = vec4(2.0*x - 1.0, 2.0*y - 1.0, 0.0, 1.0);
}
