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

    float  _UseProceduralKnit;
    float  _KnitUVTiling;
    float  _NumberOfLoops;
    float  _LoopAspect;
    float  _OpeningSize;
    float  _OpeningSoftness;
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

    float  _UseReflectiveProbe;
    float  _UseCustomCubemap;

    float  _UseNormalMap;
    float  _UseMetallicMap;
    float  _UseRoughnessMap;
    float  _UseAOMap;
    float  _UseAnisotropyMap;
    float  _UseHeightMap;
CBUFFER_END

// Shared dither function
float DitherThreshold4x4(float2 screenPos)
{
    const float4x4 bayer = float4x4(
         0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
        12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
         3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
        15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
    );
    uint2 idx = uint2(screenPos) % 4;
    return bayer[idx.x][idx.y];
}

float StableDitherWS(float3 positionWS)
{
    float3 p = floor(positionWS * 128.0);
    return frac(sin(dot(p, float3(12.9898, 78.233, 37.719))) * 43758.5453);
}

#endif