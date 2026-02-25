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

        [Header(Specular Highlights)]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularIntensity("Specular Intensity", Range(0,1)) = 1.0

        [Header(Emission)]
        _EmissionColor("Emission Color", Color) = (0,0,0,1)
        [Toggle(Enable Emission)] _EnableEmission("Enable Emission", Float) = 0

        [Header(Height Map)]
        [Toggle(Use Height Map)] _UseHeightMap("Use Height Map", Float) = 0
        _HeightMap("Height Map", 2D) = "black" {}

        [Header(Advanced Options)]
        _F0("F0", Range(0,1)) = 0.04
        _ClearCoat("Clear Coat", Range(0,1)) = 0.0
        _ClearCoatRoughness("Clear Coat Roughness", Range(0,1)) = 0.5
        _Sheen("Sheen", Range(0,1)) = 0.0
        _SheenColor("Sheen Color", Color) = (1,1,1,1)
        _TextureTiling("Texture Tiling", Vector) = (1,1,0,0)

        [Header(Reflection)]
        [Toggle(Use Reflective Probe)] _UseReflectiveProbe("Use Reflective Probe", Float) = 0
        [Toggle(Use Custom Cubemap)] _UseCustomCubemap("Use Custom Cubemap", Float) = 0
        _CustomCubemap("Custom Cubemap", Cube) = "" {}
    }

    SubShader
    {
        Pass
        {
            Tags { "RenderType"="Opaque" }

            Cull Back
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_frag _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SOFT_SHADOWS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SHADOWMASK
            #pragma multi_compile _ _LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            

            // Textures and samplers must live outside the CBuffer
            TEXTURE2D(_MainTex);         SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);       SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicMap);     SAMPLER(sampler_MetallicMap);
            TEXTURE2D(_RoughnessMap);    SAMPLER(sampler_RoughnessMap);
            TEXTURE2D(_AOMap);           SAMPLER(sampler_AOMap);
            TEXTURE2D(_AnisotropyMap);   SAMPLER(sampler_AnisotropyMap);
            TEXTURE2D(_HeightMap);       SAMPLER(sampler_HeightMap);
            TEXTURECUBE(_CustomCubemap); SAMPLER(sampler_CustomCubemap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _Metallic;
                float _Roughness;
                float _AmbientOcclusion;
                float _Anisotropy;
                float4 _SpecularColor;
                float _SpecularIntensity;
                float4 _EmissionColor;
                float _EnableEmission;
                float _F0;
                float _ClearCoat;
                float _ClearCoatRoughness;
                float _Sheen;
                float4 _SheenColor;
                float4 _TextureTiling;
                float4 _MainTex_ST;

                // Reflection
                float _UseReflectiveProbe;
                float _UseCustomCubemap;

                // Toggles
                float _UseNormalMap;
                float _UseMetallicMap;
                float _UseRoughnessMap;
                float _UseAOMap;
                float _UseAnisotropyMap;
                float _UseHeightMap;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
                float2 staticLightmapUV   : TEXCOORD1;
                float2 dynamicLightmapUV  : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;

                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                // Normal
                float4 normalWS                   : TEXCOORD2;    // xyz: normal, w: viewDir.x
                float4 tangentWS                  : TEXCOORD3;    // xyz: tangent, w: viewDir.y
                float4 bitangentWS                : TEXCOORD4;    // xyz: bitangent, w: viewDir.z
                
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half3 vertexLighting            : TEXCOORD5; // xyz: vertex light
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord              : TEXCOORD6;
                #endif

                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);

                #ifdef DYNAMICLIGHTMAP_ON
                    float2  dynamicLightmapUV : TEXCOORD8; // Dynamic lightmap UVs
                #endif

                #ifdef USE_APV_PROBE_OCCLUSION
                    float4 probeOcclusion : TEXCOORD9;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.uv = TRANSFORM_TEX(IN.texcoord, _MainTex) * _TextureTiling.xy;
                OUT.positionWS = vertexInput.positionWS;
                OUT.positionCS = vertexInput.positionCS;

                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                OUT.normalWS = float4(normalInput.normalWS, viewDirWS.x);
                OUT.tangentWS = float4(normalInput.tangentWS, viewDirWS.y);
                OUT.bitangentWS = float4(normalInput.bitangentWS, viewDirWS.z);

                OUTPUT_LIGHTMAP_UV(IN.staticLightmapUV, unity_LightmapST, OUT.staticLightmapUV);
                #ifdef DYNAMICLIGHTMAP_ON
                    OUT.dynamicLightmapUV = IN.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                OUTPUT_SH4(vertexInput.positionWS, OUT.normalWS.xyz, GetWorldSpaceNormalizeViewDir(vertexInput.positionWS), OUT.vertexSH, OUT.probeOcclusion);

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                    OUT.vertexLighting = vertexLight;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    OUT.shadowCoord = GetShadowCoord(vertexInput);
                #endif
                return OUT;
            }

            void InitializeInputData(Varyings IN, half3 normalTS, out InputData inputData)
            {
                inputData = (InputData)0;

                inputData.positionWS = IN.positionWS;
                inputData.positionCS = IN.positionCS;

                #ifdef _NORMALMAP
                    half3 viewDirWS = half3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w);
                    inputData.normalWS = TransformTangentToWorld(normalTS,half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz));
                #else
                    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(inputData.positionWS);
                    inputData.normalWS = IN.normalWS.xyz;
                #endif

                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                viewDirWS = SafeNormalize(viewDirWS);

                inputData.viewDirectionWS = viewDirWS;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    inputData.vertexLighting = IN.vertexLighting.xyz;
                #else
                    inputData.vertexLighting = half3(0, 0, 0);
                #endif

                inputData.fogCoord = 0; // we don't apply fog in the gbuffer pass
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);

                #if defined(DEBUG_DISPLAY)
                    #if defined(DYNAMICLIGHTMAP_ON)
                        inputData.dynamicLightmapUV = IN.dynamicLightmapUV;
                    #endif
                    #if defined(LIGHTMAP_ON)
                        inputData.staticLightmapUV = IN.staticLightmapUV;
                    #else
                        inputData.vertexSH = IN.vertexSH;
                    #endif
                    #if defined(USE_APV_PROBE_OCCLUSION)
                        inputData.probeOcclusion = IN.probeOcclusion;
                    #endif
                #endif
            }

            void InitializeBakedGIData(Varyings IN, inout InputData inputData)
            {
                #if defined(_SCREEN_SPACE_IRRADIANCE)
                    inputData.bakedGI = SAMPLE_GI(_ScreenSpaceIrradiance, IN.positionCS.xy);
                #elif defined(DYNAMICLIGHTMAP_ON)
                    inputData.bakedGI = SAMPLE_GI(IN.staticLightmapUV, IN.dynamicLightmapUV, IN.vertexSH, inputData.normalWS);
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
                    inputData.bakedGI = SAMPLE_GI(IN.staticLightmapUV, IN.vertexSH, inputData.normalWS);
                    inputData.shadowMask = SAMPLE_SHADOWMASK(IN.staticLightmapUV);
                #endif
            }

            inline void InitializeSimpleLitSurfaceData(float2 uv, out SurfaceData surfaceData)
            {
                surfaceData = (SurfaceData)0;

                surfaceData.albedo = _BaseColor.rgb * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
                surfaceData.specular = _SpecularColor.rgb * _SpecularIntensity;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = 1.0 - _Roughness;
                surfaceData.normalTS = _UseNormalMap > 0 ? UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv)) : float3(0, 0, 1);
                surfaceData.emission = _EnableEmission > 0 ? _EmissionColor.rgb : float3(0, 0, 0);
                surfaceData.occlusion = _AmbientOcclusion;
                surfaceData.alpha = _BaseColor.a * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).a;
                surfaceData.clearCoatMask = _ClearCoat;
                surfaceData.clearCoatSmoothness = 1.0 - _ClearCoatRoughness;
            }

            float2 AmbientSampleSSAO(float2 screenPos)
            {
                float DirectAO;
                float IndirectAO;
                #if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT) && !defined(SHADERGRAPH_PREVIEW)
                    float ssao = saturate(SampleAmbientOcclusion(screenPos) + (1.0 - _AmbientOcclusionParam.x));
                    IndirectAO = ssao;
                    DirectAO = lerp(1.0, ssao, _AmbientOcclusionParam.w);
                #else
                    DirectAO = 1.0;
                    IndirectAO = 1.0;
                #endif

                return float2(DirectAO, IndirectAO);
            }

            float3 CalculateBakedIrradiance(Varyings IN, float2 screenPos, float ambientOcclusion)
            {
                float2 ambientSSAO = AmbientSampleSSAO(screenPos);
                float indirectAO = min(ambientSSAO.y, ambientOcclusion);

                SurfaceData surfaceData;
                InitializeSimpleLitSurfaceData(IN.uv, surfaceData);

                InputData inputData;
                InitializeInputData(IN, surfaceData.normalTS, inputData);
                SETUP_DEBUG_TEXTURE_DATA(inputData, UNDO_TRANSFORM_TEX(IN.uv, _MainTex));

                InitializeBakedGIData(IN, inputData);

                float3 ssao = inputData.bakedGI * indirectAO;
                
                return ssao;
            }

            // Returns combined IBL specular + diffuse contribution.
            // bakedIrradiance: ssao (bakedGI * AO) used as irradiance source for the probe path.
            float3 CalculateIBL(
            float3 normalWS, float3 viewDirWS, float3 positionWS, float2 screenUV,
            float3 albedo,   float   roughness,
            float3 kS,       float3  kD,
            float2 brdf,     float   envLOD,
            float3 bakedIrradiance)
            {
                float3 envContribution = 0;
                float3 irradianceIBL   = 0;

                if (_UseCustomCubemap > 0)
                {
                    float3 reflectDir = reflect(-viewDirWS, normalWS);

                    // IBL Specular: prefiltered env × (F × scale + bias)
                    float3 prefilteredColor = SAMPLE_TEXTURECUBE_LOD(_CustomCubemap, sampler_CustomCubemap, reflectDir, envLOD).rgb;
                    envContribution = prefilteredColor * (kS * brdf.x + brdf.y);

                    // IBL Diffuse: max-LOD sample as irradiance proxy; apply kD and albedo
                    float3 irradiance = SAMPLE_TEXTURECUBE_LOD(_CustomCubemap, sampler_CustomCubemap, normalWS, 6.0).rgb;
                    irradianceIBL = kD * albedo * irradiance;
                }
                else if (_UseReflectiveProbe > 0)
                {
                    float3 reflectDir = reflect(-viewDirWS, normalWS);

                    // IBL Specular via Unity reflection probe (handles probe blending + HDR decode)
                    float3 prefilteredColor = GlossyEnvironmentReflection(reflectDir, positionWS, roughness, 1.0, screenUV);
                    envContribution = prefilteredColor * (kS * brdf.x + brdf.y);

                    // IBL Diffuse: baked SH/lightmap irradiance, apply kD and albedo
                    irradianceIBL = kD * albedo * bakedIrradiance;
                }

                return envContribution + irradianceIBL;
            }

            // Analytical approximation of the split-sum BRDF LUT (Karis / UE4)
            // Replaces the expensive per-pixel Monte Carlo integration.
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
                return F0 + (max((float3)(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            float3 FresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            // N, T, H must be in the same space (world). Bitangent derived as cross(N,T).
            float DistributionGGXAnisotropic(float3 N, float3 T, float3 H, float roughness)
            {
                float aspect = sqrt(1.0 - 0.9 * _Anisotropy); // remap [0,1] anisotropy to [1,0.316] aspect ratio
                float ax = max(0.001, roughness * roughness / aspect);
                float ay = max(0.001, roughness * roughness * aspect);
                float XoH = dot(T, H);
                float YoH = dot(cross(N, T), H);
                float NoH = max(dot(N, H), 0.0);
                float d = XoH * XoH / (ax * ax) + YoH * YoH / (ay * ay) + NoH * NoH;
                return rcp(PI * ax * ay * d * d);
            }

            // Direct lighting remapping: k = (r+1)² / 8  (Disney/UE4)
            // IBL remapping k = r²/2 is intentionally NOT used here.
            float GeometrySmithSchlickGGX(float NoV, float NoL, float roughness)
            {
                float r1 = roughness + 1.0;
                float k  = max((r1 * r1) / 8.0, 0.0001);
                float smithV = NoV * rcp(NoV * (1.0 - k) + k);
                float smithL = NoL * rcp(NoL * (1.0 - k) + k);
                return smithV * smithL;
            }

            // sheenTint: scalar [0,1] blending between white and luminance-normalized color (Disney model)
            float3 CalculateSheen(float3 color, float sheen, float sheenTint, float HoL)
            {
                if (sheen <= 0) return 0;
                float luminance = dot(color, float3(0.3, 0.6, 0.1));
                float3 tint = luminance > 0 ? color * rcp(luminance) : (float3)1;
                float3 sheenColor = lerp((float3)1, tint, sheenTint); // sheenTint is scalar blend factor
                return sheen * sheenColor * pow(saturate(1.0 - HoL), 5.0);
            }

            // GTR1 NDF + Smith GGX geometry for clearcoat (Disney model)
            // NoL not needed — clearcoat geometry term uses fixed 0.25 roughness, not NoL.
            float3 CalculateClearcoat(float clearcoat, float alpha, float NoH, float HoL, float NoV)
            {
                if (clearcoat <= 0) return 0;

                // Remap smoothness [0,1] to GTR1 alpha [0.1, 0.001]
                // After this remap alpha is always in (0.001, 0.1), never >= 1.
                alpha = lerp(0.1, 0.001, alpha);
                float alphaSq = alpha * alpha;

                // GTR1 (Berry / Disney clearcoat NDF)
                float d = (alphaSq - 1.0) * rcp(PI * log(alphaSq) * (1.0 + (alphaSq - 1.0) * NoH * NoH));

                // Fresnel: clearcoat is always dielectric F0 = 0.04
                float f = 0.04 + 0.96 * pow(saturate(1.0 - HoL), 5.0);

                // Smith GGX geometry at fixed clearcoat roughness = 0.25
                float ccRoughSq = 0.25 * 0.25;
                float gl = 2.0 * rcp(1.0 + sqrt(ccRoughSq + (1.0 - ccRoughSq) * NoV * NoV));

                return (float3)(0.25 * clearcoat * d * f * gl);
            }

            // Returns Cook-Torrance specular for a single additional light.
            // F0 and metallic are passed from the caller so they match the main-light path exactly.
            float3 CalculateAdditionalLightsPBRSpecular(float3 N, float3 V, float3 L, float3 T,
                                                        float3 F0, float metallic, float3 albedo, float roughness)
            {
                float3 H   = normalize(V + L);
                float  NoL = saturate(dot(N, L));
                float  NoV = max(dot(N, V), 0.0);
                float  VoH = saturate(dot(V, H));

                float  D = DistributionGGXAnisotropic(N, T, H, roughness);
                float  G = GeometrySmithSchlickGGX(NoV, NoL, roughness);
                float3 F = FresnelSchlick(VoH, F0);
                return D * G * F * rcp(max(4.0 * NoV * NoL, 0.0001));
            }

            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float2 screenUV = GetNormalizedScreenSpaceUV(IN.positionCS);

                // ---------- Baked GI Calculation (Irradiance + Shadow Mask) ----------
                float3 bakedIrradiance = CalculateBakedIrradiance(IN, screenUV, _AmbientOcclusion);

                float3 viewDirWS = SafeNormalize(half3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w));

                // Apply normal map to world-space normal used by all direct/IBL lighting.
                // Without this, _UseNormalMap only affects CalculateBakedIrradiance, not specular/diffuse.
                half3 normalTS   = _UseNormalMap > 0
                ? UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv))
                : half3(0, 0, 1);
                float3 normalWS  = _UseNormalMap > 0
                ? normalize(TransformTangentToWorld(normalTS, half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz)))
                : IN.normalWS.xyz;

                // Sample surface maps
                float3 albedo    = _BaseColor.rgb * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;
                float  metallic  = _UseMetallicMap  > 0 ? SAMPLE_TEXTURE2D(_MetallicMap,  sampler_MetallicMap,  IN.uv).r * _Metallic  : _Metallic;
                float  roughness = _UseRoughnessMap > 0 ? SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, IN.uv).r * _Roughness : _Roughness;
                roughness = max(roughness, 0.045); // prevent degenerate specular at roughness = 0

                float nov = max(dot(normalWS, viewDirWS), 0.0);

                // F0: dielectrics use _F0 (default 0.04), metals tint F0 with albedo
                float3 F0 = lerp(float3(_F0, _F0, _F0), albedo, metallic);

                // Energy conservation: kS (reflected) + kD (diffuse) = 1
                float3 kS = FresnelSchlickRoughness(nov, F0, roughness);
                float3 kD = (1.0 - kS) * (1.0 - metallic);

                // Split-sum BRDF via analytical LUT approximation
                float2 brdf   = EnvBRDFApprox(roughness, nov);
                float  envLOD = roughness * 6.0; // URP cubemaps support up to 6 mip levels

                float3 ibl = CalculateIBL(
                normalWS, viewDirWS, IN.positionWS, screenUV,
                albedo,   roughness,
                kS,       kD,
                brdf,     envLOD,
                bakedIrradiance);

                // ---------- PBR Main Lighting Calculation ----------
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float nol = max(dot(normalWS, mainLight.direction), 0.0);
                float3 h   = normalize(viewDirWS + mainLight.direction);
                float voh  = max(dot(viewDirWS, h), 0.0); // Fresnel for direct light uses V·H, not N·V

                // Fresnel at V·H for direct lighting (N·V is for IBL only)
                float3 fresnelSchlick = FresnelSchlick(voh, F0);

                float distribution = DistributionGGXAnisotropic(normalWS, IN.tangentWS.xyz, h, roughness);
                float geometry     = GeometrySmithSchlickGGX(nov, nol, roughness);

                // Cook-Torrance: (D * G * F) / (4 * N·V * N·L)  ×  N·L  ×  lightColor  ×  shadow
                // N·L in numerator and denominator do NOT fully cancel — numerator is irradiance foreshortening,
                // denominator is the BRDF normalization. Omitting it causes a hard bright edge at the terminator.
                // Cook-Torrance specular BRDF (no nol/color/shadow here — applied once in pbr below)
                float3 specular = (distribution * geometry * fresnelSchlick) / max(4.0 * nov * nol, 0.001);

                // Specular tint: scalar luminance of albedo blends white→tinted (Disney specularTint model)
                float luminance = dot(_BaseColor.rgb, float3(0.3, 0.6, 0.1));
                float3 albedoTint = luminance > 0 ? _BaseColor.rgb * rcp(luminance) : (float3)1;
                specular *= _SpecularColor.rgb * lerp((float3)1, albedoTint, _SpecularIntensity);

                // Lambert diffuse with energy conservation
                float3 diffuse = (1.0 - fresnelSchlick) * (1.0 - metallic) * albedo / PI;

                // Sheen: fabric retroreflection, _SheenColor.r used as scalar tint blend (Disney model)
                float3 sheen = CalculateSheen(albedo, _Sheen, _SheenColor.r, dot(h, mainLight.direction));
                diffuse += sheen;

                // Apply nol × light color × shadow once to the combined (diffuse + specular)
                float3 mainLightRadiance = (diffuse + specular) * nol * mainLight.shadowAttenuation * mainLight.color;

                float noh = max(dot(normalWS, h), 0.0);
                float hol = max(dot(h, mainLight.direction), 0.0);

                float3 clearcoat = CalculateClearcoat(_ClearCoat, 1.0 - _ClearCoatRoughness, noh, hol, nov);
                mainLightRadiance += clearcoat * mainLight.shadowAttenuation * mainLight.color;

                // ---------- Additional Lights Radiance Calculation ----------
                float3 additionalLightsRadiance = 0;

                // Shadow mask lives in lightmap UV space, not screen UV.
                float4 shadowMask = SAMPLE_SHADOWMASK(IN.staticLightmapUV);

                uint pixelLightCount = GetAdditionalLightsCount();

                #if USE_CLUSTER_LIGHT_LOOP
                    InputData inputData = (InputData)0;
                    inputData.normalizedScreenSpaceUV = screenUV;
                    inputData.positionWS = IN.positionWS;
                    inputData.normalWS   = normalWS;
                #endif

                LIGHT_LOOP_BEGIN(pixelLightCount)
                    #if !USE_CLUSTER_LIGHT_LOOP
                        lightIndex = GetPerObjectLightIndex(lightIndex);
                    #endif

                    // Pass shadowMask (baked), not the main-light shadowCoord.
                    Light light = GetAdditionalLight(lightIndex, IN.positionWS, shadowMask);

                    // Apply cookie before computing any contribution from this light.
                    #if defined(LIGHT_COOKIES)
                        float3 cookieColor = SampleAdditionalLightCookie(lightIndex, IN.positionWS);
                        light.color *= cookieColor;
                    #endif

                    float  addNoL  = saturate(dot(normalWS, light.direction));
                    float3 addH    = normalize(viewDirWS + light.direction);
                    float  addVoH  = saturate(dot(viewDirWS, addH));

                    // Per-light Fresnel (V·H, same convention as main light)
                    float3 addF    = FresnelSchlick(addVoH, F0);

                    // Cook-Torrance specular for this light
                    float3 addSpec = CalculateAdditionalLightsPBRSpecular(
                        normalWS, viewDirWS, light.direction, IN.tangentWS.xyz,
                        F0, metallic, albedo, roughness);

                    // Lambert diffuse with energy conservation (same formula as main light)
                    float3 addDiff = (1.0 - addF) * (1.0 - metallic) * albedo / PI;

                    // Accumulate: (diffuse + specular) × N·L × light radiance
                    float3 lightRadiance = light.color * light.distanceAttenuation * light.shadowAttenuation;
                    additionalLightsRadiance += (addDiff + addSpec) * addNoL * lightRadiance;
                LIGHT_LOOP_END

                return float4(ibl + mainLightRadiance + additionalLightsRadiance, 1);
            }
            ENDHLSL
        }
    }
}