Shader "Custom/BasePBR"
{
    Properties
    {
        [Header(Main Color)]
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)

        [Header(Normal Map)]
        [Toggle(_USE_NORMAL_MAP)] _UseNormalMap("Use Normal Map", Float) = 0
        _NormalMap("Normal Map", 2D) = "bump" {}

        [Header(Metallic)]
        _Metallic("Metallic", Range(0,1)) = 0.0
        [Toggle(_USE_METALLIC_MAP)] _UseMetallicMap("Use Metallic Map", Float) = 0
        _MetallicMap("Metallic Map", 2D) = "white" {}

        [Header(Roughness)]
        _Roughness("Roughness (perceptual)", Range(0,1)) = 0.5
        [Toggle(_USE_ROUGHNESS_MAP)] _UseRoughnessMap("Use Roughness Map", Float) = 0
        _RoughnessMap("Roughness Map", 2D) = "white" {}

        [Header(Ambient Occlusion)]
        _AmbientOcclusion("Ambient Occlusion", Range(0,1)) = 1.0
        [Toggle(_USE_AO_MAP)] _UseAOMap("Use AO Map", Float) = 0
        _AOMap("AO Map (G channel)", 2D) = "white" {}

        [Header(Anisotropy)]
        _Anisotropy("Anisotropy", Range(0,1)) = 0.0
        _AnisotropicRotation("Anisotropic Rotation", Range(0,1)) = 0.0
        [Toggle(_USE_ANISOTROPY_MAP)] _UseAnisotropyMap("Use Anisotropy Map", Float) = 0
        _AnisotropyMap("Anisotropy Map", 2D) = "white" {}

        [Header(Specular Tint)]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularTint("Specular Tint (Disney)", Range(0,1)) = 0.0

        [Header(Emission)]
        _EmissionColor("Emission Color", Color) = (0,0,0,1)
        [Toggle(_ENABLE_EMISSION)] _EnableEmission("Enable Emission", Float) = 0

        [Header(Height Map / Parallax)]
        [Toggle(_USE_HEIGHT_MAP)] _UseHeightMap("Use Height Map", Float) = 0
        _HeightMap("Height Map (R)", 2D) = "black" {}
        _HeightScale("Height Scale", Range(0, 0.1)) = 0.02

        [Header(Advanced Options)]
        _F0("Dielectric F0", Range(0,1)) = 0.04
        _ClearCoat("Clear Coat", Range(0,1)) = 0.0
        _ClearCoatRoughness("Clear Coat Roughness (perceptual)", Range(0,1)) = 0.5
        _Sheen("Sheen", Range(0,1)) = 0.0
        _SheenColor("Sheen Color", Color) = (1,1,1,1)
        _SheenTint("Sheen Tint (Disney)", Range(0,1)) = 0.5
        _TextureTiling("Texture Tiling", Vector) = (1,1,0,0)

        [Header(Reflection)]
        [Toggle(_USE_REFLECTIVE_PROBE)] _UseReflectiveProbe("Use Reflective Probe", Float) = 0
        [Toggle(_USE_CUSTOM_CUBEMAP)] _UseCustomCubemap("Use Custom Cubemap", Float) = 0
        _CustomCubemap("Custom Cubemap", Cube) = "" {}
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }

        // Shared CBUFFER + texture decls available to every pass.
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float  _Metallic;
                float  _Roughness;
                float  _AmbientOcclusion;
                float  _Anisotropy;
                float  _AnisotropicRotation;
                float4 _SpecularColor;
                float  _SpecularTint;
                float4 _EmissionColor;
                float  _EnableEmission;
                float  _F0;
                float  _ClearCoat;
                float  _ClearCoatRoughness;
                float  _Sheen;
                float4 _SheenColor;
                float  _SheenTint;
                float4 _TextureTiling;
                float4 _MainTex_ST;
                float  _HeightScale;

                // Toggles kept in CBUFFER for SRP-batcher compatibility.
                float  _UseReflectiveProbe;
                float  _UseCustomCubemap;
                float  _UseNormalMap;
                float  _UseMetallicMap;
                float  _UseRoughnessMap;
                float  _UseAOMap;
                float  _UseAnisotropyMap;
                float  _UseHeightMap;
            CBUFFER_END

            TEXTURE2D(_MainTex);         SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);       SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicMap);     SAMPLER(sampler_MetallicMap);
            TEXTURE2D(_RoughnessMap);    SAMPLER(sampler_RoughnessMap);
            TEXTURE2D(_AOMap);           SAMPLER(sampler_AOMap);
            TEXTURE2D(_AnisotropyMap);   SAMPLER(sampler_AnisotropyMap);
            TEXTURE2D(_HeightMap);       SAMPLER(sampler_HeightMap);
            TEXTURECUBE(_CustomCubemap); SAMPLER(sampler_CustomCubemap);
        ENDHLSL

        // ─────────────────────────────────────────────────────────────
        // Forward Lit
        // ─────────────────────────────────────────────────────────────
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Material features
            #pragma shader_feature_local _USE_NORMAL_MAP
            #pragma shader_feature_local _USE_METALLIC_MAP
            #pragma shader_feature_local _USE_ROUGHNESS_MAP
            #pragma shader_feature_local _USE_AO_MAP
            #pragma shader_feature_local _USE_ANISOTROPY_MAP
            #pragma shader_feature_local _USE_HEIGHT_MAP
            #pragma shader_feature_local _USE_REFLECTIVE_PROBE
            #pragma shader_feature_local _USE_CUSTOM_CUBEMAP
            #pragma shader_feature_local _ENABLE_EMISSION

            // URP forward keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP

            // GI / lightmap
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ USE_APV_PROBE_OCCLUSION
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile _ PROBE_VOLUMES_L1 PROBE_VOLUMES_L2

            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS        : POSITION;
                float3 normalOS          : NORMAL;
                float4 tangentOS         : TANGENT;
                float2 texcoord          : TEXCOORD0;
                float2 staticLightmapUV  : TEXCOORD1;
                float2 dynamicLightmapUV : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 positionWS  : TEXCOORD1;
                float4 normalWS    : TEXCOORD2;   // xyz: N,  w: viewDir.x
                float4 tangentWS   : TEXCOORD3;   // xyz: T,  w: viewDir.y
                float4 bitangentWS : TEXCOORD4;   // xyz: B,  w: viewDir.z

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half3  vertexLighting : TEXCOORD5;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord    : TEXCOORD6;
                #endif

                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);

                #ifdef DYNAMICLIGHTMAP_ON
                    float2 dynamicLightmapUV : TEXCOORD8;
                #endif

                #ifdef USE_APV_PROBE_OCCLUSION
                    float4 probeOcclusion : TEXCOORD9;
                #endif

                float fogFactor    : TEXCOORD10;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vIn = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nIn = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.uv         = TRANSFORM_TEX(IN.texcoord, _MainTex) * _TextureTiling.xy;
                OUT.positionWS = vIn.positionWS;
                OUT.positionCS = vIn.positionCS;

                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(vIn.positionWS);
                OUT.normalWS    = float4(nIn.normalWS,    viewDirWS.x);
                OUT.tangentWS   = float4(nIn.tangentWS,   viewDirWS.y);
                OUT.bitangentWS = float4(nIn.bitangentWS, viewDirWS.z);

                OUTPUT_LIGHTMAP_UV(IN.staticLightmapUV, unity_LightmapST, OUT.staticLightmapUV);
                #ifdef DYNAMICLIGHTMAP_ON
                    OUT.dynamicLightmapUV = IN.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                OUTPUT_SH4(vIn.positionWS, OUT.normalWS.xyz, viewDirWS, OUT.vertexSH, OUT.probeOcclusion);

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    OUT.vertexLighting = VertexLighting(vIn.positionWS, nIn.normalWS);
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    OUT.shadowCoord = GetShadowCoord(vIn);
                #endif

                OUT.fogFactor = ComputeFogFactor(vIn.positionCS.z);
                return OUT;
            }

            // ============================================================
            //                Disney Principled BRDF helpers
            // ============================================================

            // Karis env-BRDF LUT approximation (split-sum)
            float2 EnvBRDFApprox(float roughness, float NoV)
            {
                const float4 c0 = float4(-1.0, -0.0275, -0.572,  0.022);
                const float4 c1 = float4( 1.0,  0.0425,  1.040, -0.040);
                float4 r    = roughness * c0 + c1;
                float  a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
                return float2(-1.04, 1.04) * a004 + r.zw;
            }

            float3 FresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
            }

            float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
                return F0 + (max((float3)(1.0 - roughness), F0) - F0) * pow(saturate(1.0 - cosTheta), 5.0);
            }

            // Disney / Burley diffuse with retro-reflection (the missing piece in the original shader)
            // FD90 = 0.5 + 2 r cos²θd ; result already divided by PI.
            float3 DisneyDiffuse(float3 albedo, float roughness, float NoV, float NoL, float HoL)
            {
                float fd90         = 0.5 + 2.0 * roughness * HoL * HoL;
                float lightScatter = 1.0 + (fd90 - 1.0) * pow(1.0 - NoL, 5.0);
                float viewScatter  = 1.0 + (fd90 - 1.0) * pow(1.0 - NoV, 5.0);
                return albedo * (lightScatter * viewScatter / PI);
            }

            // Anisotropic GGX NDF (Burley)
            float D_GGXAnisotropic(float NoH, float ToH, float BoH, float ax, float ay)
            {
                float a2 = ax * ay;
                float3 v = float3(ay * ToH, ax * BoH, a2 * NoH);
                float v2 = dot(v, v);
                float w2 = a2 / max(v2, 1e-7);
                return a2 * w2 * w2 * (1.0 / PI);
            }

            // Anisotropic Smith joint visibility (Heitz). Already includes 1/(4 NoV NoL).
            float V_SmithGGXAnisotropic(float NoV, float NoL,
                                        float ToV, float BoV,
                                        float ToL, float BoL,
                                        float ax,  float ay)
            {
                float lambdaV = NoL * length(float3(ax * ToV, ay * BoV, NoV));
                float lambdaL = NoV * length(float3(ax * ToL, ay * BoL, NoL));
                return 0.5 / max(lambdaV + lambdaL, 1e-5);
            }

            // Disney sheen — uses sheenColor properly (was: only .r)
            float3 DisneySheen(float3 albedo, float3 sheenColor, float sheen, float sheenTint, float HoL)
            {
                if (sheen <= 0) return 0;
                float lum     = dot(albedo, float3(0.3, 0.6, 0.1));
                float3 cTint  = lum > 0 ? albedo * rcp(lum) : (float3)1;
                float3 sCol   = lerp((float3)1, cTint, sheenTint) * sheenColor;
                return sheen * sCol * pow(saturate(1.0 - HoL), 5.0);
            }

            // GTR1 NDF for Disney clearcoat
            float D_GTR1(float NoH, float a)
            {
                if (a >= 1.0) return 1.0 / PI;
                float a2 = a * a;
                float t  = 1.0 + (a2 - 1.0) * NoH * NoH;
                return (a2 - 1.0) / (PI * log(a2) * t);
            }

            // Smith G for clearcoat (fixed roughness 0.25)
            float V_KelemenClearcoat(float NoV, float NoL)
            {
                const float ccRoughSq = 0.0625; // 0.25^2
                float gv = 2.0 * rcp(1.0 + sqrt(ccRoughSq + (1.0 - ccRoughSq) * NoV * NoV));
                float gl = 2.0 * rcp(1.0 + sqrt(ccRoughSq + (1.0 - ccRoughSq) * NoL * NoL));
                return gv * gl;
            }

            // Returns clearcoat BRDF (no NoL/light radiance applied).
            float ClearcoatBRDF(float clearcoat, float ccPerceptualRoughness,
                                float NoH, float HoL, float NoV, float NoL)
            {
                if (clearcoat <= 0) return 0;
                // Disney remap of perceptual roughness to GTR1 alpha range (0.001 .. 0.1).
                float a = lerp(0.1, 0.001, 1.0 - ccPerceptualRoughness);
                float D = D_GTR1(NoH, a);
                float F = 0.04 + 0.96 * pow(saturate(1.0 - HoL), 5.0);
                float G = V_KelemenClearcoat(NoV, NoL);
                return 0.25 * clearcoat * D * F * G;
            }

            // Lagarde specular occlusion approximation
            float SpecularOcclusion(float NoV, float ao, float roughness)
            {
                return saturate(pow(abs(NoV + ao), exp2(-16.0 * roughness - 1.0)) - 1.0 + ao);
            }

            // Rotate tangent frame around N to expose anisotropic rotation control.
            void RotateTangentFrame(inout float3 T, inout float3 B, float3 N, float angle01)
            {
                float a  = angle01 * 2.0 * PI;
                float ca = cos(a);
                float sa = sin(a);
                float3 newT =  T * ca + B * sa;
                float3 newB = -T * sa + B * ca;
                T = newT;
                B = newB;
            }

            // Single-step parallax UV offset using tangent-space view direction.
            float2 ParallaxOffset(float2 uv, float3 viewDirTS, float scale)
            {
                float h = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
                float2 viewXY = viewDirTS.xy / max(viewDirTS.z, 0.1);
                return uv + viewXY * (h - 0.5) * scale;
            }

            // ============================================================
            //                       Surface init
            // ============================================================

            void InitInputData(Varyings IN, half3 normalTS, float3 normalWS, float3 viewDirWS, out InputData inputData)
            {
                inputData                  = (InputData)0;
                inputData.positionWS       = IN.positionWS;
                inputData.positionCS       = IN.positionCS;
                inputData.normalWS         = normalWS;
                inputData.viewDirectionWS  = viewDirWS;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0,0,0,0);
                #endif

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    inputData.vertexLighting = IN.vertexLighting.xyz;
                #else
                    inputData.vertexLighting = half3(0,0,0);
                #endif

                inputData.fogCoord                = InitializeInputDataFog(float4(IN.positionWS, 1.0), IN.fogFactor);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
            }

            void InitBakedGI(Varyings IN, inout InputData inputData)
            {
                #if defined(DYNAMICLIGHTMAP_ON)
                    inputData.bakedGI    = SAMPLE_GI(IN.staticLightmapUV, IN.dynamicLightmapUV, IN.vertexSH, inputData.normalWS);
                    inputData.shadowMask = SAMPLE_SHADOWMASK(IN.staticLightmapUV);
                #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
                    inputData.bakedGI    = SAMPLE_GI(IN.vertexSH,
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

            // SSAO sample. Returns (directAO, indirectAO).
            float2 SampleSSAO(float2 screenUV)
            {
                #if defined(_SCREEN_SPACE_OCCLUSION) && !defined(SHADERGRAPH_PREVIEW)
                    float ssao = saturate(SampleAmbientOcclusion(screenUV) + (1.0 - _AmbientOcclusionParam.x));
                    float directAO = lerp(1.0, ssao, _AmbientOcclusionParam.w);
                    return float2(directAO, ssao);
                #else
                    return float2(1, 1);
                #endif
            }

            // ============================================================
            //                          Fragment
            // ============================================================

            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float2 screenUV  = GetNormalizedScreenSpaceUV(IN.positionCS);
                float3 viewDirWS = SafeNormalize(half3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w));

                // ---- Geometric TBN ----
                float3 N0 = normalize(IN.normalWS.xyz);
                float3 T0 = normalize(IN.tangentWS.xyz);
                float3 B0 = normalize(IN.bitangentWS.xyz);

                // ---- Parallax UV ----
                float2 uv = IN.uv;
                #if defined(_USE_HEIGHT_MAP)
                {
                    float3x3 worldToTangent = float3x3(T0, B0, N0);
                    float3 viewDirTS = mul(worldToTangent, viewDirWS);
                    uv = ParallaxOffset(uv, viewDirTS, _HeightScale);
                }
                #endif

                // ---- Texture samples ----
                float4 baseSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                float3 albedo     = _BaseColor.rgb * baseSample.rgb;
                float  alpha      = _BaseColor.a   * baseSample.a;

                float metallic = _Metallic;
                #if defined(_USE_METALLIC_MAP)
                    metallic *= SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv).r;
                #endif

                // Disney/UE4 convention: UI value is perceptual roughness; α used by D/G is r².
                float perceptualRoughness = _Roughness;
                #if defined(_USE_ROUGHNESS_MAP)
                    perceptualRoughness *= SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).r;
                #endif
                perceptualRoughness = max(perceptualRoughness, 0.045);
                float roughness = perceptualRoughness * perceptualRoughness;

                float ao = _AmbientOcclusion;
                #if defined(_USE_AO_MAP)
                    ao *= SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, uv).g;
                #endif

                float anisotropy = _Anisotropy;
                #if defined(_USE_ANISOTROPY_MAP)
                    anisotropy *= SAMPLE_TEXTURE2D(_AnisotropyMap, sampler_AnisotropyMap, uv).r;
                #endif

                // ---- Normal map ----
                half3 normalTS = half3(0,0,1);
                #if defined(_USE_NORMAL_MAP)
                    normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv));
                #endif
                float3 normalWS = normalize(TransformTangentToWorld(normalTS, float3x3(T0, B0, N0)));

                // ---- Anisotropic tangent frame (rotated, then re-orthogonalized to perturbed normal) ----
                float3 anisoT = T0;
                float3 anisoB = B0;
                if (anisotropy > 0)
                    RotateTangentFrame(anisoT, anisoB, N0, _AnisotropicRotation);
                anisoT = normalize(anisoT - normalWS * dot(normalWS, anisoT));
                anisoB = normalize(cross(normalWS, anisoT));

                // ---- Anisotropic α ----
                float aspect = sqrt(1.0 - 0.9 * anisotropy);
                float ax = max(0.001, roughness / aspect);
                float ay = max(0.001, roughness * aspect);

                float NoV = saturate(dot(normalWS, viewDirWS));

                // ---- F0 ----
                float3 F0 = lerp((float3)_F0, albedo, metallic);

                // ---- InputData / GI ----
                InputData inputData;
                InitInputData(IN, normalTS, normalWS, viewDirWS, inputData);
                InitBakedGI(IN, inputData);

                float2 ssao      = SampleSSAO(screenUV);
                float  indirectAO = min(ssao.y, ao);
                float  directAO   = ssao.x;

                // ============================================================
                //                            IBL
                // ============================================================
                float3 kS_indirect = FresnelSchlickRoughness(NoV, F0, perceptualRoughness);
                float3 kD_indirect = (1.0 - kS_indirect) * (1.0 - metallic);

                float2 envBRDF = EnvBRDFApprox(perceptualRoughness, NoV);
                float  envLOD  = PerceptualRoughnessToMipmapLevel(perceptualRoughness);

                float3 reflectDir   = reflect(-viewDirWS, normalWS);
                float3 iblSpec      = 0;
                float3 iblDiff      = kD_indirect * albedo * inputData.bakedGI;
                float3 iblClearcoat = 0;

                #if defined(_USE_CUSTOM_CUBEMAP)
                    float3 prefiltered     = SAMPLE_TEXTURECUBE_LOD(_CustomCubemap, sampler_CustomCubemap, reflectDir, envLOD).rgb;
                    iblSpec                = prefiltered * (kS_indirect * envBRDF.x + envBRDF.y);
                    // Approximate irradiance via max-mip sample (not a proper convolution).
                    float3 irradianceCube  = SAMPLE_TEXTURECUBE_LOD(_CustomCubemap, sampler_CustomCubemap, normalWS, 6.0).rgb;
                    iblDiff                = kD_indirect * albedo * irradianceCube;
                #elif defined(_USE_REFLECTIVE_PROBE)
                    float3 prefiltered = GlossyEnvironmentReflection(reflectDir, IN.positionWS, perceptualRoughness, 1.0, screenUV);
                    iblSpec            = prefiltered * (kS_indirect * envBRDF.x + envBRDF.y);
                #endif

                // Lagarde specular occlusion + AO on diffuse irradiance
                float specOcc = SpecularOcclusion(NoV, indirectAO, roughness);
                iblSpec *= specOcc;
                iblDiff *= indirectAO;

                // IBL clearcoat (separate env sample at clearcoat roughness)
                #if defined(_USE_CUSTOM_CUBEMAP) || defined(_USE_REFLECTIVE_PROBE)
                    if (_ClearCoat > 0)
                    {
                        float ccPerceptual = max(_ClearCoatRoughness, 0.045);
                        float ccLOD        = PerceptualRoughnessToMipmapLevel(ccPerceptual);
                        float Fcc          = 0.04 + 0.96 * pow(saturate(1.0 - NoV), 5.0);
                        float3 ccPref      = 0;
                        #if defined(_USE_CUSTOM_CUBEMAP)
                            ccPref = SAMPLE_TEXTURECUBE_LOD(_CustomCubemap, sampler_CustomCubemap, reflectDir, ccLOD).rgb;
                        #else
                            ccPref = GlossyEnvironmentReflection(reflectDir, IN.positionWS, ccPerceptual, 1.0, screenUV);
                        #endif
                        iblClearcoat = ccPref * Fcc * _ClearCoat * specOcc;
                    }
                #endif

                float3 ibl = iblSpec + iblDiff + iblClearcoat;

                // ============================================================
                //                       Main Light (direct)
                // ============================================================
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light  mainLight   = GetMainLight(shadowCoord, IN.positionWS, inputData.shadowMask);
                MixRealtimeAndBakedGI(mainLight, normalWS, inputData.bakedGI);

                float3 mainLightContrib;
                {
                    float3 L = mainLight.direction;
                    float3 H = normalize(viewDirWS + L);

                    float NoL = saturate(dot(normalWS, L));
                    float NoH = saturate(dot(normalWS, H));
                    float HoL = saturate(dot(H, L));
                    float VoH = saturate(dot(viewDirWS, H));

                    float ToH = dot(anisoT, H);
                    float BoH = dot(anisoB, H);
                    float ToV = dot(anisoT, viewDirWS);
                    float BoV = dot(anisoB, viewDirWS);
                    float ToL = dot(anisoT, L);
                    float BoL = dot(anisoB, L);

                    // Disney diffuse (energy-conserving via 1 - metallic)
                    float3 diffuse = DisneyDiffuse(albedo, roughness, NoV, NoL, HoL) * (1.0 - metallic);

                    // Anisotropic GGX specular: D · V_smith · F  (V_smith already absorbs the 4 NoV NoL)
                    float  D = D_GGXAnisotropic(NoH, ToH, BoH, ax, ay);
                    float  V = V_SmithGGXAnisotropic(NoV, NoL, ToV, BoV, ToL, BoL, ax, ay);
                    float3 F = FresnelSchlick(VoH, F0);
                    float3 specular = D * V * F;

                    // Disney specularTint blend (white ↔ luminance-normalized albedo)
                    float  lumA   = dot(_BaseColor.rgb, float3(0.3, 0.6, 0.1));
                    float3 albTint = lumA > 0 ? _BaseColor.rgb * rcp(lumA) : (float3)1;
                    specular *= _SpecularColor.rgb * lerp((float3)1, albTint, _SpecularTint);

                    float3 sheen = DisneySheen(albedo, _SheenColor.rgb, _Sheen, _SheenTint, HoL);
                    float  cc    = ClearcoatBRDF(_ClearCoat, _ClearCoatRoughness, NoH, HoL, NoV, NoL);

                    float3 radiance = mainLight.color * mainLight.shadowAttenuation * NoL * directAO;
                    mainLightContrib = (diffuse + specular + sheen + cc) * radiance;
                }

                // ============================================================
                //                    Additional Lights (direct)
                // ============================================================
                float3 additionalContrib = 0;

                #if defined(_ADDITIONAL_LIGHTS) || defined(_CLUSTER_LIGHT_LOOP)
                    uint pixelLightCount = GetAdditionalLightsCount();

                    LIGHT_LOOP_BEGIN(pixelLightCount)
                        Light light = GetAdditionalLight(lightIndex, IN.positionWS, inputData.shadowMask);
                        #if defined(_LIGHT_COOKIES)
                            light.color *= SampleAdditionalLightCookie(lightIndex, IN.positionWS);
                        #endif

                        float3 L = light.direction;
                        float3 H = normalize(viewDirWS + L);

                        float NoL = saturate(dot(normalWS, L));
                        float NoH = saturate(dot(normalWS, H));
                        float HoL = saturate(dot(H, L));
                        float VoH = saturate(dot(viewDirWS, H));

                        float ToH = dot(anisoT, H);
                        float BoH = dot(anisoB, H);
                        float ToV = dot(anisoT, viewDirWS);
                        float BoV = dot(anisoB, viewDirWS);
                        float ToL = dot(anisoT, L);
                        float BoL = dot(anisoB, L);

                        float3 diffuse = DisneyDiffuse(albedo, roughness, NoV, NoL, HoL) * (1.0 - metallic);

                        float  D = D_GGXAnisotropic(NoH, ToH, BoH, ax, ay);
                        float  V = V_SmithGGXAnisotropic(NoV, NoL, ToV, BoV, ToL, BoL, ax, ay);
                        float3 F = FresnelSchlick(VoH, F0);
                        float3 specular = D * V * F;

                        float3 sheen = DisneySheen(albedo, _SheenColor.rgb, _Sheen, _SheenTint, HoL);
                        float  cc    = ClearcoatBRDF(_ClearCoat, _ClearCoatRoughness, NoH, HoL, NoV, NoL);

                        float3 radiance = light.color * light.distanceAttenuation * light.shadowAttenuation * NoL;
                        additionalContrib += (diffuse + specular + sheen + cc) * radiance;
                    LIGHT_LOOP_END
                #endif

                #if defined(_ADDITIONAL_LIGHTS_VERTEX)
                    additionalContrib += inputData.vertexLighting * albedo * (1.0 - metallic) / PI;
                #endif

                // ---- Emission ----
                float3 emission = 0;
                #if defined(_ENABLE_EMISSION)
                    emission = _EmissionColor.rgb;
                #endif

                float3 color = ibl + mainLightContrib + additionalContrib + emission;

                color = MixFog(color, inputData.fogCoord);
                return float4(color, alpha);
            }
            ENDHLSL
        }

        // ─────────────────────────────────────────────────────────────
        // ShadowCaster
        // ─────────────────────────────────────────────────────────────
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex   ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            float4 GetShadowPositionHClip(ShadowAttributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS   = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                return positionCS;
            }

            ShadowVaryings ShadowVert(ShadowAttributes IN)
            {
                ShadowVaryings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                OUT.positionCS = GetShadowPositionHClip(IN);
                return OUT;
            }

            half4 ShadowFrag(ShadowVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                return 0;
            }
            ENDHLSL
        }

        // ─────────────────────────────────────────────────────────────
        // DepthOnly
        // ─────────────────────────────────────────────────────────────
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex   DepthVert
            #pragma fragment DepthFrag
            #pragma multi_compile_instancing

            struct DepthAttributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct DepthVaryings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            DepthVaryings DepthVert(DepthAttributes IN)
            {
                DepthVaryings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 DepthFrag(DepthVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                return 0;
            }
            ENDHLSL
        }

        // ─────────────────────────────────────────────────────────────
        // DepthNormals (for SSAO / depth-normal prepass)
        // ─────────────────────────────────────────────────────────────
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex   DepthNormalsVert
            #pragma fragment DepthNormalsFrag
            #pragma multi_compile_instancing

            struct DNAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct DNVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS   : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            DNVaryings DepthNormalsVert(DNAttributes IN)
            {
                DNVaryings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                VertexPositionInputs vIn = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nIn = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS = vIn.positionCS;
                OUT.normalWS   = nIn.normalWS;
                return OUT;
            }

            half4 DepthNormalsFrag(DNVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                return half4(NormalizeNormalPerPixel(IN.normalWS), 0.0);
            }
            ENDHLSL
        }

        // ─────────────────────────────────────────────────────────────
        // Meta (lightmap baking)
        // ─────────────────────────────────────────────────────────────
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM
            #pragma vertex   MetaVert
            #pragma fragment MetaFrag
            #pragma shader_feature_local _ENABLE_EMISSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

            struct MetaAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv0        : TEXCOORD0;
                float2 uv1        : TEXCOORD1;
                float2 uv2        : TEXCOORD2;
            };
            struct MetaVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            MetaVaryings MetaVert(MetaAttributes IN)
            {
                MetaVaryings OUT;
                OUT.positionCS = UnityMetaVertexPosition(IN.positionOS.xyz, IN.uv1, IN.uv2, unity_LightmapST, unity_DynamicLightmapST);
                OUT.uv         = TRANSFORM_TEX(IN.uv0, _MainTex) * _TextureTiling.xy;
                return OUT;
            }

            half4 MetaFrag(MetaVaryings IN) : SV_Target
            {
                MetaInput meta = (MetaInput)0;
                meta.Albedo    = _BaseColor.rgb * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;
                #if defined(_ENABLE_EMISSION)
                    meta.Emission = _EmissionColor.rgb;
                #else
                    meta.Emission = 0;
                #endif
                return UnityMetaFragment(meta);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
