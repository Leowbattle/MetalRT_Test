//
//  Shaders.metal
//  Lightmapper
//
//  Created by Leo Battle on 04/09/2025.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
using namespace metal;
using namespace raytracing;

#include <simd/simd.h>

#import "ShaderTypes.h"

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
    float3 normal [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vert_main_flat(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.uv * 2 - 1, 0, 1);
//    out.colour = float3(in.uv, 0);
    return out;
}

vertex VertexOut vert_main(VertexIn in [[stage_in]],
                           constant Uniforms& u [[buffer(1)]]) {
    VertexOut out;
    out.position = u.viewProj * float4(in.position, 1);
    out.uv = in.uv;
    return out;
}

fragment float4 frag_main(VertexOut in [[stage_in]],
                          texture2d<float> tex [[texture(0)]],
                          primitive_acceleration_structure accel [[buffer(1)]]) {
    sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float x = tex.sample(s, in.uv).r;
    
    return float4(x, 0, 0, 1);
}
