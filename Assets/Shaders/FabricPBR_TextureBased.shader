Shader "Custom/FabricPBR_TextureBased"
{
    Properties
    {
        [Header(Main Color)]
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)

        [Header(Normal Map)]
        [Toggle(Use Normal Map)] _UseNormalMap("Use Normal Map", Float) = 0
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0, 10)) = 1.0

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

        [Header(Fabric Micro BRDF)]
        _FabricSpecAttenuation("GGX Attenuation (0=fabric  1=standard)", Range(0,1)) = 0.3
        _FabricMicroNDFStrength("Yarn-Loop Normal Tilt Strength", Range(0,1)) = 0.5

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

            #include "FabricPBR_Common.hlsl"    // ★ shared CBUFFER
            #include "FabricPBR_TextureBased_Utilities.hlsl" // ★ shared BRDF/utilities

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

                // ════════════════════════════════════════════
                // Fabric Micro-BRDF  (mirrors ProceduralPattern)
                // ════════════════════════════════════════════
                // ── 1. Specular attenuation ──────────────────
                // Real fabric fibers scatter GGX broadly. Attenuate the
                // Cook-Torrance lobe and clearcoat, letting Charlie sheen
                // dominate — identical logic to the procedural knit shader.
                // _FabricSpecAttenuation: 0 = full fabric, 1 = standard PBR.
                float fabricSpecAtten = lerp(0.15, 1.0, _FabricSpecAttenuation);
                float fabricCCAtten   = lerp(0.25, 1.0, _FabricSpecAttenuation);
                float fabricSpecMul   = fabricSpecAtten;

                // ── 2. Yarn-loop micro-NDF ────────────────────
                // Mip filtering corrects colour/normal at distance but the
                // BRDF still receives the macro surface normal → vertical
                // GGX stripe on any cylinder. Fix: per-pixel stochastic
                // tilt whose magnitude grows with UV pixel footprint,
                // mirroring the cellsPerPx logic in the procedural shader.
                // texelsPerPx ≈ 1 when one 512-px texture cell spans one pixel.
                {
                    float2 uvDx = ddx(uv);
                    float2 uvDy = ddy(uv);
                    float  texelsPerPx = max(length(float2(uvDx.x, uvDy.x)),
                                             length(float2(uvDx.y, uvDy.y))) * 512.0;

                    float  yarnStochFade = smoothstep(0.05, 0.4, texelsPerPx)
                                           * _FabricMicroNDFStrength;
                    float  yarnAngle = InterleavedGradientNoise(IN.positionCS.xy + 17.3)
                                       * 6.2831853;
                    float  yarnTilt  = yarnStochFade * texelsPerPx * 0.3;
                    normalTS.x += cos(yarnAngle) * yarnTilt;
                    normalTS.y += sin(yarnAngle) * yarnTilt;
                    normalTS = normalize(normalTS);

                    // Roughness elevation: broadens lobe as yarn loops go
                    // sub-pixel — analytic equivalent of mip-level blurring.
                    roughness = saturate(roughness + texelsPerPx
                                         * 0.35 * _FabricMicroNDFStrength);
                }

                half3x3 tbnMatrix = half3x3(
                IN.tangentWS.xyz,
                IN.bitangentWS.xyz,
                IN.normalWS.xyz);

                float3 normalWS = normalize(
                TransformTangentToWorld(normalTS, tbnMatrix));

                float3 tangentWS = normalize(IN.tangentWS.xyz
                - normalWS * dot(normalWS, IN.tangentWS.xyz));

                float3 specNormalWS = normalWS;

                float nov     = max(dot(normalWS,     viewDirWS), 0.0001);
                float specNoV = max(dot(specNormalWS,  viewDirWS), 0.0001);

                float clearcoatWeight = saturate(_ClearCoat);

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

                float3 kS = FresnelSchlickRoughness(specNoV, F0, roughness);
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

                float2 brdf   = EnvBRDFApprox(roughness, specNoV);  // ← specNoV
                float  envLOD = roughness * 6.0;

                float3 ibl = CalculateIBL(
                specNormalWS, viewDirWS, IN.positionWS, screenUV,  // ← specNormalWS
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
                float  noh = max(dot(specNormalWS, h), 0.0);   // ← specNormalWS
                float  voh = max(dot(viewDirWS, h), 0.0);
                float  hol = max(dot(h, mainLight.direction), 0.0);

                float3 F_direct = FresnelSchlick(voh, F0);
                float  D_direct = DistributionGGXAnisotropic(
                specNormalWS, tangentWS, h, roughness, anisotropy);  // ← specNormalWS
                float  G_direct = GeometrySmithSchlickGGX(specNoV, nol, roughness);  // ← specNoV
                float3 specular = (D_direct * G_direct * F_direct)
                / max(4.0 * specNoV * nol, 0.001) * fabricSpecMul;  // ← specNoV + fabricSpecMul

                float3 diffuse = (1.0 - F_direct) * (1.0 - metallic)
                * (1.0 - sheenAlbedo) * albedo / PI;

                float3 sheen = EvaluateSheen(
                _SheenColor.rgb, _Sheen, _SheenRoughness,
                noh, specNoV, nol);                              // ← specNoV

                float3 clearcoat = EvaluateClearcoat(
                clearcoatWeight, 1.0 - _ClearCoatRoughness,
                noh, hol, specNoV, nol);                         // ← specNoV
                clearcoat *= fabricCCAtten;

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
                float  aNoH = max(dot(specNormalWS, aH), 0.0);    // ← specNormalWS
                float  aVoH = saturate(dot(viewDirWS, aH));
                float  aHoL = max(dot(aH, light.direction), 0.0);

                float3 aF = FresnelSchlick(aVoH, F0);

                float3 aSpec = EvaluateSpecular(
                specNormalWS, viewDirWS, light.direction,       // ← specNormalWS
                tangentWS, F0, roughness, anisotropy) * fabricSpecMul;  // ← fabricSpecMul

                float3 aDiff = (1.0 - aF) * (1.0 - metallic)
                * (1.0 - sheenAlbedo) * albedo / PI;

                float3 aSheen = EvaluateSheen(
                _SheenColor.rgb, _Sheen, _SheenRoughness,
                aNoH, specNoV, aNoL);

                float3 aCC = EvaluateClearcoat(
                clearcoatWeight, 1.0 - _ClearCoatRoughness,
                aNoH, aHoL, specNoV, aNoL);
                aCC *= fabricCCAtten;

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

            half4 ShadowFrag(Varyings IN) : SV_TARGET
            {
                float opacity;


                opacity = _Opacity * _BaseColor.a;
                if (_UseOpacityMap > 0)
                opacity *= SAMPLE_TEXTURE2D(_OpacityMap, sampler_OpacityMap, IN.uv).r;
                

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

            half DepthFrag(Varyings IN) : SV_TARGET
            {
                float opacity;

                
                opacity = _Opacity * _BaseColor.a;
                if (_UseOpacityMap > 0)
                opacity *= SAMPLE_TEXTURE2D(_OpacityMap, sampler_OpacityMap, IN.uv).r;
                

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