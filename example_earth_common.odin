import "core:fmt.odin";
import "core:math.odin";
import "core:mem.odin";

import stbi "shared:odin-stb/stb_image.odin";


// Unit isocahedron vertex positions. 
// From http://paulbourke.net/geometry/platonic/
ai :: 0.5;
bi :: 1.0/(1.0 + math.SQRT_FIVE);
icosahedron_vertices := [...]math.Vec3 {
    { 0,   bi, -ai},   { bi,  ai,  0 },   {-bi,  ai,  0 },
    { 0,   bi,  ai},   {-bi,  ai,  0 },   { bi,  ai,  0 },
    { 0,   bi,  ai},   { 0,  -bi,  ai},   {-ai,  0,   bi},
    { 0,   bi,  ai},   { ai,  0,   bi},   { 0,  -bi,  ai},
    { 0,   bi, -ai},   { 0,  -bi, -ai},   { ai,  0,  -bi},
    { 0,   bi, -ai},   {-ai,  0,  -bi},   { 0,  -bi, -ai},
    { 0,  -bi,  ai},   { bi, -ai,  0 },   {-bi, -ai,  0 },
    { 0,  -bi, -ai},   {-bi, -ai,  0 },   { bi, -ai,  0 },
    {-bi,  ai,  0 },   {-ai,  0,   bi},   {-ai,  0,  -bi},
    {-bi, -ai,  0 },   {-ai,  0,  -bi},   {-ai,  0,   bi},
    { bi,  ai,  0 },   { ai,  0,  -bi},   { ai,  0,   bi},
    { bi, -ai,  0 },   { ai,  0,   bi},   { ai,  0,  -bi},
    { 0,   bi,  ai},   {-ai,  0,   bi},   {-bi,  ai,  0 },
    { 0,   bi,  ai},   { bi,  ai,  0 },   { ai,  0,   bi},
    { 0,   bi, -ai},   {-bi,  ai,  0 },   {-ai,  0,  -bi},
    { 0,   bi, -ai},   { ai,  0,  -bi},   { bi,  ai,  0 },
    { 0,  -bi, -ai},   {-ai,  0,  -bi},   {-bi, -ai,  0 },
    { 0,  -bi, -ai},   { bi, -ai,  0 },   { ai,  0,  -bi},
    { 0,  -bi,  ai},   {-bi, -ai,  0 },   {-ai,  0,   bi},
    { 0,  -bi,  ai},   { ai,  0,   bi},   { bi, -ai,  0 },
};

Vertex :: struct {
    position: math.Vec3,
    pad0: u8,
    normal: math.Vec3,
    pad1: u8,
};

Model :: struct {
    vertices: []Vertex,
    
    num_vertices: int,
    num_triangles: int,
    
    vao: u32,
    vbo: u32,
};

make_models :: proc(N: int) -> []Model {
	models := make([]Model, N);

    // Create base model out of icosahedron vertices
    models[0].num_vertices = len(icosahedron_vertices);
    models[0].num_triangles = models[0].num_vertices/3;
    models[0].vertices = make([]Vertex, models[0].num_vertices);
    for vertex, i in icosahedron_vertices {
        models[0].vertices[i] = Vertex{math.norm0(vertex), 0, math.norm0(vertex), 0};
    }

    // subdivide 5 times, each subdivision takes a triangle and splits it into 4 pieces, 
    // and re-projecting each position onto the surface of the unit sphere
    for j in 0..N-1 {
        models[j+1].num_vertices = models[j].num_vertices*4;
        models[j+1].num_triangles = models[j].num_triangles*4;
        models[j+1].vertices = make([]Vertex, models[j+1].num_vertices);

        for i in 0..models[j].num_triangles {
            v1 := models[j].vertices[3*i+0].position;
            v2 := models[j].vertices[3*i+1].position;
            v3 := models[j].vertices[3*i+2].position;
            v12 := math.norm0((v1 + v2)/2.0);
            v23 := math.norm0((v3 + v2)/2.0);
            v13 := math.norm0((v1 + v3)/2.0);

            models[j+1].vertices[12*i+0].position = v1;
            models[j+1].vertices[12*i+1].position = v12;
            models[j+1].vertices[12*i+2].position = v13;

            models[j+1].vertices[12*i+3].position = v2;
            models[j+1].vertices[12*i+4].position = v23;
            models[j+1].vertices[12*i+5].position = v12;

            models[j+1].vertices[12*i+6].position = v3;
            models[j+1].vertices[12*i+7].position = v13;
            models[j+1].vertices[12*i+8].position = v23;

            models[j+1].vertices[12*i+9].position  = v12;
            models[j+1].vertices[12*i+10].position = v23;
            models[j+1].vertices[12*i+11].position = v13;
        }

        // normal is equal to position for a sphere!
        for i in 0..models[j+1].num_vertices {
            models[j+1].vertices[i].normal = models[j+1].vertices[i].position;
        }

        fmt.printf("Created model of %d vertices by subdivided model of %d vertices\n", models[j+1].num_vertices, models[j].num_vertices);
    }

    return models;
}


Image :: struct {
    width, height, channels: i32,
    filename: string,
    data: []u8,
}

load_cubemap_images :: proc() -> [6]Image {
    // Read cubemap textures
    filenames := [...]string { // @NOTE: This order is wrong! The normal is flipped inside the shader to correct for this as a quick hack
        "earth-cubemap/earth-cubemap-0.png",
        "earth-cubemap/earth-cubemap-1.png",
        "earth-cubemap/earth-cubemap-2.png",
        "earth-cubemap/earth-cubemap-3.png",
        "earth-cubemap/earth-cubemap-4.png",
        "earth-cubemap/earth-cubemap-5.png",
    };
    fmt.println(size_of(Vertex), size_of(math.Vec3));

    images: [6]Image;
    for _, i in filenames {
        using img := &images[i];
        filename = filenames[i];
        data = mem.slice_ptr(stbi.load(&filename[0], &width, &height, &channels, 3), int(width*height*3));
        fmt.printf("Read file `%s`: width = %d, height = %d, channels = %d\n", filename, width, height, channels);
    }

    return images;
}
