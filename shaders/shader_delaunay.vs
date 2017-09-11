#version 450 core


out vec2 fragment_position;
out vec2 fragment_position2;
out float radius;
flat out int instance_id;


uniform float time;
uniform int vertex_mode;
uniform vec2 resolution;
uniform vec4 cam_box;
uniform vec2 mouse_pos;
uniform float mouse_radius;


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


const vec2 square[4] = {
    vec2(-1.0, -1.0), 
    vec2( 1.0, -1.0), 
    vec2(-1.0,  1.0), 
    vec2( 1.0,  1.0)
};

const vec2 hexagon[6] = {
    vec2( 0.0,  1.15470053838), 
    vec2(-1.0,  0.57735026919), 
    vec2( 1.0,  0.57735026919), 
    vec2(-1.0, -0.57735026919), 
    vec2( 1.0, -0.57735026919), 
    vec2( 0.0, -1.15470053838)
};

const vec2 octagon[8] = {
    vec2(-0.414213562373095,  1.000000000000000), 
    vec2( 0.414213562373095,  1.000000000000000), 
    vec2(-1.000000000000000,  0.414213562373095), 
    vec2( 1.000000000000000,  0.414213562373095), 
    vec2(-1.000000000000000, -0.414213562373095), 
    vec2( 1.000000000000000, -0.414213562373095),
    vec2(-0.414213562373095, -1.000000000000000), 
    vec2( 0.414213562373095, -1.000000000000000) 
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

#define VERTEX_LINK 0
#define VERTEX_CYLINDERS 1
#define VERTEX_LINK_ARC 2
#define VERTEX_LINK_CENTER 3
#define VERTEX_NODE_CENTER 4
#define VERTEX_MOUSE_DISK 5

void main() {
	// expand to unit quad
	float x = gl_VertexID / 2;
	float y = gl_VertexID % 2;
    float scale = 1.05;
	vec2 p = scale*(2.0 * vec2(x, y) - 1.0);
    p = scale*square[gl_VertexID];
	fragment_position = p;

	if (vertex_mode == VERTEX_CYLINDERS) {
		p *= points[gl_InstanceID].r;
		p += vec2(points[gl_InstanceID].x, points[gl_InstanceID].y);
		radius = points[gl_InstanceID].r;
	} else if (vertex_mode == VERTEX_LINK) {
        if (links[gl_InstanceID].front == -1) {
            p = vec2(0.0, 0.0);
        } else if (gl_VertexID == 0) {
            p = vec2(points[links[gl_InstanceID].left].x, points[links[gl_InstanceID].left].y);
        } else if (gl_VertexID == 1) {
            p = vec2(nodes[links[gl_InstanceID].front].x, nodes[links[gl_InstanceID].front].y);
        } else if (gl_VertexID == 2) {
            p = vec2(nodes[links[gl_InstanceID].back].x, nodes[links[gl_InstanceID].back].y);
        } else {
            p = vec2(points[links[gl_InstanceID].right].x, points[links[gl_InstanceID].right].y);
        }
    } else if (vertex_mode == VERTEX_NODE_CENTER) {
        radius = 0.5;
        p *= radius;
        p += vec2(nodes[gl_InstanceID].x, nodes[gl_InstanceID].y);
    } else if (vertex_mode == VERTEX_LINK_CENTER) {
        radius = 0.25;
        p *= radius;
        p += vec2(links[gl_InstanceID].x, links[gl_InstanceID].y);
    } else if (vertex_mode == VERTEX_LINK_ARC) {
        Link l = links[gl_InstanceID];

        if (l.Cr > 6.6e4) {
            p = scale*(2.0 * vec2(x, y) - 1.0);
            dvec2 p1 = vec2(nodes[l.front].x, nodes[l.front].y);
            dvec2 p2 = vec2(nodes[l.back].x, nodes[l.back].y);

            dvec2 pm = (p1 + p2)/2.0;
            double dx = abs(p2.x - p1.x) + 1.2;
            double dy = abs(p2.y - p1.y) + 1.2;
            radius = l.Cr;

            p = vec2(dvec2(p)*dvec2(dx, dy)/2.0 + pm);
            fragment_position = p;
        } else {
            float scale = 1.1;
            p = scale*(2.0 * vec2(x, y) - 1.0);
            vec2 p1 = vec2(nodes[l.front].x, nodes[l.front].y);
            vec2 p2 = vec2(nodes[l.back].x, nodes[l.back].y);

            vec2 pm = (p1 + p2)/2.0;
            float dx = abs(p2.x - p1.x) + 1.2;
            float dy = abs(p2.y - p1.y) + 1.2;
            radius = l.Cr;

            p *= vec2(dx, dy)/2.0;
            p += pm;

            fragment_position = scale*(2.0*(p - vec2(l.Cx - scale*radius, l.Cy - scale*radius))/(2*scale*radius) - 1.0);
            fragment_position2 = p;
        }
    } else if (vertex_mode == VERTEX_MOUSE_DISK) {
        radius = mouse_radius;
        p *= radius;
        p += mouse_pos;
    }

	// transform to NDC
    p = (p - cam_box.xy)/(cam_box.zw - cam_box.xy);
	p *= 2.0;
	p -= 1.0;
	gl_Position = vec4(p, 0.0, 1.0);

	instance_id = gl_InstanceID;
}