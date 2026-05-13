#include <metal_stdlib>
using namespace metal;

// ─── Wave simulation (compute) ────────────────────────────────────────
// Direct port of the WGSL compute shader in web ripple's index.html.
// 2D discrete wave equation, three ping-pong height textures rotated each
// frame, reflective bounds, soft Gaussian drop injection.

constant uint MAX_DROPS = 8;

struct Drop {
    float2 pos;
    float intensity;
    float _pad;
};

struct SimParams {
    float waveSpeed;
    float damping;
    uint dropCount;
    float _pad;
    Drop drops[MAX_DROPS];
};

kernel void waveStep(
    texture2d<float, access::read>  currentTex  [[texture(0)]],
    texture2d<float, access::read>  previousTex [[texture(1)]],
    texture2d<float, access::write> nextTex     [[texture(2)]],
    constant SimParams              &params     [[buffer(0)]],
    uint2                           gid         [[thread_position_in_grid]]
) {
    int2 size = int2(currentTex.get_width(), currentTex.get_height());
    int2 coord = int2(gid);
    if (coord.x >= size.x || coord.y >= size.y) return;

    // Reflective bounds — clamp neighbor sampling so waves bounce off edges
    int2 leftC  = clamp(coord + int2(-1,  0), int2(0), size - int2(1));
    int2 rightC = clamp(coord + int2( 1,  0), int2(0), size - int2(1));
    int2 topC   = clamp(coord + int2( 0, -1), int2(0), size - int2(1));
    int2 botC   = clamp(coord + int2( 0,  1), int2(0), size - int2(1));

    float cL = currentTex.read(uint2(leftC)).r;
    float cR = currentTex.read(uint2(rightC)).r;
    float cT = currentTex.read(uint2(topC)).r;
    float cB = currentTex.read(uint2(botC)).r;
    float c  = currentTex.read(uint2(coord)).r;
    float p  = previousTex.read(uint2(coord)).r;

    float next = c * 2.0 - p + params.waveSpeed * (cL + cR + cT + cB - 4.0 * c);
    next *= params.damping;

    // Inject any pending drops as soft Gaussian-ish bumps
    for (uint i = 0; i < params.dropCount; i++) {
        Drop d = params.drops[i];
        float dist = distance(float2(coord), d.pos);
        float r = 14.0;
        if (dist < r) {
            float falloff = 1.0 - smoothstep(0.0, r, dist);
            next += d.intensity * falloff * falloff;
        }
    }

    nextTex.write(float4(next, 0.0, 0.0, 0.0), uint2(coord));
}

// ─── Lit water render (vertex + fragment) ────────────────────────────
// Full-screen triangle, computes per-pixel surface normals from neighbor
// heights via finite differences, lights them with diffuse + specular + fresnel.

struct RenderParams {
    float2 resolution;
    float time;
    float _pad;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut waterVertex(uint vid [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0),
    };
    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0),
    };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = uvs[vid];
    return out;
}

fragment float4 waterFragment(
    VertexOut                       in        [[stage_in]],
    texture2d<float, access::read>  heightTex [[texture(0)]],
    constant RenderParams           &rp       [[buffer(0)]]
) {
    int2 size = int2(heightTex.get_width(), heightTex.get_height());
    int2 coord = clamp(int2(in.uv * float2(size)), int2(0), size - int2(1));

    int2 L = clamp(coord + int2(-1,  0), int2(0), size - int2(1));
    int2 R = clamp(coord + int2( 1,  0), int2(0), size - int2(1));
    int2 T = clamp(coord + int2( 0, -1), int2(0), size - int2(1));
    int2 B = clamp(coord + int2( 0,  1), int2(0), size - int2(1));
    float hL = heightTex.read(uint2(L)).r;
    float hR = heightTex.read(uint2(R)).r;
    float hT = heightTex.read(uint2(T)).r;
    float hB = heightTex.read(uint2(B)).r;

    float3 n = normalize(float3((hL - hR) * 4.0, (hT - hB) * 4.0, 1.0));

    // Base water — deep teal vignette around the center
    float2 center = float2(0.5, 0.5);
    float d = distance(in.uv, center);
    float vignette = 1.0 - smoothstep(0.25, 1.05, d);
    float3 deep    = float3(0.012, 0.045, 0.110);
    float3 shallow = float3(0.055, 0.155, 0.260);
    float3 baseColor = mix(deep, shallow, vignette);

    // Diffuse — light angled from upper-left
    float3 lightDir = normalize(float3(0.35, 0.55, 0.9));
    float diff = max(dot(n, lightDir), 0.0);

    // Specular crest highlight — narrow & bright on wave peaks
    float3 viewDir = float3(0.0, 0.0, 1.0);
    float3 halfway = normalize(lightDir + viewDir);
    float spec = pow(max(dot(n, halfway), 0.0), 48.0);

    // Subtle fresnel-ish rim
    float fres = pow(1.0 - max(n.z, 0.0), 3.0);

    float3 color = baseColor;
    color += float3(0.22, 0.42, 0.55) * diff * 0.22;
    color += float3(0.75, 0.90, 1.00) * spec * 1.1;
    color += float3(0.15, 0.30, 0.45) * fres * 0.35;

    return float4(color, 1.0);
}
