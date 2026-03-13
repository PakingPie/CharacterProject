#ifndef CUSTOM_FABRIC_PROCEDURAL_PATTERN_UTILITIES_INCLUDED
#define CUSTOM_FABRIC_PROCEDURAL_PATTERN_UTILITIES_INCLUDED

// ── SSAO ─────────────────────────────────────
float2 SampleSSAO(float2 screenUV)
{
    float DirectAO = 1.0;
    float IndirectAO = 1.0;
#if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
    float ssao = saturate(SampleAmbientOcclusion(screenUV) + (1.0 - _AmbientOcclusionParam.x));
    IndirectAO = ssao;
    DirectAO = lerp(1.0, ssao, _AmbientOcclusionParam.w);
#endif
    return float2(DirectAO, IndirectAO);
}

// ── IBL ──────────────────────────────────────
struct IBLComponents
{
    float3 specular;
    float3 diffuse;
};

IBLComponents CalculateIBLComponents(
    float3 normalWS, float3 viewDirWS, float3 positionWS, float2 screenUV,
    float3 albedo, float roughness,
    float3 kS, float3 kD,
    float2 brdf, float envLOD,
    float3 bakedIrradiance)
{
    IBLComponents result = (IBLComponents)0;
    result.diffuse = kD * albedo * bakedIrradiance;

    if (_UseReflectiveProbe > 0)
    {
        float3 R = reflect(-viewDirWS, normalWS);
        float3 prefiltered = GlossyEnvironmentReflection(
            R, positionWS, roughness, 1.0, screenUV);
        result.specular = prefiltered * (kS * brdf.x + brdf.y);
    }

    return result;
}

float3 CalculateIBL(
    float3 normalWS, float3 viewDirWS, float3 positionWS, float2 screenUV,
    float3 albedo, float roughness,
    float3 kS, float3 kD,
    float2 brdf, float envLOD,
    float3 bakedIrradiance)
{
    IBLComponents result = CalculateIBLComponents(
        normalWS, viewDirWS, positionWS, screenUV,
        albedo, roughness,
        kS, kD,
        brdf, envLOD,
        bakedIrradiance);

    return result.specular + result.diffuse;
}

// ── BRDF Utilities ───────────────────────────
float2 EnvBRDFApprox(float roughness, float NoV)
{
    const float4 c0 = float4(-1.0, -0.0275, -0.572, 0.022);
    const float4 c1 = float4(1.0, 0.0425, 1.040, -0.040);
    float4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return float2(-1.04, 1.04) * a004 + r.zw;
}

float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max((float3)(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float3 FresnelSchlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// ── Ward Anisotropic Specular (strip highlight) ─────
float WardAnisotropicSpecular(float3 H, float3 T, float3 B, float3 N,
                              float roughness, float anisotropy)
{
    float TdotH = dot(T, H);
    float BdotH = dot(B, H);
    float NdotH = dot(N, H);

    float roughnessT = roughness * (1.0 + anisotropy);
    float roughnessB = roughness * (1.0 - anisotropy);

    float normalization = rcp(PI * roughnessT * roughnessB);
    float exponent = -(TdotH * TdotH / (roughnessT * roughnessT)
                     + BdotH * BdotH / (roughnessB * roughnessB))
                     / (NdotH * NdotH + 0.0001);

    return normalization * exp(exponent);
}

// ── Ward with independent T/B roughness ───────────
float WardSpecularSplit(float3 H, float3 T, float3 B, float3 N,
                        float roughnessT, float roughnessB)
{
    float TdotH = dot(T, H);
    float BdotH = dot(B, H);
    float NdotH = dot(N, H);

    float normalization = rcp(PI * roughnessT * roughnessB);
    float exponent = -(TdotH * TdotH / (roughnessT * roughnessT)
                     + BdotH * BdotH / (roughnessB * roughnessB))
                     / (NdotH * NdotH + 0.0001);

    return normalization * exp(exponent);
}

// ── Anisotropic GGX NDF ─────────────────────
float DistributionGGXAnisotropic(float3 N, float3 T, float3 H,
                                 float roughness, float anisotropy)
{
    float aspect = sqrt(1.0 - 0.9 * anisotropy);
    float ax = max(0.001, roughness * roughness / aspect);
    float ay = max(0.001, roughness * roughness * aspect);
    float3 B = cross(N, T);
    float XoH = dot(T, H);
    float YoH = dot(B, H);
    float NoH = max(dot(N, H), 0.0);
    float d = XoH * XoH / (ax * ax) + YoH * YoH / (ay * ay) + NoH * NoH;
    return rcp(PI * ax * ay * d * d);
}

// ── Smith-Schlick-GGX Geometry ───────────────
float GeometrySmithSchlickGGX(float NoV, float NoL, float roughness)
{
    float r1 = roughness + 1.0;
    float k = max((r1 * r1) / 8.0, 0.0001);
    float smithV = NoV * rcp(NoV * (1.0 - k) + k);
    float smithL = NoL * rcp(NoL * (1.0 - k) + k);
    return smithV * smithL;
}

// ── Sheen ────────────────────────────────────
float CharlieD(float sheenRoughness, float NoH)
{
    sheenRoughness = max(sheenRoughness, 0.07);
    float invR = rcp(sheenRoughness);
    float cos2h = NoH * NoH;
    float sin2h = max(1.0 - cos2h, 0.0078125);
    return (2.0 + invR) * pow(sin2h, invR * 0.5) / (2.0 * PI);
}

float ClothV(float NoV, float NoL)
{
    return rcp(4.0 * max(NoL + NoV - NoL * NoV, 0.1));
}

float3 EvaluateSheen(float3 sheenColor, float sheenIntensity,
                     float sheenRoughness,
                     float NoH, float NoV, float NoL)
{
    if (sheenIntensity <= 0.0)
        return 0.0;
    float D = CharlieD(sheenRoughness, NoH);
    float V = ClothV(NoV, NoL);
    float DV = min(D * V, 4.0);
    return sheenColor * sheenIntensity * DV;
}

float SheenDirectionalAlbedo(float sheenIntensity, float sheenRoughness)
{
    return sheenIntensity * saturate(0.15 * sheenRoughness + 0.05);
}

// ── Clearcoat ────────────────────────────────
float3 EvaluateClearcoat(float clearcoat, float smoothness,
                         float NoH, float HoL, float NoV, float NoL)
{
    if (clearcoat <= 0.0)
        return 0.0;

    float alpha = lerp(0.1, 0.001, smoothness);
    float alphaSq = alpha * alpha;

    float d = (alphaSq - 1.0) * rcp(PI * log(alphaSq) * (1.0 + (alphaSq - 1.0) * NoH * NoH));

    float f = 0.04 + 0.96 * pow(saturate(1.0 - HoL), 5.0);

    float ccRoughSq = 0.25 * 0.25;
    float gv = 2.0 * rcp(1.0 + sqrt(ccRoughSq + (1.0 - ccRoughSq) * NoV * NoV));
    float gl = 2.0 * rcp(1.0 + sqrt(ccRoughSq + (1.0 - ccRoughSq) * NoL * NoL));

    return (float3)(0.25 * clearcoat * d * f * gv * gl);
}

// ── Cook-Torrance Specular ───────────────────
float3 EvaluateSpecular(float3 N, float3 V, float3 L, float3 T,
                        float3 F0val, float roughness, float anisotropy)
{
    float3 H = normalize(V + L);
    float NoL = saturate(dot(N, L));
    float NoV = max(dot(N, V), 0.0001);
    float VoH = saturate(dot(V, H));

    float D = DistributionGGXAnisotropic(N, T, H, roughness, anisotropy);
    float G = GeometrySmithSchlickGGX(NoV, NoL, roughness);
    float3 F = FresnelSchlick(VoH, F0val);
    return D * G * F * rcp(max(4.0 * NoV * NoL, 0.0001));
}

// ── Subsurface Transmission ──────────────────
float3 EvaluateTransmission(
    float3 N, float3 V, float3 L,
    float3 lightColor,
    float subsurface, float3 subsurfaceColor,
    float distortion, float power)
{
    if (subsurface <= 0.0)
        return 0.0;

    float3 transLight = normalize(L + N * distortion);
    float VdotNegTL = pow(saturate(dot(V, -transLight)), power);

    return subsurface * subsurfaceColor * VdotNegTL * lightColor;
}

// ══════════════════════════════════════════════
// PROCEDURAL KNIT FUNCTIONS
// ══════════════════════════════════════════════

void FabricHash_uint(uint2 v, out uint o)
{
    v.y ^= 1103515245U;
    v.x += v.y;
    v.x *= v.y;
    v.x ^= v.x >> 5u;
    v.x *= 0x27d4eb2du;
    o = v.x;
}

void FabricHash_float(float2 i, out float o)
{
    uint r;
    uint2 v = (uint2)(int2)round(i);
    FabricHash_uint(v, r);
    o = (r >> 8) * (1.0 / float(0x00ffffff));
}

float FabricNoiseValue(float2 uv)
{
    float2 i = floor(uv);
    float2 f = frac(uv);
    f = f * f * (3.0 - 2.0 * f);

    float r0;
    FabricHash_float(i + float2(0, 0), r0);
    float r1;
    FabricHash_float(i + float2(1, 0), r1);
    float r2;
    FabricHash_float(i + float2(0, 1), r2);
    float r3;
    FabricHash_float(i + float2(1, 1), r3);

    return lerp(lerp(r0, r1, f.x),
                lerp(r2, r3, f.x), f.y);
}

float FabricNoise2Oct(float2 UV, float Scale)
{
    float noise = 0.0;
    noise += FabricNoiseValue(UV * (Scale * 0.25)) * 0.667;
    noise += FabricNoiseValue(UV * (Scale * 0.5)) * 0.333;
    return noise;
}

float InterleavedGradientNoise(float2 screenPos)
{
    float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    return frac(magic.z * frac(dot(screenPos, magic.xy)));
}

// ============================================================
// Knit pattern hash utilities
// ============================================================
float KnitHash(float2 p)
{
    p = frac(p * float2(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return frac(p.x * p.y);
}

float2 KnitHash2(float2 p)
{
    return float2(KnitHash(p), KnitHash(p + 127.231));
}

// ============================================================
// Superelliptical Knit Loop SDF
// ============================================================
// Returns all knit pattern data for a single fragment.
//
// Gap shape transitions from diamond (n=1) through rounded-diamond
// (n≈1.5, the sweet-spot for knit) to ellipse (n=2).
// The two-arc "lens" shape of real knit gaps lives at roughly n=1.3–1.6.
// ============================================================

struct KnitResult
{
    float gapMask;      // 1 inside gap opening, 0 on thread
    float threadMask;   // 1 on thread, 0 in gap (= 1 - gapMask)
    float threadDist;   // distance from gap boundary into thread
    float profile;      // thread cross-section height (1 at gap edge → 0 deep in thread)
    float3 bumpNormal;  // tangent-space normal from thread cross-section
    float2 threadDir;   // tangent direction along the thread arc
    float2 gapGradient; // unit gradient pointing away from gap center
    float fade;         // SDF detail factor (1 = full SDF, 0 = far-field only)
    float2 cellID;      // integer cell identifier (for per-stitch randomisation)
    float cellsPerPx;   // pixel footprint in grid cells (for fragment effects)
};

KnitResult EvaluateKnitSDF(
    float2 uv,
    float numberOfLoops,
    float uvTiling,
    float loopAspect,
    float openingSize,
    float openingSoftness,
    float gapShapePower,
    float gapWidthRatio,
    float threadWidth,
    float jitterAmount,
    float bumpStrength,
    float2 screenPos)
{
    KnitResult o = (KnitResult)0;

    // -------------------------------------------------------
    // 1.  GRID
    // -------------------------------------------------------
    float loopsAcross = numberOfLoops * uvTiling;
    float2 gridScale = float2(loopsAcross, loopsAcross / loopAspect);
    float2 gridUV = uv * gridScale;

    // -------------------------------------------------------
    // 2.  PIXEL FOOTPRINT  (anti-moiré core)
    // -------------------------------------------------------
    // Measure how many grid cells span one screen pixel.
    float2 gx = ddx(gridUV);
    float2 gy = ddy(gridUV);
    float cellsPerPx = max(length(float2(gx.x, gy.x)),
                           length(float2(gx.y, gy.y)));
    // Toggle: when anti-moiré is off, zero out cellsPerPx so all
    // distance-dependent effects (fade, bumpFade, jitter, yarn tilt,
    // roughness broadening) naturally evaluate to their near-field values.
    cellsPerPx = _UseAntiMoire > 0 ? cellsPerPx : 0;
    o.cellsPerPx = cellsPerPx;

    // SDF detail fade:
    //   < 0.25 cells/px →  fully resolved, show SDF
    //   > 0.55 cells/px →  past Nyquist → far-field only
    o.fade = 1.0 - smoothstep(0.25, 0.55, cellsPerPx);

    // Bump fades faster — specular shimmer is far more
    // perceptible than colour-level moiré.
    float bumpFade = 1.0 - smoothstep(0.15, 0.45, cellsPerPx);

    // -------------------------------------------------------
    // 3.  STOCHASTIC JITTER  (transition-zone noise)
    // -------------------------------------------------------
    // Per-pixel noise offset in grid space breaks the coherent
    // periodic sampling that causes moiré.  Uses a grid-anchored
    // hash so the jitter sticks to the fabric (no screen crawl).
    float ign = KnitHash(floor(gridUV) + 53.7);
    float stochActivation = smoothstep(0.15, 0.5, cellsPerPx);
    gridUV += (ign - 0.5) * stochActivation * cellsPerPx * 0.5;

    // Brick offset on odd rows (half-cell shift)
    float rowIdx = floor(gridUV.y);
    float brick = fmod(abs(rowIdx), 2.0) * 0.5;
    gridUV.x += brick;

    // Cell ID & local coords  [-0.5 .. 0.5]
    o.cellID = floor(gridUV);
    float2 local = frac(gridUV) - 0.5;

    // -------------------------------------------------------
    // 4.  ARTISTIC JITTER  (per-cell opening position)
    // -------------------------------------------------------
    float2 jit = (KnitHash2(o.cellID) - 0.5) * 2.0 * jitterAmount;
    local -= jit;

    // -------------------------------------------------------
    // 5.  SUPERELLIPTICAL GAP SDF
    // -------------------------------------------------------
    float gapH = max(openingSize, 0.001);
    float gapW = max(openingSize * gapWidthRatio, 0.001);
    float n = gapShapePower;

    float px = abs(local.x) / gapW;
    float py = abs(local.y) / gapH;

    float se = pow(pow(px, n) + pow(py, n), 1.0 / n);

    float minR = min(gapW, gapH);
    float gapDist = (1.0 - se) * minR;

    // -------------------------------------------------------
    // 6.  MASKS  (adaptive softness for anti-aliasing)
    // -------------------------------------------------------
    // Two modes, toggled by _UseAnalyticSoftness:
    //   0 — cell-footprint:   cellsPerPx * 0.45  (original, global estimate)
    //   1 — analytic fwidth:  fwidth(gapDist) * 0.5  (exact screen-space
    //                         derivative of the SDF, reacts to perspective,
    //                         oblique angles and UV stretch automatically)
    // fwidth is kept soft with a cellsPerPx floor so sub-pixel fade still fires.
    float softCell  = cellsPerPx * 0.45;
    float softFwidh = fwidth(gapDist) * 0.5;
    float adaptiveSoft = max(openingSoftness,
                             lerp(softCell, max(softFwidh, cellsPerPx * 0.05), _UseAnalyticSoftness));
    o.gapMask = smoothstep(-adaptiveSoft, adaptiveSoft, gapDist);
    o.threadMask = 1.0 - o.gapMask;
    o.threadDist = abs(gapDist);

    // Thread profile also widens at distance
    float adaptiveTW = max(threadWidth, cellsPerPx * 0.35);
    o.profile = saturate(1.0 - o.threadDist / adaptiveTW);

    // -------------------------------------------------------
    // 7.  GRADIENT  (perpendicular to gap boundary)
    // -------------------------------------------------------
    float nm1 = max(n - 1.0, 0.01);
    float2 seGrad = float2(
        sign(local.x) * pow(max(px, 1e-6), nm1) / gapW,
        sign(local.y) * pow(max(py, 1e-6), nm1) / gapH);
    float gl = length(seGrad);
    seGrad = (gl > 0.001) ? (seGrad / gl) : float2(0, 1);

    o.gapGradient = seGrad;
    o.threadDir = float2(-seGrad.y, seGrad.x);

    // -------------------------------------------------------
    // 8.  FREQUENCY-CLAMPED BUMP NORMAL
    // -------------------------------------------------------
    float bumpAmt = o.profile * bumpStrength * o.threadMask * bumpFade;
    o.bumpNormal = normalize(float3(-seGrad * bumpAmt, 1.0));

    return o;
}
#endif