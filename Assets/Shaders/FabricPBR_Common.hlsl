// ─────────────────────────────────────────────────────
// FabricPBR_Common.hlsl
// Shared CBUFFER — MUST be identical in every pass
// for SRP Batcher compatibility.
// ─────────────────────────────────────────────────────
#ifndef FABRIC_PBR_COMMON_INCLUDED
#define FABRIC_PBR_COMMON_INCLUDED

CBUFFER_START(UnityPerMaterial)
    float4 _BaseColor;
    float  _Metallic;
    float  _Roughness;
    float  _AmbientOcclusion;
    float  _Anisotropy;
    float4 _SpecularColor;
    float  _SpecularTint;
    float4 _EmissionColor;
    float  _EnableEmission;
    float  _F0;
    float  _ClearCoat;
    float  _ClearCoatRoughness;
    float  _Sheen;
    float4 _SheenColor;
    float  _SheenRoughness;
    float4 _TextureTiling;
    float4 _MainTex_ST;
    float  _HeightScale;
    float  _NormalStrength;

    float  _Subsurface;
    float4 _SubsurfaceColor;
    float  _TransmissionDistortion;
    float  _TransmissionPower;
    float  _AmbientTransmission;

    float  _DiffuseWrap;

    float  _FuzzIntensity;
    float4 _FuzzColor;
    float  _FuzzPower;

    // ── Fabric Micro-BRDF (texture-based shader) ──────────────────────
    // _FabricSpecAttenuation: 0 = full fabric (85% GGX suppression),
    //                         1 = standard PBR (no attenuation)
    float  _FabricSpecAttenuation;
    // _FabricMicroNDFStrength: scales the per-pixel stochastic normal tilt
    //                          and roughness elevation from UV pixel footprint.
    float  _FabricMicroNDFStrength;

    float  _UseProceduralKnit;
    float  _UseAntiMoire;
    float  _KnitFadeStart;
    float  _KnitFadeEnd;
    float  _KnitUVTiling;
    float  _NumberOfLoops;
    float  _LoopAspect;
    float  _OpeningSize;
    float  _OpeningSoftness;
    float  _UseAnalyticSoftness;
    float  _GapOpacity;
    float  _KnitNormalStrength;
    float  _KnitRoughnessVar;
    float  _ThreadDarken;
    float  _KnitJitter;
    float  _KnitNoiseScale;
    float  _GapEdgeHighlight;
    float _GapShapePower;
    float _GapWidthRatio;
    float _ThreadWidth;

    float  _StretchTransparency;
    float  _StretchOpeningGrow;
    float  _StretchReference;
    float  _UseStretchFromVertexG;

    float  _TwoLayerDarkening;
    float  _TwoLayerPower;
    float  _TwoLayerSaturation;

    float  _UseDenierFromVertexR;
    float  _DenierMin;
    float  _DenierMax;

    float  _Opacity;
    float  _ShadowDensity;
    float  _ForwardZWrite;
    float  _UseOpacityMap;
    float  _UseVertexAlpha;
    float  _FresnelOpacityPower;
    float  _FresnelOpacityStrength;
    float  _SeeThruTint;

    float4 _StripSpecDirection;
    float  _StripSpecIntensity;
    float  _StripSpecRoughness;
    float  _StripSpecAnisotropy;
    float  _StripSpecWidth;

    float  _UseReflectiveProbe;
    float  _UseCustomCubemap;

    float  _UseNormalMap;
    float  _UseMetallicMap;
    float  _UseRoughnessMap;
    float  _UseAOMap;
    float  _UseAnisotropyMap;
    float  _UseHeightMap;
CBUFFER_END

float StableDitherWS(float3 positionWS)
{
    float3 p = floor(positionWS * 128.0);
    return frac(sin(dot(p, float3(12.9898, 78.233, 37.719))) * 43758.5453);
}

#endif