#version 330 core

flat in int instance;

out vec4 color;

void main() {
    float R = 0.5 + 0.5*cos(1.3 + 2.0*instance);
    float G = 0.5 + 0.5*cos(2.5 - 3.0*instance);
    float B = 0.5 + 0.5*cos(3.2 + 5.0*instance);

    color = vec4(R, G, B, 1.0);
}
