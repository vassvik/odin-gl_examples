#version 450 core

in vec3 pos;
in vec3 normal;
in vec2 uv;
in float area;
in vec3 spos;

uniform float time;
uniform float near;
uniform float far;
uniform vec3 camera_pos;
uniform vec3 sphere_pos;
uniform vec2 resolution;
uniform mat4 MVP;

uniform float min_area;
uniform float max_area;
uniform int draw_mode;

out vec4 color;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

mat4 thresholdMatrix = mat4(
	1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
	13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
	4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
	16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
);

void main() {
	if (draw_mode == 0) {
		float a;
		if (abs(max_area - min_area) < 1.0e-6) {
			a = 0.0;
		} else {
			a = (area - min_area)/(max_area-min_area);	
		}
		color = vec4(a, a, a, 1.0);
		float Z = MVP[3].z/(gl_FragCoord.z * -2.0 + 1.0 - MVP[2].z);
		gl_FragDepth = ( 1.0/gl_FragCoord.w - near ) / (far - near);
		color = vec4(0.5 + 0.5*normal, 1.0);
	} else if (draw_mode == 1) {
		color = vec4(1.0, 0.0, 0.0, 1.0);
		gl_FragDepth = ( 1.0/gl_FragCoord.w - near ) / (far - near);
	} else {
		float l = length(uv);
		if (l > 1.0) discard;

		vec2 q = 0.5 + 0.5*uv;
		float a = 0.5 + 0.5*cos(time);
		/*
		a = 1.0;
		float w = (0.4/dFdx(uv.x));
		if (a < thresholdMatrix[int(w*q.y + cos(0*time))%4][int(w*q.x + cos(0*time))%4]) discard;
		*/
		vec3 p = vec3(uv, 0.0);
		p.z = sqrt(max(0.0, 1.0 - l*l));
		vec3 n = normalize(p);

        float w_half = 1.0/resolution.y;

        // switch on/off anti aliasing every second
        if (mod(time, 2.0) < 1.0) w_half = 0.0;

        // actual shading
        //float t = 1.0 - smoothstep(1.0 - w_half, 1.0 + w_half, l);
		float d = dot(vec3(0.0, 0.0, 1.0), n);
		color = vec4(0.5 + 0.5*n, 1.0);
		color = vec4(vec3(0.5, 0.5, 0.5)*d, 1.0);
		//color = vec4(d*(0.5 + 0.5*cos(3.0*spos)), 1.0);
		gl_FragDepth = ((length(spos - camera_pos) - p.z) - near)/(far - near);
	}



}