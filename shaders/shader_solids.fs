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
		if (length(uv) > 1.0) discard;

		vec3 p = vec3(uv, 0.0);
		p.z = sqrt(max(0.0, 1.0 - dot(uv, uv)));
		vec3 n = normalize(p);


        float w_half = 0.0/resolution.y;

        // switch on/off anti aliasing every second
        if (mod(time, 2.0) < 1.0)
            w_half = 0.0;

        // actual shading
        float t = 1.0 - smoothstep(1.0 - w_half, 1.0 + w_half, length(p.xy));
		color = vec4(0.5 + 0.5*n, 1.0);
		gl_FragDepth = ((length(spos - camera_pos) - p.z) - near)/(far - near);

		//if (length(p.xy) > 1.0) discard;

	    
		//float s = smoothstep(0.0, 0.05, dot(normalize(camera_pos-(sphere_pos+pos)), pos)-0.1);
		//color = vec4(0.0, 0.0, 0.0, 1.0)*(1.0 - s) + color*s;
	}

	//color = vec4(vec3(cos(gl_FragCoord.w)*0.5 + 0.5), 1.0);


}