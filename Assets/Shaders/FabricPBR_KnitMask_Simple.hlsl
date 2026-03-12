// ─────────────────────────────────────────────────────────────────────────────
// FabricPBR_KnitMask_Simple.hlsl
// Shared simplified knit mask evaluation for ShadowCaster and DepthOnly passes.
// Requires FabricPBR_Common.hlsl (CBUFFER) to be included first.
// ─────────────────────────────────────────────────────────────────────────────
#ifndef FABRIC_PBR_KNITMASK_SIMPLE_INCLUDED
#define FABRIC_PBR_KNITMASK_SIMPLE_INCLUDED

float SimpleKnitHash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float ComputeSimpleStretchAmount(float2 uv, float3 positionWS, float4 vertexColor)
{
    if (_UseStretchFromVertexG > 0)
        return saturate(vertexColor.g);

    float3 dPdx_ws = ddx(positionWS);
    float3 dPdy_ws = ddy(positionWS);
    float  worldPixArea = length(cross(dPdx_ws, dPdy_ws));

    float2 dUVdx = ddx(uv);
    float2 dUVdy = ddy(uv);
    float  uvPixArea = abs(dUVdx.x * dUVdy.y - dUVdx.y * dUVdy.x);
    float  worldPerUV = sqrt(worldPixArea / max(uvPixArea, 1e-10));

    float stretchRatio = worldPerUV / max(_StretchReference, 1e-6);
    return saturate((stretchRatio - 1.0) * _StretchTransparency);
}

float EvaluateSimpleKnitMask(float2 uv, float stretchAmount, float2 screenPos)
{
    float stretchMod = lerp(1.0, 1.0 + _StretchOpeningGrow, stretchAmount);
    float stretchedOpening = _OpeningSize * stretchMod;

    float loopsAcross = max(_NumberOfLoops * _KnitUVTiling, 1e-4);
    float2 gridScale = float2(loopsAcross, loopsAcross / max(_LoopAspect, 0.001));
    float2 gridUV = uv * gridScale;

    float2 gx = ddx(gridUV);
    float2 gy = ddy(gridUV);
    float cellsPerPx = max(length(float2(gx.x, gy.x)),
                           length(float2(gx.y, gy.y)));
    float fade = 1.0 - smoothstep(0.3, 1.0, cellsPerPx);

    float ign = frac(52.9829189 * frac(dot(screenPos, float2(0.06711056, 0.00583715))));
    float stochActivation = smoothstep(0.15, 0.6, cellsPerPx);
    gridUV += (ign - 0.5) * stochActivation * cellsPerPx * 0.5;

    float rowIdx = floor(gridUV.y);
    gridUV.x += fmod(abs(rowIdx), 2.0) * 0.5;

    float2 cellID = floor(gridUV);
    float2 local = frac(gridUV) - 0.5;
    float2 jitter = (float2(
        SimpleKnitHash(cellID),
        SimpleKnitHash(cellID + 127.231)) - 0.5) * 2.0 * _KnitJitter;
    local -= jitter;

    float gapH = max(stretchedOpening, 0.001);
    float gapW = max(stretchedOpening * _GapWidthRatio, 0.001);
    float n = _GapShapePower;

    float px = abs(local.x) / gapW;
    float py = abs(local.y) / gapH;
    float se = pow(pow(px, n) + pow(py, n), 1.0 / n);
    float minR = min(gapW, gapH);
    float gapDist = (1.0 - se) * minR;

    float softCell = cellsPerPx * 0.45;
    float softFwidth = fwidth(gapDist) * 0.5;
    float adaptiveSoft = max(
        _OpeningSoftness,
        lerp(softCell, max(softFwidth, cellsPerPx * 0.05), _UseAnalyticSoftness));

    float threadMask = 1.0 - smoothstep(-adaptiveSoft, adaptiveSoft, gapDist);
    float avgThreadCoverage = saturate(1.0 - PI * gapW * gapH);
    return saturate(lerp(avgThreadCoverage, threadMask, fade));
}

#endif
