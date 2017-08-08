#version 330 core

out vec3 fragment_position;

uniform int mode;

flat out int instance_ID;

void main() {
	int x = (gl_VertexID / 2) + (gl_InstanceID%3);
	int y = (gl_VertexID % 2) + (gl_InstanceID/3);
	vec2 p = vec2(x, y);

	if (mode == 0) {
		p.x = p.x + 0.2*cos((3.0*x-0.7)*y - 0.4);
		p.y = p.y + 0.2*cos((3.0*x+0.3)/(y+0.3) + 0.3);
    	gl_Position = vec4(0.25*(2.0*p - 1.0)-0.5, 0.0, 1.0);
	} else {
		gl_Position = vec4((2.0*p - 1.0), 0.0, 1.0);
	}
    fragment_position = vec3(p, 0.0);
    instance_ID = gl_InstanceID;
}