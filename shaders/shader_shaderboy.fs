#version 330 core

uniform float iGlobalTime;
uniform vec3 iResolution;

out vec4 color;

void mainImage(out vec4 fragColor, in vec2 fragCoord);
float distanceBezier(vec2 p, vec2 P0, vec2 P1, vec2 P2, vec2 P3);

void main() {
	mainImage(color, gl_FragCoord.xy);
}

// copy of https://www.shadertoy.com/view/4sXyDr, 
// stripped of comments and defines for brevity
float distanceBezier(vec2 p, vec2 P0, vec2 P1, vec2 P2, vec2 P3) {
	vec2 A = -P0 + 3.0*P1 - 3.0*P2 + P3;
	vec2 B = 3.0*(P0 - 2.0*P1 + P2);
	vec2 C = 3.0*(P1 - P0);
	vec2 D = P0;

	float a5 = 6.0*dot(A,A);
	float a4 = 10.0*dot(A,B);
	float a3 = 8.0*dot(A,C) + 4.0*dot(B,B);
	float a2 = 6.0*dot(A,D-p) + 6.0*dot(B,C);
	float a1 = 4.0*dot(B,D-p) + 2.0*dot(C,C);
	float a0 = 2.0*dot(C,D-p);
	
	float d0 = length(p-P0);
	float d1 = length(p-P1);
	float d2 = length(p-P2);
	float d3 = length(p-P3);
	float d = min(d0, min(d1, min(d2,d3)));
	
	float t;
	if (abs(d3 - d) < 1.0e-5)
		t = 1.0;
	else if (abs(d0 - d) < 1.0e-5)
		t = 0.0;
	else
		t = 0.5;
		
	for (int i = 0; i < 10; i++) {
		float t2 = t*t;
		float t3 = t2*t;
		float t4 = t3*t;
		float t5 = t4*t;
		
		float f = a5*t5 + a4*t4 + a3*t3 + a2*t2 + a1*t + a0;
		float df = 5.0*a5*t4 + 4.0*a4*t3 + 3.0*a3*t2 + 2.0*a2*t + a1;
		
		t = t - f/df;
	}
	
	t = clamp(t, 0.0, 1.0);
	vec2 P = A*t*t*t + B*t*t + C*t + D;
		
	if (d < 0.1) { 
		return -d*10.0;
	} else {
		return min(length(p-P), min(d0, d3)); 
	}
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	float scale = 5.0;
	vec2 p = scale*(2.0*fragCoord.xy - iResolution.xy)/iResolution.y;
	
	float a = 2.0*sin(0.5*0.5*0.5*2.0*3.1415925*iGlobalTime);
	vec2 P0 = vec2(-1.00 - 1.00*cos(1.0*a), 1.0*sin(a));
	vec2 P1 = vec2(-0.75 + 0.25*cos(0.5*a), 0.0*sin(a));
	vec2 P2 = vec2( 0.75 - 0.25*cos(0.5*a), 0.0*sin(a));
	vec2 P3 = vec2( 1.00 + 1.00*cos(1.0*a), 1.0*sin(a));
	
	float r = distanceBezier(p, P0, P1, P2, P3);    
	
	if (r < 0.0) {
		fragColor = vec4(-r, 0.0, -r, 1.0);
	} else {
		r = sin(10.0/scale*2.0*3.1415925*r);
		fragColor = vec4(r, r*r, -r, 1.0);
	}
}