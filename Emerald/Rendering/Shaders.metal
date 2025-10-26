//
//  Shaders.metal
//  Emerald
//
//  Created by Christian Koscielniak Pinto on 26/10/25.
//

#include <metal_stdlib>
using namespace metal;

// Vertex shader input/output structures
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Vertex shader
vertex VertexOut vertex_main(const device VertexIn* vertex_array [[buffer(0)]],
                            unsigned int vid [[vertex_id]]) {
    VertexIn in = vertex_array[vid];
    
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    
    return out;
}

// Fragment shader - basic pixel-perfect rendering
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             texture2d<half> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::nearest,
                                   min_filter::nearest);
    
    const half4 colorSample = colorTexture.sample(textureSampler, in.texCoord);
    return float4(colorSample);
}

// Fragment shader with CRT effect
fragment float4 fragment_crt(VertexOut in [[stage_in]],
                            texture2d<half> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear);
    
    float2 uv = in.texCoord;
    
    // CRT screen curvature
    uv = uv * 2.0 - 1.0;
    float2 offset = abs(uv.yx) / float2(3.0, 1.5);
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;
    
    // Sample the texture
    half4 color = colorTexture.sample(textureSampler, uv);
    
    // Scanlines
    float scanline = sin(uv.y * 240.0 * 3.14159) * 0.1;
    color.rgb *= (1.0 - scanline);
    
    // Vignette
    float2 vignetteUV = uv * (1.0 - uv.yx);
    float vignette = vignetteUV.x * vignetteUV.y * 15.0;
    vignette = pow(vignette, 0.25);
    color.rgb *= vignette;
    
    return float4(color);
}

// Fragment shader with scanlines
fragment float4 fragment_scanlines(VertexOut in [[stage_in]],
                                  texture2d<half> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::nearest,
                                   min_filter::nearest);
    
    const half4 colorSample = colorTexture.sample(textureSampler, in.texCoord);
    
    // Add scanlines
    half scanline = sin(in.texCoord.y * 160.0 * 2.0 * 3.14159) * 0.05 + 0.95;
    
    return float4(half4(colorSample.rgb * scanline, colorSample.a));
}

// Fragment shader with smooth scaling
fragment float4 fragment_smooth(VertexOut in [[stage_in]],
                               texture2d<half> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear);
    
    const half4 colorSample = colorTexture.sample(textureSampler, in.texCoord);
    return float4(colorSample);
}

// Color correction shader
fragment float4 fragment_color_corrected(VertexOut in [[stage_in]],
                                        texture2d<half> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::nearest,
                                   min_filter::nearest);
    
    half4 color = colorTexture.sample(textureSampler, in.texCoord);
    
    // GBA color correction matrix
    // This compensates for the original GBA's darker, more saturated screen
    half3x3 colorMatrix = half3x3(
        1.0,   0.0,   0.0,
        0.0,   1.0,   0.0,
        0.0,   0.0,   1.0
    );
    
    // Apply gamma correction (GBA screen was darker)
    color.rgb = pow(color.rgb, half(0.8));
    
    // Apply color matrix
    color.rgb = colorMatrix * color.rgb;
    
    // Increase saturation slightly
    half3 grayscale = dot(color.rgb, half3(0.299, 0.587, 0.114));
    color.rgb = mix(half3(grayscale), color.rgb, half(1.2));
    
    return float4(color);
}