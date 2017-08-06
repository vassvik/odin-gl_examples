#version 330 core

in vec3 fragment_position;

uniform int mode;
uniform sampler2D renderedTexture;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 blah;

void main() {
	if (mode == 0) {
		float R = 0.5 + 0.5*cos(2.0*gl_PrimitiveID);
		float G = 0.5 - 0.5*cos(3.0*gl_PrimitiveID);
		float B = 0.5 + 0.5*cos(5.0*gl_PrimitiveID);
	    color = vec4(R, G, B, 1.0);
	} else {
		ivec2 texture_size = textureSize(renderedTexture, 0);

		vec4 middle        = texture(renderedTexture, fragment_position.xy);
		
		float thickness = 1.0;

		float top_left     = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0, +1.0)/texture_size) == middle ? 1 : 0;
		float top          = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, +1.0)/texture_size) == middle ? 1 : 0;
		float top_right    = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0, +1.0)/texture_size) == middle ? 1 : 0;
		float left         = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0,  0.0)/texture_size) == middle ? 1 : 0;
		float right        = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0,  0.0)/texture_size) == middle ? 1 : 0;
		float bottom_left  = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0, -1.0)/texture_size) == middle ? 1 : 0;
		float bottom       = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, -1.0)/texture_size) == middle ? 1 : 0;
		float bottom_right = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0, -1.0)/texture_size) == middle ? 1 : 0;

		float sx = 2.0*(right - left) + (bottom_right - bottom_left) + (top_right - top_left);
		float sy = 2.0*(top - bottom) + (top_right - bottom_right)   + (top_left - bottom_left);

		float s = clamp(sqrt(sx*sx + sy*sy)/4.0, 0.0, 1.0);

		color = texture(renderedTexture, fragment_position.xy);
		color = vec4(0.5 + 0.5*sx, 0.5 + 0.5*sy, 0.0, 1.0);

		//color = vec4(0.0, 0.0, 0.0, 1.0)*s + color*(1.0 - s);

		//color = vec4(s, s, s, 1.0);
	}
}