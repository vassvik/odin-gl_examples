#version 330 core

in vec2 uv;

uniform float time;
uniform int num;
uniform sampler2D renderedTexture;

layout(location = 0) out vec4 color;

void main() {
	float s = texture(renderedTexture, uv).r*0.001;
	float R = 0.5 + 0.5*cos(2.0*s+2.3);
	float G = 0.5 + 0.5*sin(2.0*s-1.2);
	float B = 0.5 + 0.5*tan(2.0*s+4.1);
	color = vec4(R, G, B, 1.0);
	
	if (s == 0.0 || (s*1000.0) > num*fract(1000.0/num*time)) {
		color = vec4(0.0, 0.0, 0.0, 1.0);
	}
}