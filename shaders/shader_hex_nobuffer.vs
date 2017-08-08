/*
    Vertex shader for rendering hexagons without any vertex buffers (no explicit input)

    Works by expanding the vertex ID into vertex positions, assuming triangle strips. 
    The instance ID can then be used to position each hexagon tile, 
    either in a grid directly or indirectly by look up position values in uniform buffers or a texture.

    Example calling code:

        glUseProgram(program);
        glUniform2f(glGetUniformLocation(program, "resolution"), resx, resy);

        int Nx = 64, Ny = 32;
        glUniform1i(glGetUniformLocation(program, "Nx"), Nx);
        glUniform1i(glGetUniformLocation(program, "Ny"), Ny);
        
        glBindVertexArray(vao);
        glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 6, Nx*Ny);

    Useful geometric quantities:

        0.28867513459 == sqrt(3)/6 == 1/(sqrt(3)*2)
        0.57735026919 == sqrt(3)/3 == 1/sqrt(3)
        0.86602540378 == sqrt(3)/2 == 3/(sqrt(3)*2)
*/

#version 330 core

uniform int Nx;
uniform int Ny;
uniform vec2 resolution;

flat out int instance;

vec2 hexagon(int vertex_id, vec2 scale_factor);
vec2 hexagon_alt(int vertex_id, vec2 scale_factor);

void main() {
    vec2 p0 = hexagon(gl_VertexID, vec2(0.28867513459, 0.5)); // scaled so that the height is unity, and equal sides

    // position tile
    int x = gl_InstanceID%Nx;
    int y = gl_InstanceID/Nx;
    vec2 p = p0 + vec2(x*0.86602540378, y + 0.5*(x&1) + 0.5);

    // move and scale so that it aligns nicely
    p.x -= 0.86602540378*(Nx-1)/2.0;
    p /= (Ny+1)/2.0;
    p.y -= 1.0;

    // correct for aspect ratio
    p.x /= resolution.x/resolution.y;

    gl_Position = vec4(p, 0.0, 1.0);

    // forward to fragment shader
    instance = gl_InstanceID;
}

/*
    Courtesy of @d7samurai for deriving these

    Creates vertex coordinates in the following order based on vertex ID:
        -2,  0
        -1,  1
        -1, -1
         1,  1
         1, -1
         2,  0

    Needs a scaling factor proportional to (sqrt(3)/3, 1.0) for a regular hexagon

    Note: The top and edges are horizontal. 
          If you require the left and right edge to be vertical, just swap the x and y values
*/
vec2 hexagon_alt(int vertex_id, vec2 scale_factor) {
    return vec2(((ivec2(0x433110, 0x102021) >> (vertex_id << 2)) & 7) - ivec2(2, 1))*scale_factor; 
}

vec2 hexagon(int vertex_id, vec2 scale_factor) {
    int x = (vertex_id + 1) >> 1;
    int y = (vertex_id & 1) << 1;
    
    return vec2(x + (x >> 1) - 2, y - ((vertex_id + 3) >> 2)) * scale_factor;
}