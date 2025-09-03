//
//  Shaders.metal
//  MetalRT_Test
//
//  Created by Leo Battle on 02/09/2025.
//

#include <metal_stdlib>
using namespace metal;
using namespace raytracing;

#import "ShaderTypes.h"

struct VertexIn {
    float3 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 1.0);
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return float4(1);
}

kernel void rt_main(uint2 xy [[thread_position_in_grid]],
                    texture2d<float, access::write> tex [[texture(0)]],
                    primitive_acceleration_structure accel [[buffer(0)]]) {
    int w = tex.get_width();
    int h = tex.get_height();
    
    float2 uv = float2(xy) / float2(w, h) * 2. - 1.;
    
    ray r;
    r.origin = float3(uv, -1);
    r.direction = float3(0, 0, 1);
    r.min_distance = 0.1;
    r.max_distance = 10;
    
    intersector<triangle_data> inter;
    inter.assume_geometry_type(geometry_type::triangle);
    
    float4 colour;
    
    auto intersection = inter.intersect(r, accel);
    if (intersection.type == intersection_type::triangle) {
        colour = float4(1);
    }
    else {
        colour = float4(0);
    }
    
    tex.write(colour, xy);
}

struct VertexOut_Copy {
    float4 position [[position]];
    float2 uv;
};

constant float2 quadVertices[] = {
    float2(-1, -1),
    float2(-1,  1),
    float2( 1,  1),
    float2(-1, -1),
    float2( 1,  1),
    float2( 1, -1)
};

vertex VertexOut_Copy copyVertex(uint vertexId [[vertex_id]]) {
    VertexOut_Copy out;
    float2 position = quadVertices[vertexId];
    out.position = float4(position, 0.0f, 1.0f);
    out.uv = position * 0.5f + 0.5f;
    return out;
}

fragment float4 copyFragment(VertexOut_Copy in [[stage_in]],
                             texture2d<float> tex) {
    constexpr sampler sam(min_filter::nearest, mag_filter::nearest, mip_filter::none);
    float3 color = tex.sample(sam, in.uv).xyz;
    return float4(pow(color, 1/2.2), 1.0f);
}
