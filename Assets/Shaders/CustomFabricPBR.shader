Shader "Custom/FabricPBR"
{
    Properties
    {
        [Header(Main Color)]
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)

        [Header(Normal Map)]
        [Toggle(Use Normal Map)] _UseNormalMap("Use Normal Map", Float) = 0
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0, 2)) = 1.0

        [Header(Metallic)]
        _Metallic("Metallic", Range(0,1)) = 0.0
        [Toggle(Use Metallic Map)] _UseMetallicMap("Use Metallic Map", Float) = 0
        _MetallicMap("Metallic Map", 2D) = "white" {}

        [Header(Roughness)]
        _Roughness("Roughness", Range(0,1)) = 0.5
        [Toggle(Use Roughness Map)] _UseRoughnessMap("Use Roughness Map", Float) = 0
        _RoughnessMap("Roughness Map", 2D) = "white" {}

        [Header(Ambient Occlusion)]
        _AmbientOcclusion("Ambient Occlusion", Range(0,1)) = 1.0
        [Toggle(Use AO Map)] _UseAOMap("Use AO Map", Float) = 0
        _AOMap("AO Map", 2D) = "white" {}

        [Header(Anisotropy)]
        _Anisotropy("Anisotropy", Range(0,1)) = 0.5
        [Toggle(Use Anisotropy Map)] _UseAnisotropyMap("Use Anisotropy Map", Float) = 0
        _AnisotropyMap("Anisotropy Map", 2D) = "white" {}

        [Header(Specular)]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularTint("Specular Tint (albedo blend)", Range(0,1)) = 0.0

        [Header(Emission)]
        _EmissionColor("Emission Color", Color) = (0,0,0,1)
        [Toggle(Enable Emission)] _EnableEmission("Enable Emission", Float) = 0

        [Header(Height Map)]
        [Toggle(Use Height Map)] _UseHeightMap("Use Height Map", Float) = 0
        _HeightMap("Height Map", 2D) = "black" {}
        _HeightScale("Height Scale", Range(0, 0.1)) = 0.02

        [Header(Sheen)]
        _Sheen("Sheen Intensity", Range(0,1)) = 0.0
        _SheenColor("Sheen Color", Color) = (1,1,1,1)
        _SheenRoughness("Sheen Roughness", Range(0.05,1)) = 0.5

        [Header(Subsurface Transmission)]
        _Subsurface("Subsurface Intensity", Range(0,1)) = 0.0
        _SubsurfaceColor("Subsurface Color", Color) = (1, 0.4, 0.25, 1)
        _TransmissionDistortion("Normal Distortion", Range(0, 1)) = 0.5
        _TransmissionPower("Transmission Power", Range(1, 16)) = 4.0
        _AmbientTransmission("Ambient Transmission", Range(0, 1)) = 0.5

        [Header(Diffuse Wrap)]
        _DiffuseWrap("Diffuse Wrap", Range(0, 0.5)) = 0.0

        [Header(Fabric Fuzz)]
        _FuzzIntensity("Fuzz Intensity", Range(0, 1)) = 0.0
        _FuzzColor("Fuzz Color", Color) = (0.5, 0.5, 0.5, 1)
        _FuzzPower("Fuzz Power", Range(1, 8)) = 3.0

        // ★ ────────────────────────────────────────────
        // ★ Procedural Weave (ported from FabricPattern)
        // ★ ────────────────────────────────────────────
        [Header(Procedural Weave)]
        [Toggle] _UseProceduralWeave("Enable Procedural Weave", Float) = 0
        _WeaveUVTiling("UV Tiling Multiplier", Float) = 1.0
        _NumberOfThreads("Thread Count", Float) = 40
        _WeaveFabricIntensity("Thread Distortion", Range(0, 2)) = 0.3
        _WeaveNoiseScale("Noise Scale", Float) = 10
        _GapThreshold("Gap Size", Range(0.01, 0.5)) = 0.25
        _GapSoftness("Gap Edge Softness", Range(0.001, 0.2)) = 0.05
        _GapOpacity("Gap Min Opacity", Range(0, 1)) = 0.05
        _WeaveNormalStrength("Weave Bump Strength", Range(0, 10)) = 2.0
        _WeaveRoughnessVar("Thread Roughness Variation", Range(0, 0.3)) = 0.1
        _WeaveDarken("Thread Edge Darkening", Range(0, 1)) = 0.2

        [Header(Clearcoat)]
        _ClearCoat("Clear Coat", Range(0,1)) = 0.0
        _ClearCoatRoughness("Clear Coat Roughness", Range(0,1)) = 0.5

        [Header(Transparency)]
        _Opacity("Base Opacity", Range(0, 1)) = 1.0
        [Toggle(Use Opacity Map)] _UseOpacityMap("Use Opacity Map", Float) = 0
        _OpacityMap("Opacity Map (R = opaque)", 2D) = "white" {}
        [Toggle(Use Vertex Alpha)] _UseVertexAlpha("Use Vertex Color Alpha", Float) = 0
        _FresnelOpacityPower("Edge Opacity Power", Range(1, 8)) = 3.0
        _FresnelOpacityStrength("Edge Opacity Boost", Range(0, 1)) = 0.0
        _SeeThruTint("See-Through Fabric Tint", Range(0, 1)) = 0.3

        [Header(Advanced)]
        _F0("F0 (Dielectric Reflectance)", Range(0,1)) = 0.04
        _TextureTiling("Texture Tiling", Vector) = (1,1,0,0)

        [Header(Reflection)]
        [Toggle(Use Reflective Probe)] _UseReflectiveProbe("Use Reflective Probe", Float) = 0
        [Toggle(Use Custom Cubemap)] _UseCustomCubemap("Use Custom Cubemap", Float) = 0
        _CustomCubemap("Custom Cubemap", Cube) = "" {}
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"     = "Transparent"
            "Queue"          = "Transparent"
        }

        // ═══════════════════════════════════════════════
        // Pass 0 : ForwardLit
        // ═══════════════════════════════════════════════
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED

            #pragma multi_compile _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            // ──────────────────────────────────────────────
            // Texture / Sampler Declarations
            // ──────────────────────────────────────────────
            TEXTURE2D(_MainTex);          SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);         SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicMap);       SAMPLER(sampler_MetallicMap);
            TEXTURE2D(_RoughnessMap);      SAMPLER(sampler_RoughnessMap);
            TEXTURE2D(_AOMap);             SAMPLER(sampler_AOMap);
            TEXTURE2D(_AnisotropyMap);     SAMPLER(sampler_AnisotropyMap);
            TEXTURE2D(_HeightMap);         SAMPLER(sampler_HeightMap);
            TEXTURE2D(_OpacityMap);        SAMPLER(sampler_OpacityMap);
            TEXTURECUBE(_CustomCubemap);   SAMPLER(sampler_CustomCubemap);

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

                // ★ Procedural Weave uniforms
                float  _UseProceduralWeave;
                float  _WeaveUVTiling;
                float  _NumberOfThreads;
                float  _WeaveFabricIntensity;
                float  _WeaveNoiseScale;
                float  _GapThreshold;
                float  _GapSoftness;
                float  _GapOpacity;
                float  _WeaveNormalStrength;
                float  _WeaveRoughnessVar;
                float  _WeaveDarken;

                float  _Opacity;
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

            // ──────────────────────────────────────────────
            // Structs
            // ──────────────────────────────────────────────
            struct Attributes
            {
                float4 positionOS        : POSITION;
                float3 normalOS          : NORMAL;
                float4 tangentOS         : TANGENT;
                float2 texcoord          : TEXCOORD0;
                float2 staticLightmapUV  : TEXCOORD1;
                float2 dynamicLightmapUV : TEXCOORD2;
                float4 color             : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 positionWS  : TEXCOORD1;
                float4 normalWS    : TEXCOORD2;
                float4 tangentWS   : TEXCOORD3;
                float4 bitangentWS : TEXCOORD4;

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half3 vertexLighting : TEXCOORD5;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord : TEXCOORD6;
                #endif

                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);

                #ifdef DYNAMICLIGHTMAP_ON
                    float2 dynamicLightmapUV : TEXCOORD8;
                #endif

                #ifdef USE_APV_PROBE_OCCLUSION
                    float4 probeOcclusion : TEXCOORD9;
                #endif

                half   fogFactor   : TEXCOORD10;
                float4 vertexColor : TEXCOORD11;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // ──────────────────────────────────────────────
            // Vertex Shader
            // ──────────────────────────────────────────────
            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.uv         = TRANSFORM_TEX(IN.texcoord, _MainTex) * _TextureTiling.xy;
                OUT.positionWS = vertexInput.positionWS;
                OUT.positionCS = vertexInput.positionCS;

                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                OUT.normalWS    = float4(normalInput.normalWS,    viewDirWS.x);
                OUT.tangentWS   = float4(normalInput.tangentWS,   viewDirWS.y);
                OUT.bitangentWS = float4(normalInput.bitangentWS, viewDirWS.z);

                OUT.vertexColor = IN.color;

                OUTPUT_LIGHTMAP_UV(IN.staticLightmapUV, unity_LightmapST, OUT.staticLightmapUV);
                #ifdef DYNAMICLIGHTMAP_ON
                    OUT.dynamicLightmapUV = IN.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy
                                          + unity_DynamicLightmapST.zw;
                #endif
                OUTPUT_SH4(vertexInput.positionWS, OUT.normalWS.xyz,
                           GetWorldSpaceNormalizeViewDir(vertexInput.positionWS),
                           OUT.vertexSH, OUT.probeOcclusion);

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    OUT.vertexLighting = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    OUT.shadowCoord = GetShadowCoord(vertexInput);
                #endif

                OUT.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                return OUT;
            }

            // ──────────────────────────────────────────────
            // Baked GI
            // ──────────────────────────────────────────────
            void InitializeBakedGIData(Varyings IN, inout InputData inputData)
            {
                #if defined(DYNAMICLIGHTMAP_ON)
                    inputData.bakedGI    = SAMPLE_GI(IN.staticLightmapUV, IN.dynamicLightmapUV,
                                                     IN.vertexSH, inputData.normalWS);
                    inputData.shadowMask = SAMPLE_SHADOWMASK(IN.staticLightmapUV);
                #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
                    inputData.bakedGI = SAMPLE_GI(IN.vertexSH,
                        GetAbsolutePositionWS(inputData.positionWS),
                        inputData.normalWS,
                        inputData.viewDirectionWS,
                        inputData.positionCS.xy,
                        IN.probeOcclusion,
                        inputData.shadowMask);
                #else
                    inputData.bakedGI    = SAMPLE_GI(IN.staticLightmapUV, IN.vertexSH, inputData.normalWS);
                    inputData.shadowMask = SAMPLE_SHADOWMASK(IN.staticLightmapUV);
                #endif
            }

            // ──────────────────────────────────────────────
            // SSAO
            // ──────────────────────────────────────────────
            float2 SampleSSAO(float2 screenUV)
            {
                float DirectAO   = 1.0;
                float IndirectAO = 1.0;
                #if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
                    float ssao = saturate(SampleAmbientOcclusion(screenUV)
                                        + (1.0 - _AmbientOcclusionParam.x));
                    IndirectAO = ssao;
                    DirectAO   = lerp(1.0, ssao, _AmbientOcclusionParam.w);
                #endif
                return float2(DirectAO, IndirectAO);
            }

            // ──────────────────────────────────────────────
            // Parallax
            // ──────────────────────────────────────────────
            float2 ParallaxOffset(float2 uv, float3 viewDirTS)
            {
                float h = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
                return uv + viewDirTS.xy / (viewDirTS.z + 0.42) * (h * _HeightScale);
            }

            // ──────────────────────────────────────────────
            // IBL
            // ──────────────────────────────────────────────
            float3 CalculateIBL(
                float3 normalWS, float3 viewDirWS, float3 positionWS, float2 screenUV,
                float3 albedo,   float  roughness,
                float3 kS,       float3 kD,
                float2 brdf,     float  envLOD,
                float3 bakedIrradiance)
            {
                float3 envSpec = 0;
                float3 envDiff = 0;

                if (_UseCustomCubemap > 0)
                {
                    float3 R = reflect(-viewDirWS, normalWS);
                    float3 prefiltered = SAMPLE_TEXTURECUBE_LOD(
                        _CustomCubemap, sampler_CustomCubemap, R, envLOD).rgb;
                    envSpec = prefiltered * (kS * brdf.x + brdf.y);

                    float3 irradiance = SAMPLE_TEXTURECUBE_LOD(
                        _CustomCubemap, sampler_CustomCubemap, normalWS, 6.0).rgb;
                    envDiff = kD * albedo * irradiance;
                }
                else if (_UseReflectiveProbe > 0)
                {
                    float3 R = reflect(-viewDirWS, normalWS);
                    float3 prefiltered = GlossyEnvironmentReflection(
                        R, positionWS, roughness, 1.0, screenUV);
                    envSpec = prefiltered * (kS * brdf.x + brdf.y);
                    envDiff = kD * albedo * bakedIrradiance;
                }

                return envSpec + envDiff;
            }

            // ──────────────────────────────────────────────
            // BRDF Utilities
            // ──────────────────────────────────────────────
            float2 EnvBRDFApprox(float roughness, float NoV)
            {
                const float4 c0 = float4(-1.0, -0.0275, -0.572,  0.022);
                const float4 c1 = float4( 1.0,  0.0425,  1.040, -0.040);
                float4 r    = roughness * c0 + c1;
                float  a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
                return float2(-1.04, 1.04) * a004 + r.zw;
            }

            float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
                return F0 + (max((float3)(1.0 - roughness), F0) - F0)
                          * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            float3 FresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            // ──────────────────────────────────────────────
            // Anisotropic GGX NDF
            // ──────────────────────────────────────────────
            float DistributionGGXAnisotropic(float3 N, float3 T, float3 H,
                                             float roughness, float anisotropy)
            {
                float aspect = sqrt(1.0 - 0.9 * anisotropy);
                float ax  = max(0.001, roughness * roughness / aspect);
                float ay  = max(0.001, roughness * roughness * aspect);
                float3 B  = cross(N, T);
                float XoH = dot(T, H);
                float YoH = dot(B, H);
                float NoH = max(dot(N, H), 0.0);
                float d   = XoH * XoH / (ax * ax)
                          + YoH * YoH / (ay * ay)
                          + NoH * NoH;
                return rcp(PI * ax * ay * d * d);
            }

            // ──────────────────────────────────────────────
            // Smith-Schlick-GGX Geometry
            // ──────────────────────────────────────────────
            float GeometrySmithSchlickGGX(float NoV, float NoL, float roughness)
            {
                float r1     = roughness + 1.0;
                float k      = max((r1 * r1) / 8.0, 0.0001);
                float smithV = NoV * rcp(NoV * (1.0 - k) + k);
                float smithL = NoL * rcp(NoL * (1.0 - k) + k);
                return smithV * smithL;
            }

            // ──────────────────────────────────────────────
            // Fabric Sheen: Charlie NDF + Neubelt V
            // ──────────────────────────────────────────────
            float CharlieD(float sheenRoughness, float NoH)
            {
                sheenRoughness = max(sheenRoughness, 0.07);
                float invR  = rcp(sheenRoughness);
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
                if (sheenIntensity <= 0.0) return 0.0;
                float D  = CharlieD(sheenRoughness, NoH);
                float V  = ClothV(NoV, NoL);
                float DV = min(D * V, 4.0);
                return sheenColor * sheenIntensity * DV;
            }

            float SheenDirectionalAlbedo(float sheenIntensity, float sheenRoughness)
            {
                return sheenIntensity * saturate(0.15 * sheenRoughness + 0.05);
            }

            // ──────────────────────────────────────────────
            // Clearcoat
            // ──────────────────────────────────────────────
            float3 EvaluateClearcoat(float clearcoat, float smoothness,
                                     float NoH, float HoL, float NoV, float NoL)
            {
                if (clearcoat <= 0.0) return 0.0;

                float alpha   = lerp(0.1, 0.001, smoothness);
                float alphaSq = alpha * alpha;

                float d = (alphaSq - 1.0)
                        * rcp(PI * log(alphaSq)
                              * (1.0 + (alphaSq - 1.0) * NoH * NoH));

                float f = 0.04 + 0.96 * pow(saturate(1.0 - HoL), 5.0);

                float ccRoughSq = 0.25 * 0.25;
                float gv = 2.0 * rcp(1.0 + sqrt(ccRoughSq + (1.0 - ccRoughSq) * NoV * NoV));
                float gl = 2.0 * rcp(1.0 + sqrt(ccRoughSq + (1.0 - ccRoughSq) * NoL * NoL));

                return (float3)(0.25 * clearcoat * d * f * gv * gl);
            }

            // ──────────────────────────────────────────────
            // Cook-Torrance Specular (reusable)
            // ──────────────────────────────────────────────
            float3 EvaluateSpecular(float3 N, float3 V, float3 L, float3 T,
                                    float3 F0val, float roughness, float anisotropy)
            {
                float3 H   = normalize(V + L);
                float  NoL = saturate(dot(N, L));
                float  NoV = max(dot(N, V), 0.0001);
                float  VoH = saturate(dot(V, H));

                float  D = DistributionGGXAnisotropic(N, T, H, roughness, anisotropy);
                float  G = GeometrySmithSchlickGGX(NoV, NoL, roughness);
                float3 F = FresnelSchlick(VoH, F0val);
                return D * G * F * rcp(max(4.0 * NoV * NoL, 0.0001));
            }

            // ──────────────────────────────────────────────
            // Subsurface Transmission
            // ──────────────────────────────────────────────
            float3 EvaluateTransmission(
                float3 N, float3 V, float3 L,
                float3 lightColor,
                float  subsurface, float3 subsurfaceColor,
                float  distortion, float  power)
            {
                if (subsurface <= 0.0) return 0.0;

                float3 transLight = normalize(L + N * distortion);
                float  VdotNegTL  = pow(saturate(dot(V, -transLight)), power);

                return subsurface * subsurfaceColor * VdotNegTL * lightColor;
            }

            // ══════════════════════════════════════════════
            // ★ PROCEDURAL WEAVE FUNCTIONS
            //   Ported from FabricPattern.shader
            //   2-octave noise for real-time performance
            // ══════════════════════════════════════════════

            void WeaveHash_uint(uint2 v, out uint o)
            {
                v.y ^= 1103515245U;
                v.x += v.y;
                v.x *= v.y;
                v.x ^= v.x >> 5u;
                v.x *= 0x27d4eb2du;
                o = v.x;
            }

            void WeaveHash_float(float2 i, out float o)
            {
                uint r;
                uint2 v = (uint2)(int2)round(i);
                WeaveHash_uint(v, r);
                o = (r >> 8) * (1.0 / float(0x00ffffff));
            }

            float WeaveNoiseValue(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);

                float r0; WeaveHash_float(i + float2(0, 0), r0);
                float r1; WeaveHash_float(i + float2(1, 0), r1);
                float r2; WeaveHash_float(i + float2(0, 1), r2);
                float r3; WeaveHash_float(i + float2(1, 1), r3);

                return lerp(lerp(r0, r1, f.x),
                            lerp(r2, r3, f.x), f.y);
            }

            // ★ 2-octave FBM — saves ~33% ALU vs 3-octave original
            float WeaveNoise2Oct(float2 UV, float Scale)
            {
                float noise = 0.0;
                noise += WeaveNoiseValue(UV * (Scale * 0.25)) * 0.667;
                noise += WeaveNoiseValue(UV * (Scale * 0.5))  * 0.333;
                return noise;
            }

            // ★ Returns weave height: 0 at thread center, ~0.5 at gap
            float WeaveHeight(float2 scaledUV)
            {
                float vertPattern = floor(fmod(scaledUV.x, 2.0));
                float horiPattern = floor(fmod(scaledUV.y, 2.0));
                float pattern = vertPattern * horiPattern
                              + (1.0 - vertPattern) * (1.0 - horiPattern);

                float vertNoise = WeaveNoise2Oct(scaledUV * float2(10, 1), _WeaveNoiseScale);
                vertNoise = (vertNoise * 2.0 - 1.0) * _WeaveFabricIntensity;
                float2 vertNoiseUV = scaledUV + (float2)vertNoise;
                vertNoiseUV.x = abs(vertNoiseUV.x - round(vertNoiseUV.x));

                float horiNoise = WeaveNoise2Oct(scaledUV * float2(1, 10), _WeaveNoiseScale);
                horiNoise = (horiNoise * 2.0 - 1.0) * _WeaveFabricIntensity;
                float2 horiNoiseUV = scaledUV + (float2)horiNoise;
                horiNoiseUV.y = abs(horiNoiseUV.y - round(horiNoiseUV.y));

                return max(pattern * vertNoiseUV.x,
                           (1.0 - pattern) * horiNoiseUV.y);
            }

            // ──────────────────────────────────────────────
            // Fragment Shader
            // ──────────────────────────────────────────────
            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float2 screenUV  = GetNormalizedScreenSpaceUV(IN.positionCS);
                float3 viewDirWS = SafeNormalize(
                    half3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w));
                float2 uv = IN.uv;

                // ── Parallax Offset ──────────────────────
                if (_UseHeightMap > 0)
                {
                    float3x3 tbn     = float3x3(IN.tangentWS.xyz,
                                                 IN.bitangentWS.xyz,
                                                 IN.normalWS.xyz);
                    float3 viewDirTS = mul(tbn, viewDirWS);
                    uv = ParallaxOffset(uv, viewDirTS);
                }

                // ── Sample Surface Maps ──────────────────
                float4 albedoSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                float3 albedo = _BaseColor.rgb * albedoSample.rgb;
                float  alpha  = _BaseColor.a   * albedoSample.a;

                float metallic = _UseMetallicMap > 0
                    ? SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv).r * _Metallic
                    : _Metallic;

                float roughness = _UseRoughnessMap > 0
                    ? SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).r * _Roughness
                    : _Roughness;
                roughness = max(roughness, 0.045);

                float ao = _UseAOMap > 0
                    ? SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, uv).r * _AmbientOcclusion
                    : _AmbientOcclusion;

                float anisotropy = _UseAnisotropyMap > 0
                    ? SAMPLE_TEXTURE2D(_AnisotropyMap, sampler_AnisotropyMap, uv).r * _Anisotropy
                    : _Anisotropy;

                // ── Normal (with strength) ───────────────
                half3 normalTS = half3(0, 0, 1);
                if (_UseNormalMap > 0)
                {
                    normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv));
                    normalTS.xy *= _NormalStrength;
                    normalTS = normalize(normalTS);
                }

                // ══════════════════════════════════════════
                // ★ PROCEDURAL WEAVE INTEGRATION
                //
                //   Outputs:
                //     weaveThreadMask — 1 on threads, 0 in gaps
                //     normalTS        — perturbed with weave bumps
                //     albedo          — darkened at thread edges
                //     roughness       — varied: smoother on threads,
                //                       rougher in gaps
                // ══════════════════════════════════════════
                float weaveThreadMask = 1.0;

                if (_UseProceduralWeave > 0)
                {
                    // Scale UV: tiling × even thread count
                    float2 weaveUV = uv * _WeaveUVTiling;
                    float2 scaledWeaveUV = weaveUV
                        * (ceil(_NumberOfThreads * 0.5) * 2.0);

                    // ★ Weave height: 0 at thread center,
                    //   ~0.5 at cell boundary (gap)
                    float weaveH = WeaveHeight(scaledWeaveUV);

                    // ★ Thread mask via soft threshold
                    weaveThreadMask = 1.0 - smoothstep(
                        _GapThreshold - _GapSoftness,
                        _GapThreshold + _GapSoftness,
                        weaveH);

                    // ★ Bump normal from screen-space height
                    //   derivatives (UDN blend onto base normal)
                    float dhdx = ddx(weaveH);
                    float dhdy = ddy(weaveH);
                    normalTS.xy += float2(-dhdx, -dhdy)
                                 * _WeaveNormalStrength;
                    normalTS = normalize(normalTS);

                    // ★ Thread edge darkening (cylindrical
                    //   self-shadow approximation)
                    float threadProfile = saturate(
                        1.0 - weaveH * 2.5);
                    albedo *= lerp(1.0 - _WeaveDarken,
                                   1.0,
                                   threadProfile);

                    // ★ Roughness: thread centers smoother,
                    //   gaps / edges rougher
                    roughness += _WeaveRoughnessVar
                               * (1.0 - weaveThreadMask);
                    roughness = clamp(roughness, 0.045, 1.0);
                }

                // ═══════════════════════════════════════════

                half3x3 tbnMatrix = half3x3(
                    IN.tangentWS.xyz,
                    IN.bitangentWS.xyz,
                    IN.normalWS.xyz);

                float3 normalWS = normalize(TransformTangentToWorld(normalTS, tbnMatrix));

                float3 tangentWS = normalize(IN.tangentWS.xyz
                    - normalWS * dot(normalWS, IN.tangentWS.xyz));

                float nov = max(dot(normalWS, viewDirWS), 0.0001);

                // ── Opacity ──────────────────────────────
                float opacity = _Opacity;

                if (_UseOpacityMap > 0)
                    opacity *= SAMPLE_TEXTURE2D(_OpacityMap, sampler_OpacityMap, uv).r;

                if (_UseVertexAlpha > 0)
                    opacity *= IN.vertexColor.a;

                // ★ Weave gap transparency: gaps let skin
                //   show through, threads stay at base opacity
                if (_UseProceduralWeave > 0)
                {
                    opacity *= lerp(_GapOpacity, 1.0, weaveThreadMask);
                }

                // Fresnel edge opacity: fabric looks more
                // opaque at grazing angles (more fiber layers)
                if (_FresnelOpacityStrength > 0)
                {
                    float edgeOpacity = pow(1.0 - nov, _FresnelOpacityPower)
                                      * _FresnelOpacityStrength;
                    opacity = saturate(opacity + edgeOpacity);
                }

                // ── Sample scene behind (the leg skin) ───
                float3 sceneColor = SampleSceneColor(screenUV);

                // Tint the see-through by fabric color
                float3 tintedScene = lerp(sceneColor,
                                          sceneColor * albedo * 2.0,
                                          _SeeThruTint);

                // ── F0 ───────────────────────────────────
                float  lum        = dot(_BaseColor.rgb, float3(0.3, 0.6, 0.1));
                float3 albedoTint = lum > 0 ? _BaseColor.rgb * rcp(lum) : (float3)1;
                float3 specTint   = lerp((float3)1, albedoTint, _SpecularTint)
                                  * _SpecularColor.rgb;
                float3 F0 = lerp(float3(_F0, _F0, _F0) * specTint, albedo, metallic);

                // ── IBL Energy Conservation ──────────────
                float3 kS = FresnelSchlickRoughness(nov, F0, roughness);
                float3 kD = (1.0 - kS) * (1.0 - metallic);

                // ── InputData for Baked GI ───────────────
                InputData inputData = (InputData)0;
                inputData.positionWS              = IN.positionWS;
                inputData.positionCS              = IN.positionCS;
                inputData.normalWS                = normalWS;
                inputData.viewDirectionWS         = viewDirWS;
                inputData.normalizedScreenSpaceUV = screenUV;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    inputData.vertexLighting = IN.vertexLighting.xyz;
                #else
                    inputData.vertexLighting = half3(0, 0, 0);
                #endif

                InitializeBakedGIData(IN, inputData);

                float2 ssao       = SampleSSAO(screenUV);
                float  indirectAO = min(ssao.y, ao);
                float3 bakedIrradiance = inputData.bakedGI * indirectAO;

                // ── Split-Sum BRDF & IBL ─────────────────
                float2 brdf   = EnvBRDFApprox(roughness, nov);
                float  envLOD = roughness * 6.0;

                float3 ibl = CalculateIBL(
                    normalWS, viewDirWS, IN.positionWS, screenUV,
                    albedo, roughness,
                    kS, kD,
                    brdf, envLOD,
                    bakedIrradiance);

                ibl *= ao;

                // ── Fabric Fuzz ──────────────────────────
                if (_FuzzIntensity > 0)
                {
                    float fuzzFresnel = pow(1.0 - nov, _FuzzPower);
                    float3 fuzz = _FuzzColor.rgb * _FuzzIntensity * fuzzFresnel;
                    float3 ambientLevel = max(bakedIrradiance, 0.05);
                    ibl += fuzz * ambientLevel * ao;
                }

                // ── Indirect Transmission ────────────────
                if (_Subsurface > 0 && _AmbientTransmission > 0)
                {
                    float3 backIrradiance = max(0, SampleSH(-normalWS));
                    float3 indirectTrans  = _Subsurface * _AmbientTransmission
                                          * _SubsurfaceColor.rgb
                                          * backIrradiance * rcp(PI);
                    ibl += indirectTrans * ao;
                }

                // ── Emission ─────────────────────────────
                float3 emission = _EnableEmission > 0
                    ? _EmissionColor.rgb : (float3)0;

                float sheenAlbedo = SheenDirectionalAlbedo(_Sheen, _SheenRoughness);

                // ══════════════════════════════════════════
                //  MAIN LIGHT
                // ══════════════════════════════════════════
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light  mainLight   = GetMainLight(shadowCoord);

                float  rawNdotL = dot(normalWS, mainLight.direction);
                float  nol      = saturate(rawNdotL);
                float  nolWrap  = saturate(
                    (rawNdotL + _DiffuseWrap) / (1.0 + _DiffuseWrap));

                float3 h   = normalize(viewDirWS + mainLight.direction);
                float  noh = max(dot(normalWS, h), 0.0);
                float  voh = max(dot(viewDirWS, h), 0.0);
                float  hol = max(dot(h, mainLight.direction), 0.0);

                float3 F_direct = FresnelSchlick(voh, F0);
                float  D_direct = DistributionGGXAnisotropic(
                    normalWS, tangentWS, h, roughness, anisotropy);
                float  G_direct = GeometrySmithSchlickGGX(nov, nol, roughness);
                float3 specular = (D_direct * G_direct * F_direct)
                                / max(4.0 * nov * nol, 0.001);

                float3 diffuse = (1.0 - F_direct) * (1.0 - metallic)
                               * (1.0 - sheenAlbedo) * albedo / PI;

                float3 sheen = EvaluateSheen(
                    _SheenColor.rgb, _Sheen, _SheenRoughness,
                    noh, nov, nol);

                float3 clearcoat = EvaluateClearcoat(
                    _ClearCoat, 1.0 - _ClearCoatRoughness,
                    noh, hol, nov, nol);

                float3 mainRadiance = mainLight.color * mainLight.shadowAttenuation;

                float3 mainLighting = diffuse * nolWrap * mainRadiance
                                    + (specular + sheen + clearcoat) * nol * mainRadiance;

                mainLighting += EvaluateTransmission(
                    normalWS, viewDirWS, mainLight.direction,
                    mainLight.color,
                    _Subsurface, _SubsurfaceColor.rgb,
                    _TransmissionDistortion, _TransmissionPower);

                // ══════════════════════════════════════════
                //  ADDITIONAL LIGHTS
                // ══════════════════════════════════════════
                float3 addLighting = 0;
                float4 shadowMask  = inputData.shadowMask;
                uint   pixelLightCount = GetAdditionalLightsCount();

                LIGHT_LOOP_BEGIN(pixelLightCount)
                    #if !USE_CLUSTER_LIGHT_LOOP
                        lightIndex = GetPerObjectLightIndex(lightIndex);
                    #endif

                    Light light = GetAdditionalLight(
                        lightIndex, IN.positionWS, shadowMask);

                    #if defined(_LIGHT_COOKIES)
                        light.color *= SampleAdditionalLightCookie(
                            lightIndex, IN.positionWS);
                    #endif

                    float  aRawNdotL = dot(normalWS, light.direction);
                    float  aNoL      = saturate(aRawNdotL);
                    float  aNoLWrap  = saturate(
                        (aRawNdotL + _DiffuseWrap) / (1.0 + _DiffuseWrap));

                    float3 aH   = normalize(viewDirWS + light.direction);
                    float  aNoH = max(dot(normalWS, aH), 0.0);
                    float  aVoH = saturate(dot(viewDirWS, aH));
                    float  aHoL = max(dot(aH, light.direction), 0.0);

                    float3 aF = FresnelSchlick(aVoH, F0);

                    float3 aSpec = EvaluateSpecular(
                        normalWS, viewDirWS, light.direction,
                        tangentWS, F0, roughness, anisotropy);

                    float3 aDiff = (1.0 - aF) * (1.0 - metallic)
                                 * (1.0 - sheenAlbedo) * albedo / PI;

                    float3 aSheen = EvaluateSheen(
                        _SheenColor.rgb, _Sheen, _SheenRoughness,
                        aNoH, nov, aNoL);

                    float3 aCC = EvaluateClearcoat(
                        _ClearCoat, 1.0 - _ClearCoatRoughness,
                        aNoH, aHoL, nov, aNoL);

                    float3 lightRad = light.color
                                    * light.distanceAttenuation
                                    * light.shadowAttenuation;

                    addLighting += aDiff * aNoLWrap * lightRad
                                 + (aSpec + aSheen + aCC) * aNoL * lightRad;

                    addLighting += EvaluateTransmission(
                        normalWS, viewDirWS, light.direction,
                        light.color * light.distanceAttenuation,
                        _Subsurface, _SubsurfaceColor.rgb,
                        _TransmissionDistortion, _TransmissionPower);
                LIGHT_LOOP_END

                // ══════════════════════════════════════════
                //  FINAL COMPOSITION
                // ══════════════════════════════════════════
                float3 fabricColor = ibl + mainLighting + addLighting + emission;
                fabricColor = MixFog(fabricColor, IN.fogFactor);

                // ── Blend fabric over the scene behind ───
                float3 finalColor = lerp(tintedScene, fabricColor, opacity);

                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // ═══════════════════════════════════════════════
        // Pass 1 : ShadowCaster
        // ═══════════════════════════════════════════════
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings ShadowVert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 norWS = TransformObjectToWorldNormal(IN.normalOS);

                float4 posCS = TransformWorldToHClip(
                    ApplyShadowBias(posWS, norWS, _LightDirection));

                #if UNITY_REVERSED_Z
                    posCS.z = min(posCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    posCS.z = max(posCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                OUT.positionCS = posCS;
                return OUT;
            }

            half4 ShadowFrag(Varyings IN) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }

        // ═══════════════════════════════════════════════
        // Pass 2 : DepthOnly
        // ═══════════════════════════════════════════════
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings DepthVert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half DepthFrag(Varyings IN) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Lit"
}