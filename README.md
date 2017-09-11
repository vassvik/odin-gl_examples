# odin-gl_examples

Require GLFW binaries either locally (windows, .lib and .dll) or in the system paths (linux, .so). 

Make sure to get the dependencies and place then in the `shared` collection:
```
cd Odin/shared
git clone https://github.com/vassvik/odin-glfw.git
git clone https://github.com/vassvik/odin-gl.git
git clone https://github.com/vassvik/odin-gl_font.git
```

### The following is out of date:

Partial list: Currently contains:

### example_triangle

Single triangle

![triangle](http://i.imgur.com/CdPfTJ7.png)


### example_shaderboy

Screen-covering quad, and a copy of a [shadertoy](https://www.shadertoy.com/view/4sXyDr).
There is also a bufferless example

![shadertoy](http://i.imgur.com/y4MvVS1.jpg)


### example_hex

Draws tiled hexagons, no buffers.

![hex](http://i.imgur.com/leT6dBq.png)


### example_text

Simple bitmap font rendering, using bufferless quads and instancing.
Uses a binary file format. See `shared/gl_font/font.odin` for details.

![text](http://i.imgur.com/nTv85xc.png)


### example_render_to_texture

Render to texture example, containing some edge detection post-processing.
Work in progress..


### example_solids

Renders sphere approximations by subdividing platonic solids

![spheres](http://i.imgur.com/xke0Dcq.png)
