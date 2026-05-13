# BasePBR.shader — Disney Principled Upgrade Plan

Target: bring `Assets/Shaders/BasePBR.shader` in line with the Disney Principled BRDF
(Burley 2012) while keeping it a forward URP shader.

This document is the source-of-truth plan; the shader is rewritten in one pass to
match it.

---

## 1. BRDF math fixes

### 1.1 Roughness convention (BREAKING)
- UI value `_Roughness` is now treated as **perceptual roughness**.
- All D / G code uses `α = perceptualRoughness²` (Disney/UE4 standard).
- IBL mip selection uses `PerceptualRoughnessToMipmapLevel(perceptualRoughness)`
  instead of linear `roughness * 6`.
- Visual change: existing materials at mid-roughness will look softer/blurrier.

### 1.2 Diffuse lobe
- Replace `albedo / π` Lambert with **Burley/Disney diffuse**:
  - `FD90 = 0.5 + 2 · roughness · cos²θ_d`
  - `f_d = (1 + (FD90-1)(1-NoL)^5) · (1 + (FD90-1)(1-NoV)^5) · albedo/π`
- Applied identically on main light, additional lights, and IBL diffuse.

### 1.3 Anisotropic Smith G
- The anisotropic GGX NDF is currently paired with an isotropic Smith G.
- Add `GeometrySmithGGXAnisotropic(NoV, NoL, ToV, ToL, BoV, BoL, ax, ay)`
  using the anisotropic Smith Λ form.
- Used by main light + additional lights when anisotropy is non-zero.

### 1.4 Anisotropic rotation
- New property `_AnisotropicRotation` (0..1, mapped to 0..2π).
- Rotates tangent frame around N before evaluating the anisotropic lobe.

### 1.5 NoL clamping
- `saturate(dot(N, L))` early instead of relying on outer multiplication to
  zero degenerate denominators.

---

## 2. Layered lobes

### 2.1 Sheen
- `_SheenColor` is now actually used as the sheen color (was: only `.r`).
- New scalar `_SheenTint` (0..1) blends between white and the luminance-
  normalized albedo, matching Disney's `sheenTint`.
- Final sheen = `_Sheen · lerp(_SheenColor, albedoTint·_SheenColor, _SheenTint)
  · (1 - cosθ_d)^5`.

### 2.2 Clearcoat
- Add clearcoat lobe to **additional lights** and to **IBL** (currently
  main-light only).
- IBL clearcoat uses a separate environment sample at clearcoat roughness with
  fixed F0 = 0.04.
- Base specular layer is **not** attenuated by clearcoat Fresnel — kept simple,
  documented as an approximation.

### 2.3 Specular tint (rename)
- `_SpecularIntensity` → `_SpecularTint` (the property was already used as a
  blend, now its name matches its behavior).

---

## 3. Sampling / energy

### 3.1 IBL mip
- Use `PerceptualRoughnessToMipmapLevel(perceptualRoughness)` for both
  reflective probe and custom cubemap paths.

### 3.2 Custom cubemap diffuse
- Continue sampling max mip as an irradiance proxy, but document that this is
  an approximation; a proper convolved irradiance map is recommended for
  production.

### 3.3 Specular occlusion
- Apply Lagarde's specular occlusion approximation:
  `specOcc = saturate(pow(NoV + AO, exp2(-16·roughness - 1)) - 1 + AO)`
  to the IBL specular term so AO actually affects reflections.

### 3.4 AO map wiring
- `_AOMap` is currently declared but never sampled. Wire it up:
  `ao = lerp(1, _AOMap.g, _UseAOMap) · _AmbientOcclusion`.

---

## 4. New surface features

### 4.1 Parallax (height map)
- New property `_HeightScale` (0..0.1).
- Implement single-step parallax offset (`ParallaxOffset1Step` style) on UVs
  before any texture sample when `_UseHeightMap` is enabled.
- Cheap, no POM iterations — keeps mobile-friendly.

---

## 5. URP integration

### 5.1 New passes
Add proper passes inline (no `UsePass` from Lit because we use `_MainTex`
not `_BaseMap`):
- **ShadowCaster** — needed for the object to cast shadows at all.
- **DepthOnly** — needed for depth prepass / SSAO / depth-of-field.
- **DepthNormals** — needed for screen-space normal-based effects.
- **Meta** — needed for correct lightmap baking.

### 5.2 Keyword hygiene
- Convert per-feature toggles to `shader_feature_local`:
  - `_USE_NORMAL_MAP`, `_USE_METALLIC_MAP`, `_USE_ROUGHNESS_MAP`,
    `_USE_AO_MAP`, `_USE_ANISOTROPY_MAP`, `_USE_HEIGHT_MAP`,
    `_USE_REFLECTIVE_PROBE`, `_USE_CUSTOM_CUBEMAP`, `_ENABLE_EMISSION`.
- Add the missing URP keywords:
  - `_MAIN_LIGHT_SHADOWS`, `_MAIN_LIGHT_SHADOWS_CASCADE`,
    `_MAIN_LIGHT_SHADOWS_SCREEN`
  - `_ADDITIONAL_LIGHTS_VERTEX`, `_ADDITIONAL_LIGHTS`,
    `_ADDITIONAL_LIGHT_SHADOWS`
  - `_REFLECTION_PROBE_BLENDING`, `_REFLECTION_PROBE_BOX_PROJECTION`
  - `_SHADOWS_SOFT`, `_SCREEN_SPACE_OCCLUSION`, `_LIGHT_COOKIES`,
    `_LIGHT_LAYERS`, `_FORWARD_PLUS`
  - `LIGHTMAP_ON`, `DYNAMICLIGHTMAP_ON`, `DIRLIGHTMAP_COMBINED`,
    `LIGHTMAP_SHADOW_MIXING`, `SHADOWS_SHADOWMASK`,
    `_LIGHT_LAYERS`, `USE_APV_PROBE_OCCLUSION`, `EVALUATE_SH_MIXED`,
    `EVALUATE_SH_VERTEX`, `PROBE_VOLUMES_L1`, `PROBE_VOLUMES_L2`
- Fix `multi_compile_frag _MAIN_LIGHT_SHADOWS_CASCADE` (was a single-variant
  declaration).

### 5.3 Fog
- Apply `MixFog(color, fogFactor)` at the end of the forward pass; remove the
  stale "we don't apply fog in the gbuffer pass" comment.

---

## 6. Cleanup

- Remove dead `InitializeSimpleLitSurfaceData` helper — it's only used to
  feed `InitializeInputData` with a normal that we already compute.
- Remove the duplicate `_MainTex` sample in the surface-data helper.
- Drop the unused `_F0` reads (kept as property — dielectric F0 control is
  legitimate Disney input under the name `specular`/`F0`).
- Clarify comments where conventions are non-obvious.

---

## 7. Property-level changes (BREAKING)

| Old | New | Notes |
|-----|-----|-------|
| `_SpecularIntensity` | `_SpecularTint` | semantics unchanged, name now correct |
| `_SheenColor` (only .r used) | `_SheenColor` (full RGB) + `_SheenTint` scalar | matches Disney |
| `_HeightMap` (unused) | `_HeightMap` + `_HeightScale` | now wired to parallax |
| `_AOMap` (unused) | `_AOMap` (now sampled) | wired to indirect AO |
| `_Roughness` | `_Roughness` (perceptual) | UI same, math now squares it |
| toggles as `float` branches | shader_feature_local keywords | perf |

Existing materials referencing the old `_SpecularIntensity` name will lose that
value on first import. This is accepted per the user's explicit choice.

---

## 8. Validation

- After save: read Unity console for compile errors.
- Manual visual smoke test left to the user; this plan does not change render
  pipeline assets.
