# Stocking.shader Strip Specular — Analysis & Integration Plan

## 1  How Stocking.shader Produces the Strip Specular

### 1.1  Architecture overview

Stocking.shader uses `UniversalFragmentPBR` as the base and then **additively layers** four custom effects on top of the PBR result:

| Layer | Function | Purpose |
|-------|----------|---------|
| Charlie Sheen | `CharlieSheen(NdotH, roughness)` | Soft fabric sheen; brightens at grazing |
| SSS | `SubsurfaceScattering(...)` | Skin colour bleeding through fabric |
| **Anisotropic Specular** | **`AnisotropicSpecular(H, T, B, N, roughness, anisotropy)`** | **The strip highlight** |
| Rim Light | `pow(1-NdotV, power)` | Silhouette glow |

The strip specular comes exclusively from the **Ward anisotropic model** (layer 3).

### 1.2  Ward model — the core of the strip highlight

```hlsl
half AnisotropicSpecular(half3 H, half3 T, half3 B, half3 N,
                         half roughness, half anisotropy)
{
    half TdotH = dot(T, H);
    half BdotH = dot(B, H);
    half NdotH = dot(N, H);

    half roughnessT = roughness * (1.0 + anisotropy);   // wide along T
    half roughnessB = roughness * (1.0 - anisotropy);   // narrow along B

    half normalization = 1.0 / (PI * roughnessT * roughnessB);
    half exponent = -(TdotH² / roughnessT² + BdotH² / roughnessB²) / (NdotH² + ε);
    return normalization * exp(exponent);
}
```

Key points:

| Aspect | Detail |
|--------|--------|
| **NDF model** | Simplified Ward (Gaussian in half-angle space) — different from GGX |
| **Roughness split** | `roughnessT = r * (1 + a)` / `roughnessB = r * (1 - a)` — *linear* split |
| **Default values** | `_AnisotropicRoughness = 0.6`, `_AnisotropicIntensity = 0.3` |
| **Result** | A long, narrow highlight lobe stretching perpendicular to the fiber direction |

### 1.3  Why it looks like a strip

1. **Direction parameter** — `_AnisotropicDirection = (0, 1, 0, 0)` aligns the aniso axis along the bitangent (≈ the leg axis for typical UV layouts). The highlight stretches perpendicular to this axis, producing a horizontal band wrapping around the leg.

2. **Roughness asymmetry** — With `anisotropy = 0.3` and `roughness = 0.6`:
   - `roughnessT = 0.78` (wide, smeared along tangent)
   - `roughnessB = 0.42` (tight along bitangent)
   
   This 1.86:1 ratio elongates the highlight into a strip.

3. **Additive compositing** — The Ward specular is multiplied by `0.5` and *added* to the base PBR colour. It does not replace the base specular; it's a second highlight on top.

4. **Charlie Sheen synergy** — The Charlie sheen term (`(2 + 1/r) * sin²h^(1/2r)`) adds broad low-angle glow that fills in below the strip highlight, making the overall specular appear softer and more fabric-like rather than hard/mirror-like.

### 1.4  Tangent frame rotation

```hlsl
half3 anisoDir = normalize(_AnisotropicDirection.xyz);   // default (0,1,0)
tangentWS = normalize(tangentWS * anisoDir.x + bitangentWS * anisoDir.y + N * anisoDir.z);
bitangentWS = normalize(cross(N, tangentWS));
```

This remaps `tangentWS` to point along the user-specified fiber direction within the tangent frame. For `(0,1,0)`, the new tangent aligns with the original bitangent (V-axis / leg axis), so the specular stretches around the circumference (U-axis / perpendicular to leg axis).

---

## 2  Current Procedural Shader Specular — Comparison

### 2.1  What is already there

The procedural shader (`FabricPBR_ProceduralPattern.shader`) already has:

| Feature | Implementation | Status |
|---------|---------------|--------|
| **Anisotropic NDF** | `DistributionGGXAnisotropic(N, T, H, roughness, anisotropy)` | ✅ Present |
| **Roughness split** | `aspect = sqrt(1 - 0.9 * anisotropy)`; `ax = r² / aspect`, `ay = r² * aspect` | ✅ Present (GGX-based, not Ward) |
| **Geometry term** | Smith-Schlick-GGX | ✅ Present |
| **Thread-direction tangent** | Rotates `tangentWS` using `knitResult.threadDir` from SDF | ✅ Present |
| **Charlie Sheen** | `EvaluateSheen()` using CharlieD + ClothV | ✅ Present |
| **Anisotropy parameter** | `_Anisotropy`, range (-1, 1) | ✅ Present |

### 2.2  Why it does not produce the same strip look

| Difference | Stocking.shader | Procedural shader | Impact |
|------------|----------------|-------------------|--------|
| **NDF model** | Ward (Gaussian `exp(...)`) | GGX (algebraic `1/(d²)`) | GGX has heavier tails, wider body — less "crisp strip", more "spread glow" |
| **Roughness split formula** | Linear: `r*(1±a)` | Aspect-based: `r²/√(1-0.9a)` vs `r²*√(1-0.9a)` | GGX aspect formula modulates width more gently; Ward's linear split creates a more extreme ratio at the same `anisotropy` value |
| **Tangent direction** | Fixed `_AnisotropicDirection` vector, user-controllable, *not mesh-dependent* | `threadDir` from SDF: follows individual knit loops, rotates per-pixel to match yarn arcs | Per-pixel SDF direction creates many small, per-loop streaks rather than one continuous leg-scale strip |
| **Compositing** | Ward spec is a *separate additive layer* scaled by `0.5`, on top of base PBR (which itself has a normal isotropic highlight) | All specular goes through a single GGX anisotropic NDF pass — there is no separate "strip layer" | The procedural shader's single specular pass cannot simultaneously be an isotropic base + an elongated aniso highlight |
| **Far-field behaviour** | No fade; Ward spec is view-consistent at all distances | `threadDir` fades toward `(1,0)` via SDF `fade` parameter at distance — not related to leg axis | At distance, the specular direction doesn't converge to a coherent strip; it converges to the mesh tangent (U-axis) rather than a leg-axis-aligned direction |

### 2.3  Root cause summary

The procedural shader's anisotropic specular acts per-yarn-loop (driven by SDF `threadDir`), producing fine-scale fibre highlights. Stocking.shader's anisotropic specular acts at the limb scale (driven by a fixed user direction), producing a smooth wrap-around strip. **These are two different spatial scales of anisotropy.** The strip effect requires the limb-scale layer.

---

## 3  Outstanding Far-Field Issues (from FabricPBR_FarSpecular_Analysis.md)

The earlier analysis identified three interacting problems that are **still present** in the current shader (previous fixes were reverted). They remain relevant and interact with the strip specular plan:

### 3.1  Screen-space specular crawl

**Current state:** `InterleavedGradientNoise(positionCS.xy)` drives the yarn-angle micro-NDF tilt in `FabricPBR_KnitSurface.hlsl` (line ~148). Because this noise is screen-anchored, the per-loop specular shimmer crawls when the camera or character moves.

**Previous fix (reverted):** Replace with `cellID`-based hash so the tilt sticks to each stitch.

**Interaction with strip plan:** The strip specular layer (Ward, limb-scale) is **not affected** — it uses a fixed direction, no SDF noise. However, the per-loop GGX specular still sparkles. Fixing this remains desirable independently.

### 3.2  Moiré fade threshold

**Current state:** `fade = 1 - smoothstep(0.3, 1.0, cellsPerPx)` and `bumpFade = smoothstep(0.2, 0.7, cellsPerPx)` in `FabricPBR_ProceduralPattern_Utilities.hlsl`. The SDF stays partially sampled up to `cellsPerPx = 1.0`, well past the Nyquist limit (~0.5), causing concentric moiré bands.

**Previous fix (reverted):** Tighten to `smoothstep(0.2, 0.5, ...)`.

**Interaction with strip plan:** The strip specular actually **mitigates** perceived specular loss during fade — it provides a stable, distance-independent highlight. But the moiré banding itself is a separate visual artefact that tightened fade would fix.

### 3.3  Specular collapse when bump flattens

**Current state:** When `bumpFade` removes micro-normal variance at distance, the per-loop GGX highlight collapses into a tight plastic-looking spot. The roughness boost (`cellsPerPx * 0.35 * _FabricMicroNDFStrength`) partially compensates but isn't sufficient alone.

**Previous fix (reverted):** Anisotropy boost in `KnitSurfaceResult` — lerp anisotropy toward 0.95 at distance so the GGX lobe elongates into a fibre-like strip.

**Interaction with strip plan:** The new Ward strip layer **largely solves this problem by design** — even when per-loop GGX collapses, the Ward strip highlight remains visible and fabric-like. This makes the anisotropy-boost approach from the earlier analysis **redundant** if the strip layer is implemented. The roughness boost remains useful as a complementary measure.

### 3.4  Revised priority

| Issue | Still needs fixing? | Blocked by strip plan? |
|-------|--------------------|-----------------------|
| Screen-space noise crawl | Yes — independent visual bug | No |
| Moiré fade threshold | Yes — independent visual bug | No |
| Specular collapse at distance | **Mostly solved by strip layer** | N/A — strip IS the fix |

The noise crawl and moiré fixes can be done **before or after** the strip specular, in any order. They are orthogonal changes. The specular-collapse fix (anisotropy boost) is **superseded** by the strip layer and should be dropped to avoid redundant complexity.

---

## 4  Strip Specular Integration Plan

### Goal
Add a limb-scale strip specular to the procedural shader, similar to Stocking.shader, while preserving the existing per-loop SDF-driven highlights.

### 4.1  Approach: Additive second specular layer

Rather than replacing the existing GGX anisotropic specular, add a **dedicated strip-highlight layer** that operates independently.

#### Option A — Ward model (match Stocking.shader exactly)

Add `AnisotropicSpecular()` from Stocking.shader as a new helper in `FabricPBR_ProceduralPattern_Utilities.hlsl`, and invoke it as an additive term in the forward pass.

**Pros**: Exact visual match to reference; Ward's Gaussian falloff is sharper → cleaner strip.
**Cons**: Two different NDF models in one shader increases complexity.

#### Option B — Second GGX-aniso pass with higher anisotropy

Reuse the existing `DistributionGGXAnisotropic()` with a separate (higher) anisotropy value and a fixed direction. This adds the strip without introducing a new NDF model.

**Pros**: Simpler code, consistent NDF family.
**Cons**: GGX has broader tails than Ward → strip may look less crisp. May need higher anisotropy to achieve same visual ratio.

#### Recommendation: **Option A** — The Ward model is only ~10 lines and gives the distinctive sharp-edged strip that the user wants. The visual difference between Ward and GGX strips is noticeable and difficult to compensate with parameter tuning alone.

### 4.2  Detailed steps

#### Step 1 — Add Ward helper function

Add `WardAnisotropicSpecular()` to `FabricPBR_ProceduralPattern_Utilities.hlsl`, matching the Stocking.shader implementation.

#### Step 2 — Add new material properties

In the Properties block and CBUFFER of `FabricPBR_ProceduralPattern.shader` and `FabricPBR_Common.hlsl`:

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `_StripSpecDirection` | Vector | (0, 1, 0, 0) | Fiber direction in tangent space |
| `_StripSpecIntensity` | Range(0, 1) | 0.3 | Intensity of the strip highlight |
| `_StripSpecRoughness` | Range(0.01, 1) | 0.6 | Base roughness for the Ward NDF |
| `_StripSpecAnisotropy` | Range(0, 1) | 0.3 | Roughness asymmetry ratio |

**Note**: Keeping these separate from the existing `_Anisotropy` is intentional — the existing parameter drives the SDF-level per-loop GGX specular; the new params drive the limb-scale strip.

#### Step 3 — Compute strip tangent frame in fragment shader

After the existing tangent re-orthogonalization, compute a **second tangent** for the strip layer:

```
// pseudo-code
float3 stripTangentWS = normalize(
    tangentWS * _StripSpecDirection.x
  + bitangentWS * _StripSpecDirection.y
  + normalWS * _StripSpecDirection.z);
float3 stripBitangentWS = normalize(cross(normalWS, stripTangentWS));
```

This is independent of `threadDir` (which drives the per-loop SDF tangent).

#### Step 4 — Evaluate Ward strip specular per light

For main light and additional lights, compute:

```
// pseudo-code
float stripSpec = WardAnisotropicSpecular(
    H, stripTangentWS, stripBitangentWS, normalWS,
    _StripSpecRoughness, _StripSpecAnisotropy);
float3 stripTerm = stripSpec * _StripSpecIntensity * lightRadiance * NdotL;
```

Add `stripTerm` to `mainReflectLighting` / `addReflectLighting`.

The multiplication by `_StripSpecIntensity` (default 0.5) controls how strong the additive strip is.

#### Step 5 — Apply fabricSpecAtten to strip layer

The strip specular should respect `fabricSpecAtten` (which dims specular on thread regions for the knit pattern). Apply the same attenuation:

```
stripTerm *= fabricSpecAtten;
```

#### Step 6 — (Optional) Indirect strip contribution

For environment reflections, the strip highlight could optionally bias the reflection probe sampling toward a slightly anisotropic lobe. However, this is a minor effect; the strip is primarily visible in direct lighting. Consider skipping this for simplicity.

#### Step 7 — Update FabricPBR_TextureBased.shader

Add the same strip specular layer to the texture-based shader for consistency.

#### Step 8 — Update FabricPBR_Common.hlsl CBUFFER

Add the four new uniforms to the shared CBUFFER.

### 4.3  Parameters to tune after implementation

| Parameter | Suggested starting value | Tuning notes |
|-----------|------------------------|--------------|
| `_StripSpecDirection` | (0, 1, 0, 0) | For legs, bitangent direction is typically along the leg axis. May need adjusting per mesh UV orientation. |
| `_StripSpecIntensity` | 0.3 | Higher = brighter strip. Keep ≤ 0.5 to avoid overpowering base specular. |
| `_StripSpecRoughness` | 0.5 | Lower = sharper, thinner strip. Higher = wider, softer. |
| `_StripSpecAnisotropy` | 0.4 | Higher = more elongated strip. 0.3–0.5 range gives good nylon look. |

### 4.4  Risk assessment

| Risk | Mitigation |
|------|-----------|
| Two specular layers = 2× specular cost | Ward NDF is very cheap (one `exp` + arithmetic); perf impact < 5% of fragment shader cost |
| Strip direction depends on UV layout | `_StripSpecDirection` parameter lets user adjust per material; for most leg meshes, (0,1,0) or (1,0,0) works |
| Interaction with `_FabricSpecAttenuation` | Strip layer uses same atten path — no special handling needed |
| Interaction with denier opacity | Strip highlight already goes through `reflectCoverage` compositing — sheer regions will have proportionally stronger reflection vs body, same as existing specular |

### 4.5  Files to modify

1. **`FabricPBR_ProceduralPattern_Utilities.hlsl`** — Add `WardAnisotropicSpecular()` function
2. **`FabricPBR_Common.hlsl`** — Add four new uniforms to CBUFFER
3. **`FabricPBR_ProceduralPattern.shader`** — Add Properties, compute strip tangent, evaluate per light, add to reflect lighting
4. **`FabricPBR_TextureBased.shader`** — Same as above
5. **`FabricPBR_TextureBased_Utilities.hlsl`** — If shared utilities are preferred there

### 4.6  What NOT to change

- The existing GGX anisotropic NDF (`DistributionGGXAnisotropic`) stays untouched — it still handles yarn-loop-level fibre highlights.
- `threadDir` rotation in the tangent stays untouched — it still drives per-loop tangent direction.
- KnitSurface.hlsl stays untouched — the strip layer is purely a lighting-composition addition, not a surface evaluation change.
- The sheen, clearcoat, subsurface, and opacity pipelines stay untouched.
- The earlier anisotropy-boost approach (Step 4 of FarSpecular_Analysis) is **dropped** — the strip layer replaces its purpose.

---

## 5  Consolidated Execution Order

Combining the strip specular plan (§4) with the still-relevant far-field fixes (§3):

| Phase | Task | Files | Depends on |
|-------|------|-------|-----------|
| **A** | Add Ward helper + strip properties + per-light evaluation (Steps 1–5 of §4.2) | Utilities.hlsl, Common.hlsl, ProceduralPattern.shader | — |
| **B** | Add strip specular to texture-based shader (Step 7 of §4.2) | TextureBased.shader, TextureBased_Utilities.hlsl | A |
| **C** | Fix screen-space noise crawl (§3.1) — replace `InterleavedGradientNoise(positionCS.xy)` with `cellID`-based hash in yarn-angle micro-NDF | KnitSurface.hlsl | — |
| **D** | Tighten moiré fade threshold (§3.2) — `smoothstep(0.2, 0.5, ...)` in SDF fade and bump fade | ProceduralPattern_Utilities.hlsl, KnitMask_Simple.hlsl | — |

Phases A/B (strip specular) and C/D (far-field fixes) are **independent** and can be done in any order or in parallel. Within each pair, B depends on A and D is independent of C.

### Suggested order

1. **Phase A** first — gives immediate visual payoff (the strip highlight).
2. **Phase B** — keeps both shaders in sync.
3. **Phase C** — eliminates specular crawl.
4. **Phase D** — eliminates moiré banding.

Each phase can be tested and reviewed independently before proceeding to the next.
