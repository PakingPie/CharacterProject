# Anti-Moiré & Specular AA Plan — FabricPBR_ProceduralPattern

## 1. Problem Statement

The procedural knit pattern produces visible moiré artifacts at close-to-medium
viewing distances.  The camera is placed right on the model and the pattern is
still visibly aliasing.

### 1.1  Screenshot Observations (current state)

| Region | What's visible |
|--------|----------------|
| Close-up right leg (face-on) | Individual cells resolved, but specular highlights sparkle/shimmer between pixels |
| Medium-distance right leg (curved) | Clear **moiré banding** — dark/light interference bands running diagonally across the surface |
| Far left leg | Same moiré banding, denser |
| Specular highlights | Dotted, noisy pattern instead of smooth sheen |

### 1.2  Root Causes Identified

**Root Cause A — Albedo-level moiré (dominant artifact):**
The `threadMask` oscillates between 0 (gap) and 1 (thread) at the pixel grid
frequency.  `threadDarken` amplifies this into a high-contrast albedo pattern.
The existing `fade` mechanism lerps `threadMask → knitAvgThread` at distance,
but the current **material** fade band is too wide:

- `_KnitFadeStart = 0.097 cells/px` → SDF shows at full detail only below 0.097 cpp
- `_KnitFadeEnd   = 0.97  cells/px` → completely faded only above 0.97 cpp

With a 640×1280 cell grid on a ~800px-tall model, face-on `cellsPerPx ≈ 1.6`.
That means **most of the surface lives inside the transition band**, where the
SDF is partially visible but under-sampled — the exact regime that produces moiré.

**Root Cause B — Previous specular AA fix was measuring the wrong signal:**
The `bumpVariance = max(dot(ddx(normalTS.xy), ...), ...)` approach measures
the derivative of the **post-fade** bump normal.  The bump is already multiplied
by `bumpFade` inside `EvaluateKnitSDF`, so at distance the bump is near-zero,
its derivatives are near-zero, and `bumpVariance ≈ 0`.  The fix is inert
precisely in the regime where aliasing is worst.

**Root Cause C — Clearcoat and strip specular still alias:**
Even if we fix B, the clearcoat (roughness=0, mirror-sharp) and strip specular
(roughness=0.1, intensity=3) were never covered by the old `cellsPerPx * 0.35`
broadening.  Any residual per-pixel normal variation — even from mesh
interpolation — drives specular sparkle through these sharp lobes.

---

## 2. Proposed Fix (three layers)

### Fix 1 — Restore and extend `cellsPerPx`-based roughness broadening

**Why:** `cellsPerPx` is the correct, robust metric for sub-pixel feature density.
It's computed from `ddx/ddy` of `gridUV` (the pattern's own frequency space), not
from the post-fade bump.  It correctly tracks viewing angle, perspective, and UV
density without being attenuated by the fade mechanism.

**What:**
- **Restore** `cellsPerPx * factor * _FabricMicroNDFStrength` broadening for the
  main GGX roughness in `FabricPBR_KnitSurface.hlsl` (revert variance-only approach,
  keep variance as supplement).
- **Extend** `cellsPerPx`-based broadening to:
  - Strip specular T and B roughness axes
  - Clearcoat roughness
- **Keep** the `bumpVariance` computation but use it as a **supplement** for close-range
  oblique-angle specular AA where `cellsPerPx` is low but normals still vary rapidly.

**Formula for each specular layer:**
```hlsl
float specAA = cellsPerPx * 0.35 * _FabricMicroNDFStrength;
float varAA  = bumpVariance * _FabricMicroNDFStrength;
roughness = sqrt(roughness*roughness + specAA*specAA + varAA);
```

**Files:** `FabricPBR_KnitSurface.hlsl` (GGX), `FabricPBR_ProceduralPattern.shader` (strip, clearcoat)

**Requires `cellsPerPx` exported from KnitSurfaceResult** (add field).

### Fix 2 — Keep clearcoat on geometric normal

*Already implemented and correct.*  Nylon clearcoat is a smooth polymer layer that
bridges across thread bumps.  Using the interpolated mesh normal (`geomNormalWS`)
prevents the sharp clearcoat lobe from tracking per-thread perturbations.

**Files:** `FabricPBR_ProceduralPattern.shader` (already done, keep as-is)

### Fix 3 — Compute `bumpVariance` from the **pre-fade** bump signal

The current `ddx/ddy(normalTS.xy)` measures the post-fade signal.  Instead:

**Option A (analytical):** Estimate variance from known bump amplitude and cell frequency:
```hlsl
// The bump amplitude before fade is: profile * bumpStrength * threadMask
// When cells are sub-pixel, the RMS tilt across the pixel is proportional
// to bumpStrength * sqrt(cellsPerPx).
float analyticalVar = _KnitNormalStrength * _KnitNormalStrength
                    * saturate(cellsPerPx);
```
This is cheap, robust, and doesn't depend on the bump fade at all.

**Option B (measure pre-fade):** Compute `ddx/ddy` of the bump **before** applying
`bumpFade` in `EvaluateKnitSDF`.  This requires restructuring the SDF function,
which touches more code for marginal benefit over Option A.

**Recommended: Option A.** It's simpler, cheaper, and produces a monotonically
increasing signal as cells shrink — exactly the behavior we want.

---

## 3. Files Modified

| File | Changes |
|------|---------|
| `FabricPBR_KnitSurface.hlsl` | Add `cellsPerPx` to `KnitSurfaceResult`; restore cellsPerPx broadening for GGX; replace ddx/ddy variance with analytical estimate |
| `FabricPBR_ProceduralPattern.shader` | Use `cellsPerPx` + analytical variance to broaden strip and clearcoat roughness; keep geom normal for clearcoat (already done) |
| `FabricPBR_ProceduralPattern_Utilities.hlsl` | No changes needed (cellsPerPx already computed and exported in KnitResult) |
| `FabricPBR_Common.hlsl` | No changes needed |

## 4. What Stays Unchanged

- SDF evaluation & superelliptical gap model
- Stretch / transparency / denier pipeline
- Thread mask fade mechanism (`lerp(avg, sdf, fade)`)
- Brick-offset grid, cell hashing, jitter
- Shadow / depth passes (no specular evaluation)
- The `_KnitFadeStart` / `_KnitFadeEnd` **shader property** defaults (already sensible at 0.25/0.55)

## 5. Material Parameter Recommendation

The material's fade band (`_KnitFadeStart=0.097`, `_KnitFadeEnd=0.97`) is the
single biggest contributor to the visible moiré.  With a 640×1280 grid at 1080p,
Nyquist is at ~0.5 cells/px.  Recommended material values:

- `_KnitFadeStart`: **0.20–0.30** (start fading when approaching 3–5 px per cell)
- `_KnitFadeEnd`:   **0.50–0.65** (fully faded before Nyquist)

This is a material-level change, not a code change.  The shader code improvements
above make the transition smoother so the exact values become less critical, but
the material should still have a tight band to avoid the mushy transition zone.

## 6. Risk Assessment

| Change | Risk | Reversibility |
|--------|------|---------------|
| cellsPerPx broadening for GGX | Low — restores proven mechanism | Trivial revert |
| cellsPerPx broadening for strip/CC | Low — same principle, new scope | Trivial revert |
| Analytical variance estimate | Low — simple formula, well-defined | Trivial revert |
| Geometric normal for clearcoat | Low — already implemented | Already in place |

No new shader properties.  No CBUFFER changes.  SRP Batcher compatibility preserved.
