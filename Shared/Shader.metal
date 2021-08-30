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

    // color attachment 0
    half4 result [[color(0)]];
};

#pragma mark - Actual compute we want to achieve is here:

half4 func0(half4 input) {
    // Consume a lot of registers
    half4 a = sin(input);
    half4 b = sin(input + a);
    half4 c = sin(input + b);
    half4 d = sin(input + c);
    half4 e = sin(input + d);
    half4 f = sin(input + e) + a + b + c + d + e;
    return 1.0 - input + 0.001 * f;
}

half4 func1(half4 input) {
    // Consume a lot of registers
    half4 a = sin(input);
    half4 b = cos(input + a);
    half4 c = sin(input + b);
    half4 d = cos(input + c);
    half4 e = sin(input + d);
    half4 f = cos(input + e) + a + b + c + d + e;
    return 1.0 - input + 0.001 * f;
}

half4 func2(half4 input) {
    // Consume a lot of registers
    half4 a = cos(input);
    half4 b = cos(input + a);
    half4 c = cos(input + b);
    half4 d = cos(input + c);
    half4 e = cos(input + d);
    half4 ee = cos(input + e);
    half4 f = cos(input + ee) + a + b + c + d + e;
    return 1.0 - input + 0.001 * f;
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

//    half4 colorSample = colorMap.sample(colorSampler, vert.texCoord.xy);
     half4 colorSample = vert.texCoord.x + vert.texCoord.y;
     
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
        .temp0 = colorSample,
    };
}

// Apply func2 to result of func1
fragment MultiPassFragment fragmentShader2(
 half4 temp1 [[color(1)]]
// constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]]
)
{
    
    half4 colorSample = func2(temp1);

    return MultiPassFragment{
        .result = colorSample,
    };
}


fragment half4 fragmentShader012(
 Fullscreen vert [[stage_in]],
// constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
 texture2d<half, access::sample> colorMap     [[ texture(0) ]]
 ) {
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

     half4 colorSample = vert.texCoord.x + vert.texCoord.y;
//    half4 colorSample = colorMap.sample(colorSampler, vert.texCoord.xy);
    
    colorSample = func0(colorSample);
    colorSample = func1(colorSample);
    colorSample = func2(colorSample);

    return colorSample;
}

kernel void computeShader012(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    ushort2 gid [[thread_position_in_grid]]
) {
    float2 texCoord = float2(gid) / float2(input.get_width(), input.get_height());
    half4 colorSample = texCoord.x + texCoord.y;

    colorSample = func0(colorSample);
    colorSample = func1(colorSample);
    colorSample = func2(colorSample);

    output.write(colorSample, gid);
}
