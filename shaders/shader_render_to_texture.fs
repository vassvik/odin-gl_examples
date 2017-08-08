#version 330 core

in vec3 fragment_position;
flat in int instance_ID;

uniform int mode;
uniform sampler2D renderedTexture;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 blah;

void main() {
	if (mode == 0) {
		float R = 0.5 + 0.5*cos(2.0*instance_ID + 3.7*gl_PrimitiveID);
		float G = 0.5 - 0.5*cos(3.0*instance_ID + 3.7*gl_PrimitiveID);
		float B = 0.5 + 0.5*cos(5.0*instance_ID + 3.7*gl_PrimitiveID);
	    color = vec4(R, G, B, 1.0);
	} else if (mode == 1) {
		ivec2 texture_size = textureSize(renderedTexture, 0);

		float thickness = 1.0;

		vec4 middle        = texture(renderedTexture, fragment_position.xy);

		float top_left      = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0, +1.0)/texture_size) == middle ? 0 : 1;
		float top           = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, +1.0)/texture_size) == middle ? 0 : 1;
		float top_right     = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0, +1.0)/texture_size) == middle ? 0 : 1;
		float left          = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0,  0.0)/texture_size) == middle ? 0 : 1;
		float right         = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0,  0.0)/texture_size) == middle ? 0 : 1;
		float bottom_left   = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0, -1.0)/texture_size) == middle ? 0 : 1;
		float bottom        = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, -1.0)/texture_size) == middle ? 0 : 1;
		float bottom_right  = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0, -1.0)/texture_size) == middle ? 0 : 1;
		float up_up         = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, -2.0)/texture_size) == middle ? 0 : 1;
		float left_left     = texture(renderedTexture, fragment_position.xy + thickness*vec2(-2.0,  0.0)/texture_size) == middle ? 0 : 1;
		float right_right   = texture(renderedTexture, fragment_position.xy + thickness*vec2(+2.0,  0.0)/texture_size) == middle ? 0 : 1;
		float bottom_bottom = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, -2.0)/texture_size) == middle ? 0 : 1;

		float sx = 2.0*(right - left) + (bottom_right - bottom_left) + (top_right - top_left);
		float sy = 2.0*(top - bottom) + (top_right - bottom_right)   + (top_left - bottom_left);

		float s1 = clamp(sqrt(sx*sx + sy*sy)/5.0, 0.0, 1.0);
		float s2 = clamp((2.0*(left+top+right+bottom)+2.0*(top_left+top_right+bottom_left+bottom_right) + 4.0*(up_up+left_left+bottom_bottom+right_right))/12.0, 0.0, 1.0);
		
		float s = smoothstep(0.0, 1.0, s2);

		s = left+top+right+bottom; 
		//s = left+top+right+bottom+top_left+top_right+bottom_left+bottom_right;
		s = s > 0.0 ? 1.0 : 0.0;

		color = vec4(0.0, 0.0, 0.0, 1.0)*s + middle*(1.0 - s);
		//color = middle;
		//color = vec4(0.5 + 0.5*sx, 0.5 + 0.5*sy, 0.0, 1.0);
		color = vec4(s, s, s, 1.0);
	} else {
		ivec2 texture_size = textureSize(renderedTexture, 0);

		float thickness = 1.0;

		float middle        = texture(renderedTexture, fragment_position.xy).x;
		float top_left      = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0, +1.0)/texture_size).x;
		float top           = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, +1.0)/texture_size).x;
		float top_right     = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0, +1.0)/texture_size).x;
		float left          = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0,  0.0)/texture_size).x;
		float right         = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0,  0.0)/texture_size).x;
		float bottom_left   = texture(renderedTexture, fragment_position.xy + thickness*vec2(-1.0, -1.0)/texture_size).x;
		float bottom        = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, -1.0)/texture_size).x;
		float bottom_right  = texture(renderedTexture, fragment_position.xy + thickness*vec2(+1.0, -1.0)/texture_size).x;
		float up_up         = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, -2.0)/texture_size).x;
		float left_left     = texture(renderedTexture, fragment_position.xy + thickness*vec2(-2.0,  0.0)/texture_size).x;
		float right_right   = texture(renderedTexture, fragment_position.xy + thickness*vec2(+2.0,  0.0)/texture_size).x;
		float bottom_bottom = texture(renderedTexture, fragment_position.xy + thickness*vec2( 0.0, -2.0)/texture_size).x;
		//color = vec4(1.0 - middle.xyz, 1.0);
		color = vec4(vec3(4.0*middle + left + right + top + bottom)/8.0, 1.0);
	}
}