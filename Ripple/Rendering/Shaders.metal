#include <metal_stdlib>
using namespace metal;

// ─── Shared params ────────────────────────────────────────────────────

constant uint MAX_DROPS = 8;

struct Drop {
    float2 pos;        // in sim-texel space
    float  intensity;
    float  _pad;
};

struct SimParams {
    float waveSpeed;    // CFL-lumped coefficient (≤0.5 for the 5-pt stencil)
    float damping;      // small global energy sink (≈0.999); the real decay
                        // is the viscosity term below
    float viscosity;    // coefficient on ∇²(c−p) — frequency-dependent decay
    float spongeBand;   // absorbing-edge band width, in texels
    float spongeEdge;   // per-step attenuation reached at the very edge (≈0.92)
    float dropRadius;   // resolution-relative drop radius, in texels
    uint  dropCount;
    float _pad;
    Drop  drops[MAX_DROPS];
};

struct RenderParams {
    float2 resolution;   // sim texture dimensions
    float  time;
    float  normalScale;  // resolution-relative slope gain (look-invariant)
    float  aspect;       // viewport width / height (for round vignette)
    float  _pad0;
    float  _pad1;
    float  _pad2;
};

// ─── Texture clear (compute) ──────────────────────────────────────────
// .private textures hold undefined memory at allocation. Zero them once
// on (re)alloc so the pool opens as perfect glass and rotations don't
// flash propagated garbage.
kernel void clearTex(
    texture2d<float, access::write> tex [[texture(0)]],
    uint2                           gid [[thread_position_in_grid]]
) {
    if (int(gid.x) >= int(tex.get_width()) ||
        int(gid.y) >= int(tex.get_height())) return;
    tex.write(float4(0.0), gid);
}

// ─── Drop seeding (compute) ───────────────────────────────────────────
// A real stone makes a *displacement* released from rest: initial height
// ≠ 0, initial velocity ≈ 0. The leapfrog reads velocity implicitly as
// (current − previous), so we add the SAME profile to BOTH textures →
// implied initial velocity is zero. Profile is a Mexican-hat (central
// depression + raised rim): the outward ring then emerges from the
// physically-correct cavity rebound, not a poke from below.
//
// Each thread touches only its own texel of each texture (no neighbour
// reads), so read_write on both is hazard-free.

kernel void seedDrops(
    texture2d<float, access::read_write> currentTex  [[texture(0)]],
    texture2d<float, access::read_write> previousTex [[texture(1)]],
    constant SimParams                   &params     [[buffer(0)]],
    uint2                                gid         [[thread_position_in_grid]]
) {
    int2 size = int2(currentTex.get_width(), currentTex.get_height());
    if (int(gid.x) >= size.x || int(gid.y) >= size.y) return;
    uint2 uv = gid;

    float disp = 0.0;
    float r = max(params.dropRadius, 4.0);
    for (uint i = 0; i < params.dropCount; i++) {
        Drop d = params.drops[i];
        float dist = distance(float2(gid), d.pos);
        if (dist < r * 1.6) {
            // Difference-of-Gaussians "crater": negative core, positive rim.
            float x = dist / r;
            float core = exp(-x * x * 2.2);          // central depression
            float rim  = exp(-(x - 1.0) * (x - 1.0) * 3.0) * 0.55; // raised ring
            disp += d.intensity * (rim - core);
        }
    }
    if (disp == 0.0) return;

    float c = currentTex.read(uv).r  + disp;
    float p = previousTex.read(uv).r + disp;   // same add → zero initial velocity
    currentTex.write(float4(c, 0, 0, 0), uv);
    previousTex.write(float4(p, 0, 0, 0), uv);
}

// ─── Wave step (compute) ──────────────────────────────────────────────
// Damped explicit leapfrog of the 2D wave equation, plus:
//  • viscosity term μ·∇²(c−p): damps proportional to the curvature of the
//    *rate of change*, so the effective decay scales with k² — capillary
//    detail dies fast, the long swell persists (real water; not a rubber
//    sheet).
//  • sponge edge: a thin band where energy is bled off so ripples fade as
//    they reach the rim instead of bouncing forever in a sealed tank.
//  • hard clamp + isfinite scrub so one bad texel can't poison the field.

inline float lap5(texture2d<float, access::read> t, int2 c, int2 size) {
    int2 L = clamp(c + int2(-1, 0), int2(0), size - int2(1));
    int2 R = clamp(c + int2( 1, 0), int2(0), size - int2(1));
    int2 T = clamp(c + int2( 0,-1), int2(0), size - int2(1));
    int2 B = clamp(c + int2( 0, 1), int2(0), size - int2(1));
    float v = t.read(uint2(c)).r;
    return t.read(uint2(L)).r + t.read(uint2(R)).r
         + t.read(uint2(T)).r + t.read(uint2(B)).r - 4.0 * v;
}

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

    float c = currentTex.read(uint2(coord)).r;
    float p = previousTex.read(uint2(coord)).r;

    float lapC = lap5(currentTex, coord, size);
    float lapP = lap5(previousTex, coord, size);

    // Leapfrog + frequency-dependent viscous dissipation
    float next = c * 2.0 - p + params.waveSpeed * lapC
               + params.viscosity * (lapC - lapP);
    next *= params.damping;

    // Sponge: quadratic ramp from 1.0 (interior) to spongeEdge (rim).
    int e = min(min(coord.x, size.x - 1 - coord.x),
                min(coord.y, size.y - 1 - coord.y));
    float t = saturate(float(e) / max(params.spongeBand, 1.0));
    next *= mix(params.spongeEdge, 1.0, t * t);

    // Containment: never let a runaway / NaN propagate across the field.
    next = isfinite(next) ? clamp(next, -4.0, 4.0) : 0.0;

    nextTex.write(float4(next, 0.0, 0.0, 0.0), uint2(coord));
}

// ─── Lit water render (vertex + fragment) ─────────────────────────────

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

// Manual bilinear fetch — r32Float isn't sampler-filterable, and the sim
// runs at ~0.6× backing res. Point-sampling magnified ~5× to Retina gave
// staircased speculars; bilinear smooths the height field before normals.
inline float bilinearHeight(texture2d<float, access::read> tex,
                            float2 texPos, int2 size) {
    float2 p = texPos - 0.5;
    float2 f = fract(p);
    int2 i = int2(floor(p));
    int2 i00 = clamp(i + int2(0, 0), int2(0), size - int2(1));
    int2 i10 = clamp(i + int2(1, 0), int2(0), size - int2(1));
    int2 i01 = clamp(i + int2(0, 1), int2(0), size - int2(1));
    int2 i11 = clamp(i + int2(1, 1), int2(0), size - int2(1));
    float h00 = tex.read(uint2(i00)).r;
    float h10 = tex.read(uint2(i10)).r;
    float h01 = tex.read(uint2(i01)).r;
    float h11 = tex.read(uint2(i11)).r;
    return mix(mix(h00, h10, f.x), mix(h01, h11, f.x), f.y);
}

// Cheap procedural sky the water reflects — cool zenith → warm horizon.
inline float3 skyColor(float3 dir) {
    float t = saturate(dir.y * 0.5 + 0.5);
    float3 horizon = float3(0.16, 0.26, 0.40);
    float3 zenith  = float3(0.02, 0.06, 0.14);
    float3 sky = mix(horizon, zenith, t);
    // Soft sun bloom toward the key-light direction.
    float3 sun = normalize(float3(0.35, 0.55, 0.9));
    float s = pow(saturate(dot(dir, sun)), 64.0);
    return sky + float3(0.9, 0.85, 0.7) * s * 0.6;
}

fragment float4 waterFragment(
    VertexOut                       in        [[stage_in]],
    texture2d<float, access::read>  heightTex [[texture(0)]],
    constant RenderParams           &rp       [[buffer(0)]]
) {
    int2 size = int2(heightTex.get_width(), heightTex.get_height());
    float2 sizeF = float2(size);
    float2 texPos = in.uv * sizeF;

    // Bilinear height + neighbours one texel apart (for the gradient).
    float texel = 1.0;
    float hC = bilinearHeight(heightTex, texPos, size);
    float hL = bilinearHeight(heightTex, texPos + float2(-texel, 0), size);
    float hR = bilinearHeight(heightTex, texPos + float2( texel, 0), size);
    float hT = bilinearHeight(heightTex, texPos + float2(0, -texel), size);
    float hB = bilinearHeight(heightTex, texPos + float2(0,  texel), size);

    // Resolution-invariant slope: normalScale is set on the host from the
    // sim dimensions so the lighting character doesn't drift if the sim
    // resolution scale changes.
    float3 n = normalize(float3((hL - hR) * rp.normalScale,
                                (hT - hB) * rp.normalScale,
                                1.0));

    float3 viewDir = float3(0.0, 0.0, 1.0);

    // Aspect-correct radial vignette → a round pool on a tall phone.
    float2 cuv = in.uv - 0.5;
    cuv.x *= rp.aspect;
    float d = length(cuv);
    float vignette = 1.0 - smoothstep(0.32, 1.15, d);

    float3 deep    = float3(0.012, 0.045, 0.110);
    float3 shallow = float3(0.055, 0.155, 0.260);
    float3 body = mix(deep, shallow, vignette);

    // Depth tint — troughs darker, crests lighter (fake thickness/SSS).
    body *= 1.0 + clamp(hC, -0.6, 0.6) * 0.45;

    // Hemispheric ambient so shadowed faces don't crush to black on OLED.
    float3 ambient = mix(float3(0.02, 0.05, 0.09),
                         float3(0.08, 0.14, 0.22),
                         n.z * 0.5 + 0.5) * 0.5;

    // Diffuse key light.
    float3 lightDir = normalize(float3(0.35, 0.55, 0.9));
    float diff = max(dot(n, lightDir), 0.0);

    // Schlick Fresnel mixing the water body with a reflected sky — the
    // single biggest "this is water, not jelly" cue.
    float F0 = 0.02;
    float fres = F0 + (1.0 - F0) * pow(1.0 - max(dot(n, viewDir), 0.0), 5.0);
    float3 refl = skyColor(reflect(-viewDir, n));

    // Tight specular crest glint (can exceed 1.0 → blooms on EDR displays).
    float3 halfway = normalize(lightDir + viewDir);
    float spec = pow(max(dot(n, halfway), 0.0), 80.0);

    float3 color = body + ambient;
    color += float3(0.22, 0.42, 0.55) * diff * 0.20;
    color = mix(color, refl, fres * 0.85);
    color += float3(1.05, 1.15, 1.25) * spec * 1.4;

    // Output dither — kills banding in the dark teal gradient on 8-bit /
    // OLED. Triangular hash, ~1 LSB.
    float dither = fract(sin(dot(in.position.xy, float2(12.9898, 78.233)))
                         * 43758.5453);
    color += (dither - 0.5) / 255.0;

    return float4(color, 1.0);
}
