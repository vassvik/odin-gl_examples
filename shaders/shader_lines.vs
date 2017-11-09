#version 450 core

uniform float iGlobalTime;
out vec2 pos;
flat out int segment_index;

struct Point_Data {
	vec2 position;
	vec2 tangent;
	vec2 normal;
};

layout (std430, binding = 0) buffer point_data {
	Point_Data points[];
};

uniform bool is_point;

void main() {
	Point_Data d1 = points[gl_InstanceID];
	Point_Data d2 = points[gl_InstanceID+1];
	
	float w = 20.0;
	w = is_point ? 100000.0 : w;

	float f = 0.5 + 0.5*cos(iGlobalTime);
	f = 1.0;

	vec2 p;
	switch (gl_VertexID) {	
	case 0: p = d1.position + d1.normal/w; break;
	case 1: p = d1.position - d1.normal/w; break;
	case 2: p = d1.position + f*d1.tangent/3.0 + (is_point ? 0.0 : 1.0)*d1.normal/w; break;
	case 3: p = d1.position + f*d1.tangent/3.0 - (is_point ? 0.0 : 1.0)*d1.normal/w; break;
	case 4: p = d2.position - f*d2.tangent/3.0 + (is_point ? 0.0 : 1.0)*d2.normal/w; break;
	case 5: p = d2.position - f*d2.tangent/3.0 - (is_point ? 0.0 : 1.0)*d2.normal/w; break;
	case 6: p = d2.position + d2.normal/w; break;
	case 7: p = d2.position - d2.normal/w; break;
	}


    gl_Position = vec4(p, 0.0, 1.0);

	pos = p;
    segment_index = gl_InstanceID;
}



// 0---2---4---6---8
// |  /|  /|  /|  /|
// | / | / | / | / |
// |/  |/  |/  |/  |
// 1---3---5---7---9

//segment_index = (gl_VertexID - 2)/2;

//0    0
//1    0
//2    0
//3    0
//4    1
//5    1
//6    2
//7    2
//8    3
//9    3
