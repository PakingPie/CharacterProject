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

        [Header(Sheen  (velvet  felt  not nylon))]
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

        [Header(Fabric Fuzz  (cotton  not nylon))]
        _FuzzIntensity("Fuzz Intensity", Range(0, 1)) = 0.0
        _FuzzColor("Fuzz Color", Color) = (0.5, 0.5, 0.5, 1)
        _FuzzPower("Fuzz Power", Range(1, 8)) = 3.0

        [Header(Procedural Knit)]
        [Toggle] _UseProceduralKnit("Enable Procedural Knit", Float) = 0
        _KnitUVTiling("UV Tiling Multiplier", Float) = 1.0
        _NumberOfLoops("Loop Count (per UV)", Float) = 40
        _LoopAspect("Loop Height over Width", Range(0.5, 2.5)) = 1.3
        _OpeningSize("Opening Radius", Range(0.01, 0.45)) = 0.12
        _OpeningSoftness("Opening Edge Softness", Range(0.005, 0.3)) = 0.08
        _GapOpacity("Gap Min Opacity", Range(0, 1)) = 0.1
        _KnitNormalStrength("Knit Bump Strength", Range(0, 10)) = 1.5
        _KnitRoughnessVar("Thread Roughness Variation", Range(0, 0.3)) = 0.08
        _ThreadDarken("Thread Edge Darkening", Range(0, 1)) = 0.12
        _KnitJitter("Opening Position Jitter", Range(0, 0.15)) = 0.02
        _KnitNoiseScale("Fiber Noise Scale", Float) = 10

        _GapEdgeHighlight("Gap Edge Specular Boost", Range(0, 3)) = 0.8

        _KnitFadeStart("Moire Fade Start (cells per px)", Range(0.01, 1.0)) = 0.2
        _KnitFadeEnd("Moire Fade End   (cells per px)", Range(0.1, 2.0)) = 0.7

        [Header(Stretch Transparency)]
        _StretchTransparency("Stretch to Transparency", Range(0, 2)) = 0.5
        _StretchOpeningGrow("Stretch to Opening Grow", Range(0, 3)) = 1.5
        _StretchReference("Rest-State World per UV", Float) = 0.01
        [Toggle] _UseStretchFromVertexG("Override: Vertex Green = Stretch", Float) = 0

        [Header(Two Layer Silhouette)]
        _TwoLayerDarkening("Edge Layer Darkening", Range(0, 1)) = 0.4
        _TwoLayerPower("Edge Power", Range(1, 8)) = 3.0
        _TwoLayerSaturation("Edge Saturation Boost", Range(0, 1)) = 0.25

        [Header(Denier Variation)]
        [Toggle] _UseDenierFromVertexR("Vertex Red = Denier Opacity", Float) = 0
        _DenierMin("Min Denier Opacity", Range(0, 1)) = 0.3
        _DenierMax("Max Denier Opacity", Range(0, 1)) = 1.0

        [Header(Clearcoat)]
        _ClearCoat("Clear Coat", Range(0,10)) = 0.0
        _ClearCoatRoughness("Clear Coat Roughness", Range(0,1)) = 0.5

        [Header(Transparency)]
        _Opacity("Base Opacity", Range(0, 1)) = 1.0
        _ShadowDensity("Shadow Density", Range(0, 2)) = 1.0
        [Toggle] _ForwardZWrite("Forward Depth Write (Transparent)", Float) = 0
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
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent" "Queue" = "Transparent" }

        // ═══════════════════════════════════════════════
        // Pass 0 : ForwardLit
        // ═══════════════════════════════════════════════
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite [_ForwardZWrite]
            ZTest LEqual

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "FabricPBR_Common.hlsl"    // ★ shared CBUFFER

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

            // ── Texture / Sampler Declarations ───────────
            TEXTURE2D(_MainTex);          SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);         SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicMap);       SAMPLER(sampler_MetallicMap);
            TEXTURE2D(_RoughnessMap);      SAMPLER(sampler_RoughnessMap);
            TEXTURE2D(_AOMap);             SAMPLER(sampler_AOMap);
            TEXTURE2D(_AnisotropyMap);     SAMPLER(sampler_AnisotropyMap);
            TEXTURE2D(_HeightMap);         SAMPLER(sampler_HeightMap);
            TEXTURE2D(_OpacityMap);        SAMPLER(sampler_OpacityMap);
            TEXTURECUBE(_CustomCubemap);   SAMPLER(sampler_CustomCubemap);

            // ★ CBUFFER removed from here — now in FabricPBR_Common.hlsl

            // ── Structs ──────────────────────────────────
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

            // ── Vertex Shader ────────────────────────────
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

            // ── Baked GI ─────────────────────────────────
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

            // ── SSAO ─────────────────────────────────────
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

            // ── Parallax ─────────────────────────────────
            float2 ParallaxOffset(float2 uv, float3 viewDirTS)
            {
                float h = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
                return uv + viewDirTS.xy / (viewDirTS.z + 0.42) * (h * _HeightScale);
            }

            // ── IBL ──────────────────────────────────────
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

            // ── BRDF Utilities ───────────────────────────
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

            // ── Anisotropic GGX NDF ─────────────────────
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

            // ── Smith-Schlick-GGX Geometry ───────────────
            float GeometrySmithSchlickGGX(float NoV, float NoL, float roughness)
            {
                float r1     = roughness + 1.0;
                float k      = max((r1 * r1) / 8.0, 0.0001);
                float smithV = NoV * rcp(NoV * (1.0 - k) + k);
                float smithL = NoL * rcp(NoL * (1.0 - k) + k);
                return smithV * smithL;
            }

            // ── Sheen ────────────────────────────────────
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

            // ── Clearcoat ────────────────────────────────
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

            // ── Cook-Torrance Specular ───────────────────
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

            // ── Subsurface Transmission ──────────────────
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
            // PROCEDURAL KNIT FUNCTIONS
            // ══════════════════════════════════════════════

            void FabricHash_uint(uint2 v, out uint o)
            {
                v.y ^= 1103515245U;
                v.x += v.y;
                v.x *= v.y;
                v.x ^= v.x >> 5u;
                v.x *= 0x27d4eb2du;
                o = v.x;
            }

            void FabricHash_float(float2 i, out float o)
            {
                uint r;
                uint2 v = (uint2)(int2)round(i);
                FabricHash_uint(v, r);
                o = (r >> 8) * (1.0 / float(0x00ffffff));
            }

            float FabricNoiseValue(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);

                float r0; FabricHash_float(i + float2(0, 0), r0);
                float r1; FabricHash_float(i + float2(1, 0), r1);
                float r2; FabricHash_float(i + float2(0, 1), r2);
                float r3; FabricHash_float(i + float2(1, 1), r3);

                return lerp(lerp(r0, r1, f.x),
                            lerp(r2, r3, f.x), f.y);
            }

            float FabricNoise2Oct(float2 UV, float Scale)
            {
                float noise = 0.0;
                noise += FabricNoiseValue(UV * (Scale * 0.25)) * 0.667;
                noise += FabricNoiseValue(UV * (Scale * 0.5))  * 0.333;
                return noise;
            }

            float4 EvaluateKnit(float2 scaledUV, float stretchMod, float adaptiveSoftness)
            {
                float openSize = _OpeningSize * stretchMod;

                float minDist    = 100.0;
                float2 bestOff   = 0;
                float2 bestCell  = 0;

                float colBase = floor(scaledUV.x);

                [unroll]
                for (int dc = -1; dc <= 1; dc++)
                {
                    float col     = colBase + (float)dc;
                    float stagger = fmod(abs(col), 2.0) * 0.5;
                    float adjY    = scaledUV.y - stagger;
                    float rowBase = floor(adjY);

                    [unroll]
                    for (int dr = 0; dr <= 1; dr++)
                    {
                        float row    = rowBase + (float)dr;
                        float2 cid   = float2(col, row);

                        float jx, jy;
                        FabricHash_float(cid,                        jx);
                        FabricHash_float(cid + float2(127.1, 311.7), jy);
                        float2 jitter = (float2(jx, jy) - 0.5) * _KnitJitter;

                        float2 centre = float2(col + 0.5,
                                               row + 0.5 + stagger)
                                      + jitter;

                        float2 diff     = scaledUV - centre;
                        float2 aspDiff  = diff * float2(1.0, 1.0 / _LoopAspect);
                        float  d        = length(aspDiff);

                        if (d < minDist)
                        {
                            minDist  = d;
                            bestOff  = diff;
                            bestCell = cid;
                        }
                    }
                }

                float threadMask = smoothstep(openSize - adaptiveSoftness,
                                              openSize + adaptiveSoftness,
                                              minDist);

                float edgeMask = exp(-pow((minDist - openSize) / max(adaptiveSoftness * 0.7, 0.001), 2.0));

                float waleP   = 0.5 + 0.5 * cos(bestOff.x * PI * 2.0);
                float courseP = 0.5 + 0.5 * cos(bestOff.y * PI * 2.0 / _LoopAspect);
                float profile = lerp(max(waleP, courseP),
                                     waleP * courseP, 0.4);

                float cellVar;
                FabricHash_float(bestCell + float2(42.0, 73.0), cellVar);
                cellVar = lerp(0.88, 1.0, cellVar);

                float height = threadMask * (0.15 + 0.85 * profile) * cellVar;

                float microNoise = FabricNoise2Oct(scaledUV * 3.0, _KnitNoiseScale);
                height += (microNoise * 2.0 - 1.0) * 0.03 * threadMask;

                return float4(saturate(height), threadMask, edgeMask, 0);
            }

            float InterleavedGradientNoise(float2 screenPos)
            {
                float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
                return frac(magic.z * frac(dot(screenPos, magic.xy)));
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

                // ── Normal ───────────────────────────────
                half3 normalTS = half3(0, 0, 1);
                if (_UseNormalMap > 0)
                {
                    normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv));
                    normalTS.xy *= _NormalStrength;
                    normalTS = normalize(normalTS);
                }

                // ══════════════════════════════════════════
                //   PROCEDURAL KNIT INTEGRATION
                // ══════════════════════════════════════════
                float knitThreadMask = 1.0;
                float knitEdgeMask   = 0.0;
                float stretchAmount  = 0.0;
                float knitAvgThread  = 1.0;

                if (_UseProceduralKnit > 0)
                {
                    float2 knitUV     = uv * _KnitUVTiling;
                    float  evenLoops  = ceil(_NumberOfLoops * 0.5) * 2.0;
                    float2 scaledKnit = knitUV * evenLoops;

                    float2 dKdx = ddx(scaledKnit);
                    float2 dKdy = ddy(scaledKnit);
                    float  knitCoverage  = max(length(dKdx), length(dKdy));

                    float adaptiveSoftness = _OpeningSoftness
                                           + saturate(knitCoverage * 0.25) * 0.12;

                    float fadeSpan = max(_KnitFadeEnd - _KnitFadeStart, 1e-4);
                    float t        = saturate((knitCoverage - _KnitFadeStart) / fadeSpan);

                    // Two-stage anti-moire transition:
                    // 1) Early gentle prefilter to avoid abrupt onset
                    // 2) Later stronger filtering for heavy minification
                    float prefilterSoft  = smoothstep(0.0, 0.75, t);
                    float prefilterStrong = smoothstep(0.25, 1.0, t);

                    float bumpFade        = lerp(1.0, 0.12, prefilterStrong);
                    float detailRetention = lerp(1.0, 0.22, prefilterSoft);
                    float colorRetention  = lerp(1.0, 0.32, prefilterSoft);

                    float openArea = PI * _OpeningSize * _OpeningSize * _LoopAspect;
                    float cellArea = _LoopAspect;
                    knitAvgThread = saturate(1.0 - openArea / cellArea);

                    float3 dPdx_ws = ddx(IN.positionWS);
                    float3 dPdy_ws = ddy(IN.positionWS);
                    float  worldPixArea = length(cross(dPdx_ws, dPdy_ws));

                    float2 dUVdx = ddx(uv);
                    float2 dUVdy = ddy(uv);
                    float  uvPixArea = abs(dUVdx.x * dUVdy.y - dUVdx.y * dUVdy.x);
                    float  worldPerUV = sqrt(worldPixArea / max(uvPixArea, 1e-10));

                    if (_UseStretchFromVertexG > 0)
                    {
                        stretchAmount = IN.vertexColor.g;
                    }
                    else
                    {
                        float stretchRatio = worldPerUV / max(_StretchReference, 1e-6);
                        stretchAmount = saturate((stretchRatio - 1.0) * _StretchTransparency);
                    }

                    float stretchMod = lerp(1.0, 1.0 + _StretchOpeningGrow, stretchAmount);

                    float4 knit = EvaluateKnit(scaledKnit, stretchMod, adaptiveSoftness);

                    if (prefilterSoft > 0.001)
                    {
                        float2 dx = dKdx;
                        float2 dy = dKdy;

                        float filterRadius = lerp(0.2, 1.0, prefilterSoft);

                        float2 o1 = (dx + dy) * filterRadius;
                        float2 o2 = (dx - dy) * filterRadius;

                        float4 k1 = EvaluateKnit(scaledKnit + o1, stretchMod, adaptiveSoftness);
                        float4 k2 = EvaluateKnit(scaledKnit - o1, stretchMod, adaptiveSoftness);
                        float4 k3 = EvaluateKnit(scaledKnit + o2, stretchMod, adaptiveSoftness);
                        float4 k4 = EvaluateKnit(scaledKnit - o2, stretchMod, adaptiveSoftness);

                        float4 knitAvg = (knit + k1 + k2 + k3 + k4) * 0.2;
                        knit = lerp(knit, knitAvg, prefilterSoft);
                    }

                    float knitH = knit.x;
                    knitThreadMask = knit.y;
                    knitEdgeMask   = knit.z;

                    knitThreadMask = lerp(knitAvgThread, knitThreadMask, detailRetention);
                    knitEdgeMask  *= detailRetention;

                    float dhdx = ddx(knitH);
                    float dhdy = ddy(knitH);

                    float maxDeriv = lerp(0.15, 0.5, bumpFade);
                    dhdx = clamp(dhdx, -maxDeriv, maxDeriv);
                    dhdy = clamp(dhdy, -maxDeriv, maxDeriv);

                    normalTS.xy += float2(-dhdx, -dhdy)
                                 * _KnitNormalStrength
                                 * bumpFade;
                    normalTS = normalize(normalTS);

                    float threadProfile = saturate(1.0 - knitH * 2.5);
                    float darkening = lerp(1.0 - _ThreadDarken, 1.0, threadProfile);
                    albedo *= lerp(1.0, darkening, colorRetention);

                    roughness += _KnitRoughnessVar * (1.0 - knitThreadMask) * detailRetention;
                    roughness = clamp(roughness, 0.045, 1.0);
                }

                half3x3 tbnMatrix = half3x3(
                    IN.tangentWS.xyz,
                    IN.bitangentWS.xyz,
                    IN.normalWS.xyz);

                float3 normalWS = normalize(
                    TransformTangentToWorld(normalTS, tbnMatrix));

                float3 tangentWS = normalize(IN.tangentWS.xyz
                    - normalWS * dot(normalWS, IN.tangentWS.xyz));

                float nov = max(dot(normalWS, viewDirWS), 0.0001);

                // ══════════════════════════════════════════
                // Opacity pipeline
                // ══════════════════════════════════════════
                float opacity = _Opacity;

                if (_UseOpacityMap > 0)
                    opacity *= SAMPLE_TEXTURE2D(_OpacityMap, sampler_OpacityMap, uv).r;

                if (_UseVertexAlpha > 0)
                    opacity *= IN.vertexColor.a;

                if (_UseDenierFromVertexR > 0)
                {
                    float denier = lerp(_DenierMin, _DenierMax,
                                        IN.vertexColor.r);
                    opacity *= denier;
                }

                if (_UseProceduralKnit > 0)
                {
                    float gapTransparency = lerp(_GapOpacity, 1.0, knitThreadMask);
                    opacity *= gapTransparency;
                }

                if (_UseProceduralKnit > 0)
                {
                    float stretchOpacity = lerp(1.0, 0.5, stretchAmount);
                    opacity *= stretchOpacity;
                }

                if (_FresnelOpacityStrength > 0)
                {
                    float edgeOpacity = pow(1.0 - nov, _FresnelOpacityPower)
                                      * _FresnelOpacityStrength;
                    opacity = saturate(opacity + edgeOpacity);
                }

                float twoLayerGrazing = 0.0;
                if (_TwoLayerDarkening > 0)
                {
                    float grazing = pow(1.0 - nov, _TwoLayerPower);
                    twoLayerGrazing = grazing * _TwoLayerDarkening;

                    float layerMul = twoLayerGrazing;
                    float transmittance = pow(max(1.0 - opacity, 0.001),
                                              1.0 + layerMul);
                    opacity = 1.0 - transmittance;
                }

                // ── Sample scene behind (skin) ───────────
                float3 sceneColor = SampleSceneColor(screenUV);

                float3 tintedScene = lerp(sceneColor,
                                          sceneColor * albedo * 2.0,
                                          _SeeThruTint);

                if (_TwoLayerDarkening > 0)
                {
                    float  extraTint = twoLayerGrazing * _TwoLayerSaturation;
                    tintedScene = lerp(tintedScene,
                                       tintedScene * albedo,
                                       extraTint);
                }

                // ── F0 ───────────────────────────────────
                float  lum        = dot(_BaseColor.rgb, float3(0.3, 0.6, 0.1));
                float3 albedoTint = lum > 0 ? _BaseColor.rgb * rcp(lum) : (float3)1;
                float3 specTint   = lerp((float3)1, albedoTint, _SpecularTint)
                                  * _SpecularColor.rgb;
                float3 F0 = lerp(float3(_F0, _F0, _F0) * specTint, albedo, metallic);

                float3 kS = FresnelSchlickRoughness(nov, F0, roughness);
                float3 kD = (1.0 - kS) * (1.0 - metallic);

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

                float2 brdf   = EnvBRDFApprox(roughness, nov);
                float  envLOD = roughness * 6.0;

                float3 ibl = CalculateIBL(
                    normalWS, viewDirWS, IN.positionWS, screenUV,
                    albedo, roughness,
                    kS, kD,
                    brdf, envLOD,
                    bakedIrradiance);

                ibl *= ao;

                if (_FuzzIntensity > 0)
                {
                    float fuzzFresnel = pow(1.0 - nov, _FuzzPower);
                    float3 fuzz = _FuzzColor.rgb * _FuzzIntensity * fuzzFresnel;
                    float3 ambientLevel = max(bakedIrradiance, 0.05);
                    ibl += fuzz * ambientLevel * ao;
                }

                if (_Subsurface > 0 && _AmbientTransmission > 0)
                {
                    float3 backIrradiance = max(0, SampleSH(-normalWS));
                    float3 indirectTrans  = _Subsurface * _AmbientTransmission
                                          * _SubsurfaceColor.rgb
                                          * backIrradiance * rcp(PI);
                    ibl += indirectTrans * ao;
                }

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

                if (_UseProceduralKnit > 0 && _GapEdgeHighlight > 0)
                {
                    float edgeNdH  = pow(noh, 4.0);
                    float edgeSpec = knitEdgeMask * _GapEdgeHighlight
                                   * (edgeNdH * 0.7 + 0.3 * nol);
                    mainLighting += edgeSpec * mainRadiance;
                }

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

                    if (_UseProceduralKnit > 0 && _GapEdgeHighlight > 0)
                    {
                        float aEdge = knitEdgeMask * _GapEdgeHighlight
                                    * (pow(aNoH, 4.0) * 0.7 + 0.3 * aNoL);
                        addLighting += aEdge * lightRad;
                    }

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

                if (_TwoLayerDarkening > 0)
                {
                    float edgeDarken = 1.0 - twoLayerGrazing * 0.35;
                    fabricColor *= edgeDarken;
                }

                fabricColor = MixFog(fabricColor, IN.fogFactor);

                float3 finalColor = lerp(tintedScene, fabricColor, opacity);

                return float4(finalColor, saturate(opacity));
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
            Cull Back    // ★ Match ForwardLit

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "FabricPBR_Common.hlsl"    // ★ SAME CBUFFER

            float3 _LightDirection;

            TEXTURE2D(_MainTex);       SAMPLER(sampler_MainTex);
            TEXTURE2D(_OpacityMap);    SAMPLER(sampler_OpacityMap);

            // ★ NO CBUFFER HERE — it's in the include

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 texcoord   : TEXCOORD0;
                float4 color      : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float4 vertexColor: TEXCOORD2;
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
                OUT.uv = TRANSFORM_TEX(IN.texcoord, _MainTex) * _TextureTiling.xy;
                OUT.positionWS = posWS;
                OUT.vertexColor = IN.color;
                return OUT;
            }

            float ShadowHash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float ComputeShadowStretchAmount(Varyings IN)
            {
                if (_UseStretchFromVertexG > 0)
                    return saturate(IN.vertexColor.g);

                float3 dPdx_ws = ddx(IN.positionWS);
                float3 dPdy_ws = ddy(IN.positionWS);
                float  worldPixArea = length(cross(dPdx_ws, dPdy_ws));

                float2 dUVdx = ddx(IN.uv);
                float2 dUVdy = ddy(IN.uv);
                float  uvPixArea = abs(dUVdx.x * dUVdy.y - dUVdx.y * dUVdy.x);
                float  worldPerUV = sqrt(worldPixArea / max(uvPixArea, 1e-10));

                float stretchRatio = worldPerUV / max(_StretchReference, 1e-6);
                return saturate((stretchRatio - 1.0) * _StretchTransparency);
            }

            float EvaluateShadowKnitMask(float2 uv, float stretchAmount)
            {
                float2 knitUV = uv * _KnitUVTiling;
                float  evenLoops = max(2.0, ceil(_NumberOfLoops * 0.5) * 2.0);
                float2 scaled = knitUV * evenLoops;

                float2 dKdx = ddx(scaled);
                float2 dKdy = ddy(scaled);
                float  knitCoverage = max(length(dKdx), length(dKdy));

                float adaptiveSoftness = _OpeningSoftness
                                       + saturate(knitCoverage * 0.25) * 0.12;

                float stretchMod = lerp(1.0, 1.0 + _StretchOpeningGrow, stretchAmount);
                float openSize = _OpeningSize * stretchMod;

                float minDist = 100.0;
                float colBase = floor(scaled.x);

                [unroll]
                for (int dc = -1; dc <= 1; dc++)
                {
                    float col = colBase + (float)dc;
                    float stagger = fmod(abs(col), 2.0) * 0.5;
                    float adjY = scaled.y - stagger;
                    float rowBase = floor(adjY);

                    [unroll]
                    for (int dr = 0; dr <= 1; dr++)
                    {
                        float row = rowBase + (float)dr;
                        float2 cid = float2(col, row);

                        float jx = ShadowHash(cid + float2(0.0, 0.0));
                        float jy = ShadowHash(cid + float2(53.0, 97.0));
                        float2 jitter = (float2(jx, jy) - 0.5) * _KnitJitter;

                        float2 center = float2(col + 0.5, row + 0.5 + stagger) + jitter;
                        float2 diff = scaled - center;
                        float2 aspDiff = diff * float2(1.0, 1.0 / max(_LoopAspect, 0.001));
                        float dist = length(aspDiff);
                        minDist = min(minDist, dist);
                    }
                }

                return smoothstep(
                    openSize - adaptiveSoftness,
                    openSize + adaptiveSoftness,
                    minDist);
            }

            half4 ShadowFrag(Varyings IN) : SV_TARGET
            {
                float opacity;

                if (_UseProceduralKnit > 0)
                {
                    float stretchAmount = ComputeShadowStretchAmount(IN);
                    float threadMask = EvaluateShadowKnitMask(IN.uv, stretchAmount);
                    opacity = lerp(_GapOpacity, 1.0, threadMask);
                }
                else
                {
                    opacity = _Opacity * _BaseColor.a;
                    if (_UseOpacityMap > 0)
                        opacity *= SAMPLE_TEXTURE2D(_OpacityMap, sampler_OpacityMap, IN.uv).r;
                }

                if (_UseVertexAlpha > 0)
                    opacity *= IN.vertexColor.a;

                if (_UseDenierFromVertexR > 0)
                    opacity *= lerp(_DenierMin, _DenierMax, IN.vertexColor.r);

                opacity = saturate(opacity * _ShadowDensity);

                // World-stable stochastic clip to avoid view/cascade swimming
                float dither = StableDitherWS(IN.positionWS);
                clip(opacity - dither);

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
            Cull Back    // ★ Match ForwardLit

            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "FabricPBR_Common.hlsl"    // ★ SAME CBUFFER

            TEXTURE2D(_OpacityMap); SAMPLER(sampler_OpacityMap);
            TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);

            // ★ NO CBUFFER HERE — it's in the include

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord   : TEXCOORD0;
                float4 color      : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float4 vertexColor: TEXCOORD2;
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
                OUT.uv = TRANSFORM_TEX(IN.texcoord, _MainTex) * _TextureTiling.xy;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.vertexColor = IN.color;
                return OUT;
            }

            float DepthHash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float ComputeDepthStretchAmount(Varyings IN)
            {
                if (_UseStretchFromVertexG > 0)
                    return saturate(IN.vertexColor.g);

                float3 dPdx_ws = ddx(IN.positionWS);
                float3 dPdy_ws = ddy(IN.positionWS);
                float  worldPixArea = length(cross(dPdx_ws, dPdy_ws));

                float2 dUVdx = ddx(IN.uv);
                float2 dUVdy = ddy(IN.uv);
                float  uvPixArea = abs(dUVdx.x * dUVdy.y - dUVdx.y * dUVdy.x);
                float  worldPerUV = sqrt(worldPixArea / max(uvPixArea, 1e-10));

                float stretchRatio = worldPerUV / max(_StretchReference, 1e-6);
                return saturate((stretchRatio - 1.0) * _StretchTransparency);
            }

            float EvaluateDepthKnitMask(float2 uv, float stretchAmount)
            {
                float2 knitUV = uv * _KnitUVTiling;
                float  evenLoops = max(2.0, ceil(_NumberOfLoops * 0.5) * 2.0);
                float2 scaled = knitUV * evenLoops;

                float2 dKdx = ddx(scaled);
                float2 dKdy = ddy(scaled);
                float  knitCoverage = max(length(dKdx), length(dKdy));

                float adaptiveSoftness = _OpeningSoftness
                                       + saturate(knitCoverage * 0.25) * 0.12;

                float stretchMod = lerp(1.0, 1.0 + _StretchOpeningGrow, stretchAmount);
                float openSize = _OpeningSize * stretchMod;

                float minDist = 100.0;
                float colBase = floor(scaled.x);

                [unroll]
                for (int dc = -1; dc <= 1; dc++)
                {
                    float col = colBase + (float)dc;
                    float stagger = fmod(abs(col), 2.0) * 0.5;
                    float adjY = scaled.y - stagger;
                    float rowBase = floor(adjY);

                    [unroll]
                    for (int dr = 0; dr <= 1; dr++)
                    {
                        float row = rowBase + (float)dr;
                        float2 cid = float2(col, row);

                        float jx = DepthHash(cid + float2(0.0, 0.0));
                        float jy = DepthHash(cid + float2(53.0, 97.0));
                        float2 jitter = (float2(jx, jy) - 0.5) * _KnitJitter;

                        float2 center = float2(col + 0.5, row + 0.5 + stagger) + jitter;
                        float2 diff = scaled - center;
                        float2 aspDiff = diff * float2(1.0, 1.0 / max(_LoopAspect, 0.001));
                        float dist = length(aspDiff);
                        minDist = min(minDist, dist);
                    }
                }

                return smoothstep(
                    openSize - adaptiveSoftness,
                    openSize + adaptiveSoftness,
                    minDist);
            }

            half DepthFrag(Varyings IN) : SV_TARGET
            {
                float opacity;

                if (_UseProceduralKnit > 0)
                {
                    float stretchAmount = ComputeDepthStretchAmount(IN);
                    float threadMask = EvaluateDepthKnitMask(IN.uv, stretchAmount);
                    opacity = lerp(_GapOpacity, 1.0, threadMask);
                }
                else
                {
                    opacity = _Opacity * _BaseColor.a;
                    if (_UseOpacityMap > 0)
                        opacity *= SAMPLE_TEXTURE2D(_OpacityMap, sampler_OpacityMap, IN.uv).r;
                }

                if (_UseVertexAlpha > 0)
                    opacity *= IN.vertexColor.a;

                if (_UseDenierFromVertexR > 0)
                    opacity *= lerp(_DenierMin, _DenierMax, IN.vertexColor.r);

                opacity = saturate(opacity * _ShadowDensity);

                float dither = StableDitherWS(IN.positionWS);
                clip(opacity - dither);
                return 0;
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Lit"
}