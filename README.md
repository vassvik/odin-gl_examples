# odin-gl_examples

Require GLFW binaries either locally (windows, .lib and .dll) or in the system paths (linux, .so). 

Initialize the submodules with
```
git submodule update --init --recursive --remote
```

Currently contains:

### example_triangle

Single triangle


### example_shaderboy

Screen-covering quad, copy of a shadertoy. 
There is also a bufferless example


### example_hex

Draws tiled hexagons, no buffers.


### example_text

Simple font rendering, using bufferless quads and instancing.
Uses a binary file format. See `external/gl_font/font.odin` for details.


### example_render_to_texture

Render to texture example, containing some edge detection post-processing.
Work in progress..


### example_solids

Renders sphere approximations by subdividing platonic solids