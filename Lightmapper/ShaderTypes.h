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

struct Uniforms {
    simd_float4x4 viewProj;
};

#endif /* ShaderTypes_h */

