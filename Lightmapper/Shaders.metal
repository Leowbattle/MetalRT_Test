//
//  Shaders.metal
//  Lightmapper
//
//  Created by Leo Battle on 04/09/2025.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

#import "ShaderTypes.h"

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
    float3 normal [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
};

vertex VertexOut vert_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.uv * 2 - 1, 0, 1);
    out.normal = in.normal / 2 + 0.5;
    return out;
}

fragment float4 frag_main(VertexOut in [[stage_in]]) {
    return float4(in.normal, 1);
}
