//
//  Shader.metal
//  Shader
//
//  Created by Andrew Pouliot on 8/26/21.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} Fullscreen;

// Vertex function hardcodes a fullscreen triangle
vertex Fullscreen fullscreenTriangleVertex(ushort id [[ vertex_id ]]) {
    const float minV = -1;
    const float maxV = 3;
    switch (id) {
        case 0:
            return Fullscreen{.position = float4(minV,minV,0,1), .texCoord = float2(0, 0)};
        case 1:
            return Fullscreen{.position = float4(maxV,minV,0,1), .texCoord = float2(2, 0)};
        default:
        case 2:
            return Fullscreen{.position = float4(minV,maxV,0,1), .texCoord = float2(0, 2)};
    }
}

// Red for now
fragment float4 fillRedFrag(Fullscreen vert [[stage_in]]) {
    const float2 a = vert.texCoord;
    return float4(a.x, a.y, 0, 1);
}

struct MultiPassFragment {
    // color attachment 1
    half4 temp0 [[color(1)]];
    // color attachment 2
    half4 temp1 [[color(2)]];

    // color attachment 0
    half4 result [[color(0)]];
};

#pragma mark - Actual compute we want to achieve is here:

half4 func0(half4 input) {
    // TODO: consume a lot of registers
    return 1.0 - input;
}

half4 func1(half4 input) {
    // TODO: consume a lot of registers
    return 1.0 - input + 0.001 * sin(input);
}

half4 func2(half4 input) {
    // TODO: consume a lot of registers
    return 1.0 - input + 0.001 * sin(input);
}


// Read initial texture, apply func0
fragment MultiPassFragment fragmentShader0(
 Fullscreen vert [[stage_in]],
// constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
 texture2d<half, access::sample> colorMap     [[ texture(0) ]]
 ) {
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample = colorMap.sample(colorSampler, vert.texCoord.xy);

    colorSample = func0(colorSample);
     
    return MultiPassFragment{
        .temp0 = colorSample,
    };
}

// Apply func1 to result of func0
fragment MultiPassFragment fragmentShader1(
 half4 temp0 [[color(1)]]
// constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]]
) {
    
    half4 colorSample = func1(temp0);

    return MultiPassFragment{
        .temp1 = colorSample,
    };
}

// Apply func2 to result of func1
fragment MultiPassFragment fragmentShader2(
 half4 temp1 [[color(2)]]
// constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]]
) {
    
    half4 colorSample = func2(temp1);

    return MultiPassFragment{
        .temp1 = colorSample,
    };
}
