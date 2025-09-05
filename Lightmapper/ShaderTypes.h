//
//  ShaderTypes.h
//  Lightmapper
//
//  Created by Leo Battle on 04/09/2025.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

struct Vertex {
    simd_float3 position;
    simd_float3 normal;
    simd_float2 uv;
};

struct Uniforms {
    int frameIndex;
    simd_float4x4 viewProj;
    simd_float4x4 view;
};

#endif /* ShaderTypes_h */

