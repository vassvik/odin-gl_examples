#version 450 core

in vec2 fragment_position;
in vec2 fragment_position2;
in float radius;
flat in int instance_id;

uniform float time;
uniform int shade_mode;
uniform vec2 resolution;
uniform vec4 cam_box;
uniform int chosen_link;

out vec4 color;


struct Point {
    float x, y;
    float r;
};

struct Node {
    int links[3];
    float x, y;
    int type;
};

struct Link {
    int front; // Node
    int back;  // Node
    int left;  // Disk
    int right; // Disk
    float x, y; // Center of link along arc
    double c; // Cosine of half angle of arc, needs the precision
    float Ux, Uy; // Position of origin of arc
    float Cx, Cy; // Position of origin of arc
    float Cr; // Radius of curvature of arc
    int type;
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

#define SHADE_LINK 0
#define SHADE_CYLINDERS 1
#define SHADE_LINK_ARC 2
#define SHADE_LINK_CENTER 3
#define SHADE_NODE_CENTER 4
#define SHADE_MOUSE_DISK 5

void main() {
	vec2 p = fragment_position;

	if (shade_mode == SHADE_LINK) {
		color = vec4(0.6, 0.8, 1.0, 1.0);
		if (instance_id == chosen_link) {
			color = vec4(1.0, 0.0, 0.0, 1.0);
		} else if (links[instance_id].type == 1) {
			color = vec4(0.2, 0.4, 0.8, 1.0);
		} else if (links[instance_id].type == 2) {
			color = vec4(0.8, 0.4, 0.6, 1.0);
		}
	} else if (shade_mode == SHADE_CYLINDERS) {

		// disk
		float r = length(p) - 1.0;
		float w = 1.5*fwidth(r);
		float s = smoothstep(w/2.0, -w/2.0, r);

		// circle
		//float r1 = abs(length(p) - 1.0) - 1.5*fwidth(r);
		float r1 = abs(length(p) - 1.0) - 0.5/radius;
		float w1 = 1.5*fwidth(r1);
		float s1 = smoothstep(w1/2.0, -w1/2.0, r1);

		// mix disk and circle colors
		vec3 c1 = vec3(0.25, 0.5, 0.25);
		vec3 c2 = vec3(0.0, 0.0, 0.0);
		vec3 c3 = c1*(1.0 - s1) + c2*s1;

		// final color, blend with old image
		color = vec4(c3, s);
	} else if (shade_mode == SHADE_NODE_CENTER) {
		p *= radius;
		p /= (cam_box.w - cam_box.y)/resolution.y;

		float w = 2.0;
		float r = radius*resolution.y/(cam_box.w - cam_box.y);
		float s = smoothstep(r + w/2.0, r - w/2.0, length(p));

		color = vec4(1.0, 1.0, 0.0, s);
		if (shade_mode == 10 && nodes[instance_id].type == 1)
			color = vec4(0.8, 0.7, 1.0, s);
		if (shade_mode == 10 && nodes[instance_id].type == 2)
			color = vec4(0.0, 1.0, 1.0, s);
	} else if (shade_mode == SHADE_LINK_CENTER) {

		p *= radius;
		p /= (cam_box.w - cam_box.y)/resolution.y;

		float w = 2.0;
		float r = radius*resolution.y/(cam_box.w - cam_box.y);
		float s = smoothstep(r + w/2.0, r - w/2.0, length(p));
		

		color = vec4(1.0, 0.0, 1.0, s);

	} else if (shade_mode == SHADE_LINK_ARC) {
		Link l = links[instance_id];
		if (l.Cr > 6.6e4) {
			vec2 p1 = vec2(nodes[l.front].x, nodes[l.front].y);
            vec2 p2 = vec2(nodes[l.back].x, nodes[l.back].y);
            vec2 pm = 0.5*(p1+p2);
            float L = length(p1-p2);

            float d = (abs(abs((p2.y - p1.y)*p.x - (p2.x - p1.x)*p.y + p2.x*p1.y - p2.y*p1.x) / length(p2-p1)) - 0.3);
			float w = 1.5*fwidth(float(d));
			float s = smoothstep(w/2.0, -w/2.0, d);

			if (length(p - pm) > L/2.0)
				s = 0.0;

			color = vec4(0.5, 0.5, 0.5, s);
		} else {

			// vector from the circle origin to the middle of the arc
			dvec2 up = dvec2(l.Ux, l.Uy);

			// cos(angle/2.0), where `angle` is the full arc length
			double c = (l.c);

			// circle
			float r1 = abs(length(p) - 1.0) - 0.3/radius;
			float w1 = 1.5*fwidth(r1);
			float s1 = smoothstep(w1/2.0, -w1/2.0, r1);

			
			// smoothing along the arc
			// @BUG, does not seem to work for inlet and outlet links...?
			//float r2 = float(dot(up, normalize(dvec2(p))) - c);
			//float w2 = 1.5*fwidth(r2); // proportional to how much `d2` changes between pixels
			//float s2 = smoothstep(w2/2.0, -w2/2.0, r2); 
			//s1 = s1*(1.0 - s2);
			
			
			// Temp hack until arc angle smoothing can be used again
			vec2 p1 = vec2(nodes[l.front].x, nodes[l.front].y);
            vec2 p2 = vec2(nodes[l.back].x, nodes[l.back].y);
            vec2 pm = 0.5*(p1+p2);
            float L = length(p1-p2);

			if (length(fragment_position2 - pm) > L/2.0) s1 = 0.0;

			// final color, blend with old image
			color = vec4(0.0, 0.0, 0.0, s1);
		}
		//color = vec4(0.0, 0.0, 0.0, 1.0);
		//color = vec4(0.0, 0.0, 0.0, 1.0);
	} else if (shade_mode == SHADE_MOUSE_DISK) {
		p *= radius;
		p /= (cam_box.w - cam_box.y)/resolution.y;

		float w = 2.0;
		float r = radius*resolution.y/(cam_box.w - cam_box.y);
		float s = smoothstep(r + w/2.0, r - w/2.0, length(p));
		
		color = vec4(0.25, 0.25, 1.0, s*0.8);

	}
	
}