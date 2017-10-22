#version 450 core

out vec2 position_normalized;
out vec2 position_world;
flat out int instance_id;

uniform int vertex_mode;
uniform float time;
uniform float mouse_radius;
uniform vec2 mouse_pos;
uniform vec2 resolution;
uniform vec4 cam_box;

// For lookup using gl_VertexID
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

// For lookup using gl_InstanceID
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


layout (std430, binding = 0) buffer point_buffer {
    Point points[];
};

layout (std430, binding = 1) buffer node_buffer {
    Node nodes[];
};

layout (std430, binding = 2) buffer link_buffer {
    Link links[];
};

#define VERTEX_NONE -1
#define VERTEX_LINK 0
#define VERTEX_CYLINDERS 1
#define VERTEX_LINK_ARC 2
#define VERTEX_LINK_CENTER 3
#define VERTEX_NODE_SMALL 4
#define VERTEX_MOUSE_DISK 5
#define VERTEX_NODE_FIT 6
#define VERTEX_LINK_FIT 7

void main() {
	// expand to unit square/hexagon/octagon
    float scale = 1.05;
	vec2 p = scale*square[gl_VertexID];
	position_normalized = p;
    if (vertex_mode == VERTEX_NONE) {
        p = vec2(1000000.0);
    } else if (vertex_mode == VERTEX_LINK) {
        // Light blue quads, red if selected by mouse
        Link link = links[gl_InstanceID];

        switch (gl_VertexID) {
        case 0:
            p = points[link.left].P; 
            break;
        case 1:
            p = nodes[link.front].P;
            break;
        case 2:
            p = nodes[link.back].P;
            break;
        case 3:
            p = points[link.right].P; 
            break;
        default:
            p = vec2(0.0, 0.0);
            break;
        }
    } else if (vertex_mode == VERTEX_MOUSE_DISK) {
        // blue disk following mouse cursor
        p *= mouse_radius;
        p += mouse_pos;
    } else if (vertex_mode == VERTEX_CYLINDERS) {
        // green cylinders
        p *= points[gl_InstanceID].r;
        p += points[gl_InstanceID].P;
    } else if (vertex_mode == VERTEX_NODE_SMALL) {
        // yellow disks 
        p *= 0.5;
        p += nodes[gl_InstanceID].P;
    } else if (vertex_mode == VERTEX_NODE_FIT) {
        // yellow disks 
        Point Q = points[links[nodes[gl_InstanceID].links[0]].left];
        float r = length(Q.P - nodes[gl_InstanceID].P) - Q.r;
        p *= r;
        p += nodes[gl_InstanceID].P;
    } else if (vertex_mode == VERTEX_LINK_CENTER) {
        // purple disks
        p *= 0.25;
        p += links[gl_InstanceID].M;
    } else if (vertex_mode == VERTEX_LINK_FIT) {
        // purple disks
        float r = length(links[gl_InstanceID].M - points[links[gl_InstanceID].left].P) - points[links[gl_InstanceID].left].r;
        p *= r;
        p += links[gl_InstanceID].M;
    } else if (vertex_mode == VERTEX_LINK_ARC) {
        // gray arc
        Link l = links[gl_InstanceID];

        vec2 p1 = nodes[l.front].P;
        vec2 p2 = nodes[l.back].P;

        // axis aligned bounding box, could probably make it more tight by rotating it
        // constant of 1.2 works with the small arcs
        vec2 pm = (p1 + p2)/2.0;
        float dx = abs(p2.x - p1.x) + 1.9;
        float dy = abs(p2.y - p1.y) + 1.5;
        
        p = p*vec2(dx, dy)/2.0 + pm;

        if (l.R > 6.6e4) {
            position_normalized = p;
        } else {
            position_normalized = scale*(2.0*(p - (l.O - scale*l.R))/(2*scale*l.R) - 1.0);
            position_world = p;
        }
    } 
    position_world = p;

	// transform to NDC
    p = (p - cam_box.xy)/(cam_box.zw - cam_box.xy);
	p *= 2.0;
	p -= 1.0;
	gl_Position = vec4(p, 0.0, 1.0);

	instance_id = gl_InstanceID;
}