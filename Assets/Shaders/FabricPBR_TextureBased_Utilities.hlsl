#ifndef CUSTOM_FABRIC_TEXTURE_BASED_UTILITIES_INCLUDED
#define CUSTOM_FABRIC_TEXTURE_BASED_UTILITIES_INCLUDED

// ── Interleaved Gradient Noise ────────────────
// Matches the implementation in FabricPBR_ProceduralPattern_Utilities.hlsl
// Used for per-pixel stochastic normal tilt (yarn-loop micro-NDF).
float InterleavedGradientNoise(float2 screenPos)
{
    return frac(52.9829189 * frac(dot(screenPos, float2(0.06711056, 0.00583715))));
}

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

    if (_UseCustomCubemap > 0)
    {
        float3 R = reflect(-viewDirWS, normalWS);
        float3 prefiltered = SAMPLE_TEXTURECUBE_LOD(
                                 _CustomCubemap, sampler_CustomCubemap, R, envLOD)
                                 .rgb;
        result.specular = prefiltered * (kS * brdf.x + brdf.y);

        float3 irradiance = SAMPLE_TEXTURECUBE_LOD(
                                _CustomCubemap, sampler_CustomCubemap, normalWS, 6.0)
                                .rgb;
        result.diffuse = kD * albedo * irradiance;
    }
    else if (_UseReflectiveProbe > 0)
    {
        float3 R = reflect(-viewDirWS, normalWS);
        float3 prefiltered = GlossyEnvironmentReflection(
            R, positionWS, roughness, 1.0, screenUV);
        result.specular = prefiltered * (kS * brdf.x + brdf.y);
        result.diffuse = kD * albedo * bakedIrradiance;
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

// ── Parallax ─────────────────────────────────
float2 ParallaxOffset(float2 uv, float3 viewDirTS)
{
    float h = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
    return uv + viewDirTS.xy / (viewDirTS.z + 0.42) * (h * _HeightScale);
}
#endif