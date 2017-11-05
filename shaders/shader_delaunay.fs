#version 450 core

in vec2 position_normalized;
in vec2 position_world;
flat in int instance_id;

uniform int shade_mode;
uniform int chosen_link;
uniform float time;
uniform vec2 resolution;
uniform vec4 cam_box;
uniform int should_clear;
uniform bool should_highlight;
uniform vec2 mouse_pos;

out vec4 color;


struct Point {
    vec2 P;
    float r;
};

struct Node {
    int links[3]; // neighbouring links, 1 (inlet or outlet) or 3 (inside)
    int type;     // inside (0), inlet (1), outlet (2)
    vec2 P;       // "center" of node
};

struct Link {
    int front;  // Node
    int back;   // Node
    int left;   // Disk/Point
    int right;  // Disk/Point
    vec2 M;     // Point on center of arc
    vec2 O;     // Position of origin of arc 
    vec2 U;     // normalize(M -  O)
    double c;   // Cosine of half angle of arc sector, needs the precision
    float R;    // 'Radius of curvature' of arc
    int type;   // inside (0), inlet (1), outlet (2)
};

struct Link_Dynamic {
	int filled;
	int num_bubbles;
	float bubbles_start[16];
	float bubbles_stop[16];
};

layout (std430, binding = 0) buffer point_buffer {
    Point points[];
};

layout (std430, binding = 1) buffer node_buffer {
    Node nodes[];
};

layout (std430, binding = 2) buffer link_buffer {
    Link links[];
};

layout (std430, binding = 3) buffer link_dynamic {
    Link_Dynamic links_dynamic[];
};

#define SHADE_NONE        -1
#define SHADE_LINK         0
#define SHADE_CYLINDERS    1
#define SHADE_LINK_ARC     2
#define SHADE_LINK_CENTER  3
#define SHADE_NODE_SMALL   4
#define SHADE_MOUSE_DISK   5
#define SHADE_NODE_FIT     6
#define SHADE_LINK_FIT     7

void main() {

	vec2 position_millimeter = position_world*(54.0/1000);
	vec2 position_mid = (cam_box.xy + cam_box.zw/2.0)*(54.0/1000);
	position_mid.y += 1.0;
	if (length(position_millimeter - position_mid) > 56.5) discard;

	vec2 p = position_normalized;
	if (shade_mode == SHADE_NONE) {
		discard;
	} else if (shade_mode == SHADE_LINK) {
		color = vec4(0.6, 0.8, 1.0, 1.0);
		color = vec4(1.0, 1.0, 1.0, 1.0);
		if      (instance_id == chosen_link && should_highlight)   color = vec4(1.0, 0.3, 0.3, 1.0); 
		else if (links[instance_id].type == 2) color = vec4(0.2, 0.4, 0.8, 1.0);
		else if (links[instance_id].type == 1) color = vec4(0.8, 0.4, 0.6, 1.0);

		color = vec4(1.0, 1.0, 1.0, 1.0);
		int order = links_dynamic[instance_id].filled;
		if (order > 0) {
		//if (order == -1) {
			//|color = vec4(0.5 + 0.5*cos(0.0003*2.0*order), 0.5 - 0.5*cos(0.0003*3.0*order), 0.5 + 0.5*cos(0.0003*5.0*order), 1.0);
			color = vec4(0.0, 0.0, 0.0, 1.0);
		}

		vec2 p0 = position_world;
		vec2 p1 = nodes[links[instance_id].back].P;
		vec2 p2 = nodes[links[instance_id].front].P;

		float c = dot(p2 - p1, p0 - p1)/length(p2 - p1)/length(p0 - p1);
		
		float x  = c*length(p0-p1);
		x = length(p0-p1)/length(p2-p1);
		x = dot(normalize(p2-p1), p0-p1)/length(p2-p1);


		int found = -1;
		for (int i = 0; i < links_dynamic[instance_id].num_bubbles; i++) {
			if (x >= links_dynamic[instance_id].bubbles_start[i] && x <= links_dynamic[instance_id].bubbles_stop[i]) {
				found = i;
				break;
			}
		}

		if (found != -1) {
			color = vec4(252/255.0, 252/255.0, 252/255.0, 1.0);
		} else {
			color = vec4(0.0, 0.0, 0.0, 1.0);
		}
		//color = vec4(vec3(x), 1.0);

	} else if (shade_mode == SHADE_CYLINDERS) {
		// disk
		float r = length(p) - 1.0;
		float w = 1.5*fwidth(r)*0.0;
		float s = smoothstep(w/2.0, -w/2.0, r);

		// circle
		float r1 = abs(length(p) - 1.0) - 0.5/points[instance_id].r;
		float w1 = 1.5*fwidth(r1);
		float s1 = smoothstep(w1/2.0, -w1/2.0, r1);

		// mix disk and circle colors
		vec3 c1 = vec3(0.25, 0.5, 0.25);
		vec3 c2 = vec3(0.5, 0.5, 0.5);
		vec3 c3 = c1*(1.0 - s1) + c2*s1;
		//c3 = vec3(1.0, 1.0, 1.0);
		c3 = vec3(58/255.0*0.5,86/255.0*0.5,94/255.0*0.5);

		// final color, blend with old image
		color = vec4(c3, s);
	} else if (shade_mode == SHADE_NODE_SMALL || shade_mode == SHADE_LINK_CENTER || shade_mode == SHADE_MOUSE_DISK || shade_mode == SHADE_NODE_FIT || shade_mode == SHADE_LINK_FIT) {
		// disk
		float r = length(p) - 1.0;
		float w = 1.5*fwidth(r);
		float s = smoothstep(w/2.0, -w/2.0, r);

		// final color, blend with old image
		if (shade_mode == SHADE_NODE_SMALL)
			color = vec4(vec3(1.0, 1.0, 0.0), s);
		else if (shade_mode == SHADE_LINK_CENTER)
			color = vec4(vec3(1.0, 0.0, 1.0), s);
		else if (shade_mode == SHADE_MOUSE_DISK)
			color = vec4(0.25, 0.25, 1.0, should_clear == 0 ? s : s*0.5);
		else if (shade_mode == SHADE_NODE_FIT)
			color = vec4(1.0, 1.0, 0.0, s*0.5);
		else if (shade_mode == SHADE_LINK_FIT)
			color = vec4(1.0, 0.0, 1.0, s*0.5);
	} else if (shade_mode == SHADE_LINK_ARC) {
		Link l = links[instance_id];
		if (l.R > 6.6e4) {
			vec2 p1 = nodes[l.front].P;
            vec2 p2 = nodes[l.back].P;
            vec2 pm = 0.5*(p1+p2);
            float L = length(p1-p2);

            float d = (abs(abs((p2.y - p1.y)*p.x - (p2.x - p1.x)*p.y + p2.x*p1.y - p2.y*p1.x) / length(p2-p1)) - 0.3);
			float w = 1.5*fwidth(float(d));
			float s = smoothstep(w/2.0, -w/2.0, d);

			if (length(p - pm) > L/2.0)
				s = 0.0;

			color = vec4(0.75, 0.75, 0.75, s);
		} else {

			// vector from the circle origin to the middle of the arc
			vec2 up = vec2(l.U);		

			// cos(angle/2.0), where `angle` is the full arc length
			double c = (l.c);

			// circle
			float r1 = abs(length(p) - 1.0) - 0.3/links[instance_id].R;
			float w1 = 1.5*fwidth(r1);
			float s1 = smoothstep(w1/2.0, -w1/2.0, r1);
			
			// smoothing along the arc
			// @BUG, does not seem to work for inlet and outlet links...?
			//float r2 = float(dot(up, normalize(dvec2(p))) - c);
			//float w2 = 1.5*fwidth(r2); // proportional to how much `d2` changes between pixels
			//float s2 = smoothstep(w2/2.0, -w2/2.0, r2); 
			//s1 = s1*(1.0 - s2);
			
			// Temp hack until arc angle smoothing can be used again
			vec2 p1 = nodes[l.front].P;
            vec2 p2 = nodes[l.back].P;
            vec2 pm = 0.5*(p1+p2);
            float L = length(p1-p2);

			if (length(position_world - pm) > L/2.0) s1 = 0.0;

			// final color, blend with old image
			color = vec4(0.5, 0.5, 0.5, s1);
		}
	} 	
}