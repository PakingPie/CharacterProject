#ifndef FABRIC_PBR_KNIT_SURFACE_INCLUDED
#define FABRIC_PBR_KNIT_SURFACE_INCLUDED

// ─────────────────────────────────────────────────────────────────────────────
// FabricPBR_KnitSurface.hlsl
// Encapsulates the full procedural-knit surface integration pass:
//   stretch detection → SDF evaluation → far-field noise → normal / albedo /
//   roughness modification.
//
// Returns a KnitSurfaceResult struct; the caller unpacks what it needs.
//
// Requires (included before this file in the shader pass):
//   FabricPBR_Common.hlsl                      — CBUFFER uniforms
//   FabricPBR_ProceduralPattern_Utilities.hlsl — EvaluateKnitSDF, noise helpers
// ─────────────────────────────────────────────────────────────────────────────

struct KnitSurfaceResult
{
    float  knitThreadMask;  // 1 = full thread, 0 = gap
    float  knitEdgeMask;    // Gaussian peak at gap–thread boundary (specular boost)
    float  stretchAmount;   // 0–1 normalised UV stretch
    float  knitAvgThread;   // Average thread coverage (moire fade target)
    half3  normalTS;        // Tangent-space normal after knit bump
    float3 albedo;          // Albedo after thread darkening
    float  roughness;       // Roughness after knit variation
    float2 threadDir;       // Thread tangent direction (blended to (1,0) at distance)
};

KnitSurfaceResult EvaluateKnitSurface(
    float2 uv,
    float3 positionWS,
    float4 positionCS,
    float4 vertexColor,
    half3  normalTS,
    float3 albedo,
    float  roughness)
{
    KnitSurfaceResult r;
    r.knitThreadMask = 1.0;
    r.knitEdgeMask   = 0.0;
    r.stretchAmount  = 0.0;
    r.knitAvgThread  = 1.0;
    r.normalTS       = normalTS;
    r.albedo         = albedo;
    r.roughness      = roughness;
    r.threadDir      = float2(1, 0);

    if (_UseProceduralKnit <= 0)
        return r;

    // ── Stretch computation ──────────────
    float3 dPdx_ws = ddx(positionWS);
    float3 dPdy_ws = ddy(positionWS);
    float  worldPixArea = length(cross(dPdx_ws, dPdy_ws));

    float2 dUVdx = ddx(uv);
    float2 dUVdy = ddy(uv);
    float  uvPixArea = abs(dUVdx.x * dUVdy.y - dUVdx.y * dUVdy.x);
    float  worldPerUV = sqrt(worldPixArea / max(uvPixArea, 1e-10));

    if (_UseStretchFromVertexG > 0)
    {
        r.stretchAmount = vertexColor.g;
    }
    else
    {
        float stretchRatio = worldPerUV / max(_StretchReference, 1e-6);
        r.stretchAmount = saturate((stretchRatio - 1.0) * _StretchTransparency);
    }

    float stretchMod = lerp(1.0, 1.0 + _StretchOpeningGrow, r.stretchAmount);
    float stretchedOpening = _OpeningSize * stretchMod;

    // ── Average thread coverage (moire fade target) ──
    float gapW = stretchedOpening * _GapWidthRatio;
    float gapH = stretchedOpening;
    r.knitAvgThread = saturate(1.0 - PI * gapW * gapH);

    // ── Evaluate the superelliptical knit SDF ──
    KnitResult knit = EvaluateKnitSDF(
        uv,
        _NumberOfLoops,
        _KnitUVTiling,
        _LoopAspect,
        stretchedOpening,
        _OpeningSoftness,
        _GapShapePower,
        _GapWidthRatio,
        _ThreadWidth,
        _KnitJitter,
        _KnitNormalStrength,
        positionCS.xy
    );

    // ── Thread direction (blended to default at distance) ──
    r.threadDir = lerp(float2(1, 0), knit.threadDir, knit.fade);

    // ── Far-field fabric noise ────────────
    // When the SDF pattern fades (below Nyquist), replace it
    // with smooth noise-based variation that preserves fabric
    // character.  This is the procedural equivalent of what
    // texture mipmapping provides — the pattern blurs rather
    // than vanishing to flat plastic.
    float farField = 1.0 - knit.fade;   // 0 close, 1 far
    // Use multiple octaves at low frequency (safe from aliasing)
    float2 farUV   = uv * 20.0;
    float fnoise1  = FabricNoiseValue(farUV);
    float fnoise2  = FabricNoiseValue(farUV * 1.7 + 31.5);
    // Medium-frequency octave for more fabric texture
    float fnoise3  = FabricNoiseValue(farUV * 4.3 + 17.2);

    // ── Thread mask ──────────────────────
    // SDF detail at close range, noise-modulated average at distance.
    // Stronger noise variation (±15%) so fabric character is clear.
    float noiseVar = ((fnoise1 - 0.5) * 0.15
                    + (fnoise3 - 0.5) * 0.08) * farField;
    r.knitThreadMask = lerp(r.knitAvgThread + noiseVar,
                             knit.threadMask, knit.fade);
    r.knitThreadMask = saturate(r.knitThreadMask);

    // Edge mask: Gaussian peak at gap boundary for specular
    float edgeSigma = max(_OpeningSoftness * 0.7, 0.001);
    r.knitEdgeMask = exp(-pow(knit.threadDist / edgeSigma, 2.0))
                    * knit.fade;

    // ── Bump normal ──────────────────────
    // SDF bump (already faded internally) + far-field fabric bump
    r.normalTS.xy += knit.bumpNormal.xy;
    float farBump = 0.15 * _KnitNormalStrength * farField;
    r.normalTS.x += (fnoise1 - 0.5) * farBump;
    r.normalTS.y += (fnoise2 - 0.5) * farBump;
    r.normalTS.x += (fnoise3 - 0.5) * farBump * 0.5;

    // ── Yarn-loop micro-NDF: stochastic normal tilt ──────────
    // When cellsPerPx > 0 the resolved per-thread bump normal
    // starts fading (bumpFade). What should replace it is the
    // statistical distribution of yarn-loop surface normals —
    // which point in ALL tangent directions around the loop arc.
    // Model this as a per-pixel random tilt whose magnitude
    // grows with cellsPerPx: breaks the cylindrical macro-normal
    // pattern that causes the vertical GGX stripe.
    // Use cellID-based hash so the tilt sticks to each stitch
    // (no screen-space crawl).
    float yarnStochFade = smoothstep(0.05, 0.4, knit.cellsPerPx)
                          * _FabricMicroNDFStrength;
    float yarnAngle = KnitHash(knit.cellID + 17.3) * 6.2831853;
    float yarnTilt  = yarnStochFade * knit.cellsPerPx * 0.3;
    r.normalTS.x += cos(yarnAngle) * yarnTilt;
    r.normalTS.y += sin(yarnAngle) * yarnTilt;
    r.normalTS = normalize(r.normalTS);

    // ── Thread darkening ─────────────────
    float darkening = (1.0 - knit.profile) * knit.threadMask
                      * _ThreadDarken;
    r.albedo *= 1.0 - darkening * knit.fade;
    // Far-field subtle color variation
    r.albedo *= 1.0 - (1.0 - fnoise1) * 0.04
              * _ThreadDarken * farField;

    // ── Roughness variation ──────────────
    float cellRand = KnitHash(knit.cellID);
    float rVar = (cellRand - 0.5) * 2.0 * _KnitRoughnessVar;

    // Fiber-scale noise (subtle high-freq variation per thread)
    float2 fiberUV = (frac(uv * _NumberOfLoops * _KnitUVTiling) - 0.5)
    * _KnitNoiseScale + knit.cellID * 1.7;
    float  fiberRnd = KnitHash(floor(fiberUV * 3.0));
    rVar += (fiberRnd - 0.5) * _KnitRoughnessVar * 0.5;

    r.roughness += rVar * knit.threadMask * knit.fade;
    // Far-field roughness variation (fabric shimmer at distance)
    r.roughness += (fnoise1 - 0.5) * _KnitRoughnessVar
                 * 0.3 * farField;
    r.roughness = clamp(r.roughness, 0.045, 1.0);

    // ── Yarn-loop effective roughness ────────────────────────
    // Hardware mip filtering widens the effective BRDF as a
    // texture pattern goes sub-pixel (it integrates the NDF).
    // We replicate that here: roughness grows with cellsPerPx
    // so the GGX lobe broadens proportionally when yarn loops
    // are smaller than a pixel.
    r.roughness = saturate(r.roughness + knit.cellsPerPx * 0.35
                             * _FabricMicroNDFStrength);

    return r;
}

#endif // FABRIC_PBR_KNIT_SURFACE_INCLUDED
