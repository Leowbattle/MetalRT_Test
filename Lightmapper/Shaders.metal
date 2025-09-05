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

constant unsigned int primes[] = {
    2,   3,  5,  7,
    11, 13, 17, 19,
    23, 29, 31, 37,
    41, 43, 47, 53,
    59, 61, 67, 71,
    73, 79, 83, 89
};

// Returns the i'th element of the Halton sequence using the d'th prime number as a
// base. The Halton sequence is a low discrepency sequence: the values appear
// random, but are more evenly distributed than a purely random sequence. Each random
// value used to render the image uses a different independent dimension, `d`,
// and each sample (frame) uses a different index `i`. To decorrelate each pixel,
// you can apply a random offset to `i`.
float halton(unsigned int i, unsigned int d) {
    unsigned int b = primes[d];

    float f = 1.0f;
    float invB = 1.0f / b;

    float r = 0;

    while (i > 0) {
        f = f * invB;
        r = r + f * (i % b);
        i = i / b;
    }

    return r;
}

// Uses the inversion method to map two uniformly random numbers to a 3D
// unit hemisphere, where the probability of a given sample is proportional to the cosine
// of the angle between the sample direction and the "up" direction (0, 1, 0).
inline float3 sampleCosineWeightedHemisphere(float2 u) {
    float phi = 2.0f * M_PI_F * u.x;

    float cos_phi;
    float sin_phi = sincos(phi, cos_phi);

    float cos_theta = sqrt(u.y);
    float sin_theta = sqrt(1.0f - cos_theta * cos_theta);

    return float3(sin_theta * cos_phi, cos_theta, sin_theta * sin_phi);
}

// Aligns a direction on the unit hemisphere such that the hemisphere's "up" direction
// (0, 1, 0) maps to the given surface normal direction.
inline float3 alignHemisphereWithNormal(float3 sample, float3 normal) {
    // Set the "up" vector to the normal
    float3 up = normal;

    // Find an arbitrary direction perpendicular to the normal, which becomes the
    // "right" vector.
    float3 right = normalize(cross(normal, float3(0.0072f, 1.0f, 0.0034f)));

    // Find a third vector perpendicular to the previous two, which becomes the
    // "forward" vector.
    float3 forward = cross(right, up);

    // Map the direction on the unit hemisphere to the coordinate system aligned
    // with the normal.
    return sample.x * right + sample.y * up + sample.z * forward;
}

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 normal;
    float2 uv;
};

//vertex VertexOut vert_main_flat(VertexIn in [[stage_in]]) {
//    VertexOut out;
//    out.position = float4(in.uv * 2 - 1, 0, 1);
////    out.colour = float3(in.uv, 0);
//    return out;
//}

vertex VertexOut vert_main(VertexIn in [[stage_in]],
                           constant Uniforms& u [[buffer(1)]]) {
    VertexOut out;
    out.position = u.viewProj * float4(in.position, 1);
    out.worldPos = in.position;
    out.normal = in.normal;
    out.uv = in.uv;
    return out;
}

fragment float4 frag_main(VertexOut in [[stage_in]],
                          constant Uniforms& u [[buffer(1)]],
                          texture2d<float> tex [[texture(0)]],
                          primitive_acceleration_structure accel [[buffer(2)]],
                          constant Vertex* vertices [[buffer(3)]],
                          constant uint* indices [[buffer(4)]],
                          texture2d<unsigned int> randomTex [[texture(1)]]) {
//    sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
//    float x = tex.sample(s, in.uv).r;
    
    uint2 xy = uint2(in.position.xy);
    unsigned int offset = randomTex.read(xy).x;
    
    float2 rand = float2(halton(offset + u.frameIndex, 0),
               halton(offset + u.frameIndex, 1));
    
    float3 worldSpaceSampleDirection = sampleCosineWeightedHemisphere(rand);
    worldSpaceSampleDirection = alignHemisphereWithNormal(worldSpaceSampleDirection, in.normal);
    
    ray r;
    r.origin = in.worldPos;
    r.direction = worldSpaceSampleDirection;
    r.min_distance = 0.01;
    r.max_distance = 100;
    
    intersector<triangle_data> inter;
    inter.assume_geometry_type(geometry_type::triangle);
    inter.set_triangle_cull_mode(triangle_cull_mode::back);
    
    int maxBounces = 3;
    float colour = 1;
    int bounce;
    for (bounce = 0; bounce < maxBounces; bounce++) {
        auto intersection = inter.intersect(r, accel);
        if (intersection.type == intersection_type::triangle) {
            colour *= 0.8;
            
            float3 p = r.origin + intersection.distance * r.direction;
            
            int prim = intersection.primitive_id;
            
            float3 n0 = vertices[indices[prim * 3 + 0]].normal;
            float3 n1 = vertices[indices[prim * 3 + 1]].normal;
            float3 n2 = vertices[indices[prim * 3 + 2]].normal;
            float2 uv = intersection.triangle_barycentric_coord;
            float3 n = (1.0f - uv.x - uv.y) * n0 + uv.x * n1 + uv.y * n2;
            
            r.origin = p;
            r.direction = n;
        }
        else {
            break;
        }
    }
    if (bounce == maxBounces) {
        colour = 0;
    }
//    return float4(in.normal, 1);
    return float4(colour, colour, colour, 1);
}
