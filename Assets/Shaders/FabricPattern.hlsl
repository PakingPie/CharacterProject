#ifndef CUSTOM_FABRIC_PATTERN_INCLUDE
#define CUSTOM_FABRIC_PATTERN_INCLUDE
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
    float fade;         // moire suppression factor (1 = show pattern, 0 = hide)
    float2 cellID;      // integer cell identifier (for per-stitch randomisation)
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
    float fadeStart,
    float fadeEnd)
{
    KnitResult o = (KnitResult)0;

    // -------------------------------------------------------
    // 1.  GRID
    // -------------------------------------------------------
    float loopsAcross = numberOfLoops * uvTiling;

    // Cell grid — each cell holds one knit loop.
    // loopAspect = cell height / cell width.
    float2 gridScale = float2(loopsAcross, loopsAcross / loopAspect);
    float2 gridUV = uv * gridScale;

    // Brick offset on odd rows (half-cell shift)
    float rowIdx = floor(gridUV.y);
    float brick = fmod(abs(rowIdx), 2.0) * 0.5;
    gridUV.x += brick;

    // Cell ID & local coords  [-0.5 .. 0.5]
    o.cellID = floor(gridUV);
    float2 local = frac(gridUV) - 0.5;

    // -------------------------------------------------------
    // 2.  MOIRE FADE
    // -------------------------------------------------------
    float2 gx = ddx(gridUV);
    float2 gy = ddy(gridUV);
    float cellsPerPx = max(length(float2(gx.x, gy.x)),
                           length(float2(gx.y, gy.y)));
    o.fade = 1.0 - smoothstep(fadeStart, fadeEnd, cellsPerPx);

    // -------------------------------------------------------
    // 3.  JITTER
    // -------------------------------------------------------
    float2 jit = (KnitHash2(o.cellID) - 0.5) * 2.0 * jitterAmount;
    local -= jit;

    // -------------------------------------------------------
    // 4.  SUPERELLIPTICAL GAP SDF
    // -------------------------------------------------------
    float gapH = max(openingSize, 0.001);                 // vertical semi-axis
    float gapW = max(openingSize * gapWidthRatio, 0.001); // horizontal semi-axis
    float n = gapShapePower;

    // Normalised position inside the gap shape
    float px = abs(local.x) / gapW;
    float py = abs(local.y) / gapH;

    // Superellipse value:  0 at centre,  1 on boundary,  >1 outside
    float se = pow(pow(px, n) + pow(py, n), 1.0 / n);

    // Approximate signed distance  (positive = inside gap)
    float minR = min(gapW, gapH);
    float gapDist = (1.0 - se) * minR;

    // -------------------------------------------------------
    // 5.  MASKS
    // -------------------------------------------------------
    o.gapMask = smoothstep(-openingSoftness, openingSoftness, gapDist);
    o.threadMask = 1.0 - o.gapMask;
    o.threadDist = abs(gapDist);

    // Thread cross-section profile  (1 = at gap edge, 0 = deep in thread)
    float tw = max(threadWidth, 0.001);
    o.profile = saturate(1.0 - o.threadDist / tw);

    // -------------------------------------------------------
    // 6.  GRADIENT  (perpendicular to gap boundary)
    // -------------------------------------------------------
    //  ∇ f  where f = ( |x/a|^n + |y/b|^n )^(1/n)
    float nm1 = max(n - 1.0, 0.01);
    float2 seGrad = float2(
        sign(local.x) * pow(max(px, 1e-6), nm1) / gapW,
        sign(local.y) * pow(max(py, 1e-6), nm1) / gapH);
    float gl = length(seGrad);
    seGrad = (gl > 0.001) ? (seGrad / gl) : float2(0, 1);

    o.gapGradient = seGrad;
    o.threadDir = float2(-seGrad.y, seGrad.x); // tangent along thread arc

    // -------------------------------------------------------
    // 7.  BUMP NORMAL
    // -------------------------------------------------------
    // Round-yarn slope:  steep at gap edge, flat deep in thread
    //   h(d) = sqrt(r² - d²)  =>  dh/dd = -d / sqrt(r² - d²)
    // We use the profile for a softer approximation.

    float bumpAmt = o.profile * bumpStrength * o.threadMask * o.fade;

    o.bumpNormal = normalize(float3(-seGrad * bumpAmt, 1.0));

    return o;
}

#endif