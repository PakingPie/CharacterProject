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
            #pragma multi_compile _SOFT_SHADOWS
            #pragma multi_compile _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SHADOWMASK
            #pragma multi_compile _ _LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _CLUSTER_LIGHT_LOOP
            

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

                // Texture samplers
                sampler2D _MainTex;
                float4 _MainTex_ST;
                sampler2D _NormalMap;
                sampler2D _MetallicMap;
                sampler2D _RoughnessMap;
                sampler2D _AOMap;
                sampler2D _AnisotropyMap;
                sampler2D _HeightMap;

                // Reflection
                float _UseReflectiveProbe;
                float _UseCustomCubemap;
                samplerCUBE _CustomCubemap;

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
                    inputData.normalWS = IN.normalWS;
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

                surfaceData.albedo = _BaseColor.rgb * tex2D(_MainTex, uv).rgb;
                surfaceData.specular = _SpecularColor.rgb * _SpecularIntensity;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = 1.0 - _Roughness;
                surfaceData.normalTS = _UseNormalMap > 0 ? UnpackNormal(tex2D(_NormalMap, uv)) : float3(0, 0, 1);
                surfaceData.emission = _EnableEmission > 0 ? _EmissionColor.rgb : float3(0, 0, 0);
                surfaceData.occlusion = _AmbientOcclusion;
                surfaceData.alpha = _BaseColor.a * tex2D(_MainTex, uv).a;
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

            float3 CalculateSSAO(Varyings IN, float2 screenPos, float ambientOcclusion)
            {
                float2 ambientSSAO = AmbientSampleSSAO(screenPos);
                float indirectAO = min(ambientSSAO.y, ambientOcclusion);

                SurfaceData surfaceData;
                InitializeSimpleLitSurfaceData(IN.uv, surfaceData);

                InputData inputData;
                InitializeInputData(IN, surfaceData.normalTS, inputData);
                SETUP_DEBUG_TEXTURE_DATA(inputData, UNDO_TRANSFORM_TEX(IN.uv, _MainTex));

                InitializeBakedGIData(IN, inputData);

                Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);

                float3 ssao = inputData.bakedGI * indirectAO;
                
                return ssao;
            }

            // http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
            // efficient VanDerCorpus calculation.
            float RadicalInverse_VdC(uint bits) 
            {
                bits = (bits << 16u) | (bits >> 16u);
                bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
                bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
                bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
                bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
                return float(bits) * 2.3283064365386963e-10; // / 0x100000000
            }
            // ----------------------------------------------------------------------------
            float2 Hammersley(uint i, uint N)
            {
                return float2(float(i)/float(N), RadicalInverse_VdC(i));
            }
            // ----------------------------------------------------------------------------
            float3 ImportanceSampleGGX(float2 Xi, float3 N, float roughness)
            {
                float a = roughness*roughness;
                
                float phi = 2.0 * PI * Xi.x;
                float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
                float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
                
                // from spherical coordinates to cartesian coordinates - halfway vector
                float3 H;
                H.x = cos(phi) * sinTheta;
                H.y = sin(phi) * sinTheta;
                H.z = cosTheta;
                
                // from tangent-space H vector to world-space sample vector
                float3 up        = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
                float3 tangent   = normalize(cross(up, N));
                float3 bitangent = cross(N, tangent);
                
                float3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
                return normalize(sampleVec);
            }
            // ----------------------------------------------------------------------------
            float GeometrySchlickGGX(float NdotV, float roughness)
            {
                // note that we use a different k for IBL
                float a = roughness;
                float k = (a * a) / 2.0;

                float nom   = NdotV;
                float denom = NdotV * (1.0 - k) + k;

                return nom / denom;
            }
            // ----------------------------------------------------------------------------
            float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
            {
                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx2 = GeometrySchlickGGX(NdotV, roughness);
                float ggx1 = GeometrySchlickGGX(NdotL, roughness);

                return ggx1 * ggx2;
            }
            // ----------------------------------------------------------------------------
            float2 IntegrateBRDF(float NdotV, float roughness)
            {
                float3 V;
                V.x = sqrt(1.0 - NdotV*NdotV);
                V.y = 0.0;
                V.z = NdotV;

                float A = 0.0;
                float B = 0.0; 

                float3 N = float3(0.0, 0.0, 1.0);
                
                const uint SAMPLE_COUNT = 64u;

                UNITY_LOOP
                for(uint i = 0u; i < SAMPLE_COUNT; ++i)
                {
                    // generates a sample vector that's biased towards the
                    // preferred alignment direction (importance sampling).
                    float2 Xi = Hammersley(i, SAMPLE_COUNT);
                    float3 H = ImportanceSampleGGX(Xi, N, roughness);
                    float3 L = normalize(2.0 * dot(V, H) * H - V);

                    float NdotL = max(L.z, 0.0);
                    float NdotH = max(H.z, 0.0);
                    float VdotH = max(dot(V, H), 0.0);

                    if(NdotL > 0.0)
                    {
                        float G = GeometrySmith(N, V, L, roughness);
                        float G_Vis = (G * VdotH) / (NdotH * NdotV);
                        float Fc = pow(1.0 - VdotH, 5.0);

                        A += (1.0 - Fc) * G_Vis;
                        B += Fc * G_Vis;
                    }
                }
                A /= float(SAMPLE_COUNT);
                B /= float(SAMPLE_COUNT);
                return float2(A, B);
            }
            // ----------------------------------------------------------------------------
            float2 CalculateBRDF(float2 uv)
            {
                return IntegrateBRDF(uv.x, uv.y);
            }

            float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
                return F0 + (max(1.0 - roughness, F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float4 color = 0;

                float2 screenUV = GetNormalizedScreenSpaceUV(IN.positionCS); 

                float3 ssao = CalculateSSAO(IN, screenUV, _AmbientOcclusion);

                float3 normalWS = IN.normalWS.xyz;
                float3 viewDirWS = half3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w);
                float nov = max(dot(normalWS, viewDirWS), 0.0);
                float2 brdf = saturate(CalculateBRDF(float2(nov, _Roughness)));
                float3 specular = brdf.x * FresnelSchlickRoughness(nov, float3(_F0, _F0, _F0), _Roughness).r + brdf.y;
                float3 envContribution = 0;
                float envLOD = _Roughness * 4.0; // Example LOD calculation based on roughness

                // Sample Cubemap and Reflective Probe contribution
                if (_UseCustomCubemap > 0)
                {
                    float3 reflectDir = reflect(-viewDirWS, normalWS);
                    // Sample the custom cubemap using the reflection direction and LOD for roughness
                    envContribution += texCUBElod(_CustomCubemap, float4(reflectDir, envLOD)).rgb;
                }
                else if (_UseReflectiveProbe > 0)
                {
                    float3 reflectDir = reflect(-viewDirWS, normalWS);
                    float perceptualRoughness = _Roughness;
                    envContribution += GlossyEnvironmentReflection(reflectDir, IN.positionWS, perceptualRoughness, 1.0, screenUV);
                }

                float3 irradianceIBL = 0;
                float3 up = float3(0, 1, 0);
                float3 right = normalize(cross(up, normalWS));
                up = normalize(cross(normalWS, right));
                float sampleDelta = 0.025;
                float nrSamples = 0.0;
                for(float phi = 0; phi < 2 * PI; phi += sampleDelta)
                {
                    for(float theta = 0; theta < 0.5 * PI; theta += sampleDelta)
                    {
                        float3 tangentSample = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
                        float3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * normalWS;
                        irradianceIBL += texCUBE(_CustomCubemap, sampleVec).rgb * cos(theta) * sin(theta);
                        nrSamples++;
                    }
                }
                irradianceIBL = (PI * irradianceIBL) / nrSamples;
                
                return float4(specular + envContribution + irradianceIBL, 1);
            }
            ENDHLSL
        }
    }
}