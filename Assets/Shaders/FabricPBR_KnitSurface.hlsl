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

    // ── Thread mask ──────────────────────
    // SDF detail at close range, clean analytic average at distance.
    // No far-field noise: mipmapping converges to a flat average, so
    // the procedural equivalent is simply knitAvgThread.
    r.knitThreadMask = lerp(r.knitAvgThread, knit.threadMask, knit.fade);
    r.knitThreadMask = saturate(r.knitThreadMask);

    // Edge mask: Gaussian peak at gap boundary for specular
    float edgeSigma = max(_OpeningSoftness * 0.7, 0.001);
    r.knitEdgeMask = exp(-pow(knit.threadDist / edgeSigma, 2.0))
                    * knit.fade;

    // ── Bump normal ──────────────────────
    // SDF bump only (already faded internally via bumpFade).
    // No far-field noise bump — at distance the surface should be smooth.
    r.normalTS.xy += knit.bumpNormal.xy;
    r.normalTS = normalize(r.normalTS);

    // ── Thread darkening ─────────────────
    float darkening = (1.0 - knit.profile) * knit.threadMask
                      * _ThreadDarken;
    r.albedo *= 1.0 - darkening * knit.fade;

    // ── Roughness variation ──────────────
    // Near-field only: per-cell and fiber-scale variation, gated by fade.
    float cellRand = KnitHash(knit.cellID);
    float rVar = (cellRand - 0.5) * 2.0 * _KnitRoughnessVar;

    float2 fiberUV = (frac(uv * _NumberOfLoops * _KnitUVTiling) - 0.5)
    * _KnitNoiseScale + knit.cellID * 1.7;
    float  fiberRnd = KnitHash(floor(fiberUV * 3.0));
    rVar += (fiberRnd - 0.5) * _KnitRoughnessVar * 0.5;

    r.roughness += rVar * knit.threadMask * knit.fade;
    r.roughness = clamp(r.roughness, 0.045, 1.0);

    // ── Yarn-loop effective roughness ────────────────────────
    // Physically correct: as yarn loops go sub-pixel, the effective
    // BRDF widens (integrating over loop normals).  This broadens
    // the GGX lobe proportionally — no noise injection needed.
    r.roughness = saturate(r.roughness + knit.cellsPerPx * 0.35
                             * _FabricMicroNDFStrength);

    return r;
}

#endif // FABRIC_PBR_KNIT_SURFACE_INCLUDED
