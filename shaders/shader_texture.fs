#version 330 core

in vec2 fragment_position;
in vec2 fragment_uv;

out vec4 color;

uniform sampler2D texture_sampler;
uniform float time;

void main() {
    color = texture(texture_sampler, fragment_uv + vec2(cos(0.2*time), sin(0.2*time)));
}
