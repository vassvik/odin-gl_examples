#version 330 core

in vec3 fragment_position;
flat in int instance_ID;

uniform int mode;
uniform sampler2D tex;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 blah;

float t = 1.0;


void main() {
	vec2 p = fragment_position.xy;
	if (mode == 0) {
		float R = 0.5 + 0.5*cos(2.0*instance_ID + 3.7*gl_PrimitiveID);
		float G = 0.5 - 0.5*cos(3.0*instance_ID + 2.0*3.7*gl_PrimitiveID);
		float B = 0.5 + 0.5*cos(5.0*instance_ID + 3.0*3.7*gl_PrimitiveID);
	    color = vec4(R, G, B, 1.0);
	} else if (mode == 1) {
		ivec2 res = textureSize(tex, 0);
		ivec2 p = ivec2(fragment_position.xy*res/* + 0.5*/);

		vec4 middle   = texelFetch(tex, ivec2(gl_FragCoord.xy) + ivec2(0, 0), 0);
		int top       = texelFetch(tex, ivec2(gl_FragCoord.xy) + ivec2(0, 1), 0) == middle ? 1 : 0;
		int right     = texelFetch(tex, ivec2(gl_FragCoord.xy) + ivec2(1, 0), 0) == middle ? 1 : 0;
		int top_right = texelFetch(tex, ivec2(gl_FragCoord.xy) + ivec2(1, 1), 0) == middle ? 1 : 0;

		int s = right*1 + top_right*2 + top*4;
		s = !(s == 3 || s == 5 || s == 7) ? 0 : 1;

		color = vec4(middle.xyz*s + vec3(0.0)*(1.0 - s), 1.0);
		
	} else {
		ivec2 res = textureSize(tex, 0);

		float t = 1.0;

		float middle        = texture(tex, p.xy).x;
		float top_left      = texture(tex, p.xy + t*vec2(-1.0, +1.0)/res).x;
		float top           = texture(tex, p.xy + t*vec2( 0.0, +1.0)/res).x;
		float top_right     = texture(tex, p.xy + t*vec2(+1.0, +1.0)/res).x;
		float left          = texture(tex, p.xy + t*vec2(-1.0,  0.0)/res).x;
		float right         = texture(tex, p.xy + t*vec2(+1.0,  0.0)/res).x;
		float bottom_left   = texture(tex, p.xy + t*vec2(-1.0, -1.0)/res).x;
		float bottom        = texture(tex, p.xy + t*vec2( 0.0, -1.0)/res).x;
		float bottom_right  = texture(tex, p.xy + t*vec2(+1.0, -1.0)/res).x;
		float up_up         = texture(tex, p.xy + t*vec2( 0.0, -2.0)/res).x;
		float left_left     = texture(tex, p.xy + t*vec2(-2.0,  0.0)/res).x;
		float right_right   = texture(tex, p.xy + t*vec2(+2.0,  0.0)/res).x;
		float bottom_bottom = texture(tex, p.xy + t*vec2( 0.0, -2.0)/res).x;
		//color = vec4(1.0 - middle.xyz, 1.0);
		
		color = vec4(vec3(4.0*middle + left + right + top + bottom)/8.0, 1.0);
	}
}