Shader "Custom/FabricPBR_ProceduralPattern"
{
    Properties
    {
        [Header(Main Color)]
        _BaseColor("Base Color", Color) = (1,1,1,1)

        [Header(Metallic)]
        _Metallic("Metallic", Range(0,1)) = 0.0

        [Header(Roughness)]
        _Roughness("Roughness", Range(0,1)) = 0.5

        [Header(Ambient Occlusion)]
        _AmbientOcclusion("Ambient Occlusion", Range(0,1)) = 1.0

        [Header(Anisotropy)]
        _Anisotropy("Anisotropy", Range(-1,1)) = 0.5

        [Header(Specular)]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularTint("Specular Tint (albedo blend)", Range(0,1)) = 0.0

        [Header(Emission)]
        _EmissionColor("Emission Color", Color) = (0,0,0,1)
        [Toggle(Enable Emission)] _EnableEmission("Enable Emission", Float) = 0

        [Header(Fabric Micro BRDF)]
        _FabricSpecAttenuation("GGX Attenuation (0=fabric  1=nylon-like)", Range(0,1)) = 0.8
        _FabricMicroNDFStrength("Yarn-Loop Normal Tilt Strength", Range(0,1)) = 0.2

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
        [Toggle] _UseAntiMoire("Enable Anti-Moire", Float) = 1
        _KnitUVTiling("UV Tiling Multiplier", Float) = 1.0
        _NumberOfLoops("Loop Count (per UV)", Float) = 40
        _LoopAspect("Loop Height over Width", Range(0.5, 2.5)) = 1.3
        _OpeningSize("Opening Radius", Range(0.01, 0.45)) = 0.12
        _OpeningSoftness("Opening Edge Softness", Range(0.005, 0.3)) = 0.08
        [Toggle] _UseAnalyticSoftness("Analytic fwidth Softness", Float) = 0
        _GapOpacity("Gap Min Opacity", Range(0, 1)) = 0.1
        _KnitNormalStrength("Knit Bump Strength", Range(0, 10)) = 1.5
        _KnitRoughnessVar("Thread Roughness Variation", Range(0, 0.3)) = 0.08
        _ThreadDarken("Thread Edge Darkening", Range(0, 1)) = 0.12
        _KnitJitter("Opening Position Jitter", Range(0, 0.15)) = 0.02
        _KnitNoiseScale("Fiber Noise Scale", Float) = 10

        _GapEdgeHighlight("Gap Edge Specular Boost", Range(0, 1)) = 0.8

        _GapShapePower ("Gap Shape (1=Diamond  2=Ellipse)", Range(1.0, 2.5)) = 1.5
        _GapWidthRatio ("Gap Width / Height Ratio", Range(0.5, 3.0)) = 1.5
        _ThreadWidth   ("Thread Bump Width", Range(0.005, 1.0)) = 0.06

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
        // R=0 (thigh/calf, sheer) → opacity multiplied by this value.  0 = fully transparent.
        // R=1 (ankle/knee, dense) → opacity unchanged (always 1.0 internally, never capped).
        _DenierMin("Sheer Area Opacity  (R=0, thigh/calf)", Range(0, 1)) = 0.0
        [HideInInspector] _DenierMax("Dense Area Opacity  (R=1, ankle/knee)", Range(0, 1)) = 1.0

        [Header(Strip Specular)]
        _StripSpecDirection("Fiber Direction (tangent space)", Vector) = (0, 1, 0, 0)
        _StripSpecIntensity("Strip Intensity", Range(0, 1)) = 0.3
        _StripSpecRoughness("Strip Roughness", Range(0.01, 1)) = 0.5
        _StripSpecAnisotropy("Strip Anisotropy", Range(0, 1)) = 0.4

        [Header(Clearcoat)]
        _ClearCoat("Clear Coat", Range(0,1)) = 0.0
        _ClearCoatRoughness("Clear Coat Roughness", Range(0,1)) = 0.5

        [Header(Transparency)]
        _Opacity("Base Opacity", Range(0, 1)) = 1.0
        _ShadowDensity("Shadow Density", Range(0, 2)) = 1.0
        [Toggle] _ForwardZWrite("Forward Depth Write (Transparent)", Float) = 0
        [Toggle(Use Vertex Alpha)] _UseVertexAlpha("Use Vertex Color Alpha", Float) = 0
        _FresnelOpacityPower("Edge Opacity Power", Range(1, 8)) = 3.0
        _FresnelOpacityStrength("Edge Opacity Boost", Range(0, 1)) = 0.0
        _SeeThruTint("See-Through Fabric Tint", Range(0, 1)) = 0.3

        [Header(Advanced)]
        _F0("F0 (Dielectric Reflectance)", Range(0,1)) = 0.04

        [Header(Reflection)]
        [Toggle(Use Reflective Probe)] _UseReflectiveProbe("Use Reflective Probe", Float) = 0
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

            #include "./FabricPBR_ProceduralPattern_Utilities.hlsl"
            #include "./FabricPBR_KnitSurface.hlsl"

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

                OUT.uv         = IN.texcoord;
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

                // return vertex colors for debug
                // return float4(IN.vertexColor.g, 0, 0, 1);

                float2 screenUV  = GetNormalizedScreenSpaceUV(IN.positionCS);
                float3 viewDirWS = SafeNormalize(
                half3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w));
                float2 uv = IN.uv;

                float3 albedo = _BaseColor.rgb;

                float metallic = _Metallic;

                float roughness = _Roughness;
                roughness = max(roughness, 0.045);

                float ao = _AmbientOcclusion;

                float anisotropy = _Anisotropy;

                // ── Normal ───────────────────────────────
                half3 normalTS = half3(0, 0, 1);

                // ══════════════════════════════════════════
                //   PROCEDURAL KNIT INTEGRATION
                // ══════════════════════════════════════════
                KnitSurfaceResult knitResult = EvaluateKnitSurface(
                    uv, IN.positionWS, IN.positionCS, IN.vertexColor,
                    normalTS, albedo, roughness);
                float knitThreadMask = knitResult.knitThreadMask;
                float knitEdgeMask   = knitResult.knitEdgeMask;
                float stretchAmount  = knitResult.stretchAmount;
                float knitAvgThread  = knitResult.knitAvgThread;
                normalTS  = knitResult.normalTS;
                albedo    = knitResult.albedo;
                roughness = knitResult.roughness;

                half3x3 tbnMatrix = half3x3(
                IN.tangentWS.xyz,
                IN.bitangentWS.xyz,
                IN.normalWS.xyz);

                float3 normalWS = normalize(
                TransformTangentToWorld(normalTS, tbnMatrix));

                // return float4(normalWS, 1);

                float3 tangentWS = normalize(IN.tangentWS.xyz
                - normalWS * dot(normalWS, IN.tangentWS.xyz));

                // ── Thread-direction tangent rotation ────
                if (_UseProceduralKnit > 0)
                {
                    float2 td = knitResult.threadDir;
                    float tdLen = length(td);
                    if (tdLen > 0.001)
                    {
                        td /= tdLen;
                        float3 bitangentWS_ortho = cross(normalWS, tangentWS);
                        tangentWS = normalize(tangentWS * td.x + bitangentWS_ortho * td.y);
                    }
                }

                float nov = max(dot(normalWS, viewDirWS), 0.0001);

                // ── Strip-specular tangent frame ─────────
                float3 bitangentWS_strip = cross(normalWS, tangentWS);
                float3 stripTangentWS = normalize(
                    tangentWS * _StripSpecDirection.x
                  + bitangentWS_strip * _StripSpecDirection.y
                  + normalWS * _StripSpecDirection.z);
                float3 stripBitangentWS = normalize(cross(normalWS, stripTangentWS));

                // ══════════════════════════════════════════
                // Opacity pipeline
                // ══════════════════════════════════════════
                float opacity = _Opacity * _BaseColor.a;
                float surfaceCoverage = saturate(_Opacity * _BaseColor.a);

                if (_UseVertexAlpha > 0)
                {
                opacity *= IN.vertexColor.a;
                surfaceCoverage *= IN.vertexColor.a;
                }

                if (_UseDenierFromVertexR > 0)
                {
                    // lerp(_DenierMin, 1.0, R):
                    //   R=0 (sheer zones: thigh/calf) → opacity *= _DenierMin  (near 0 = transparent)
                    //   R=1 (dense zones: ankle/knee) → opacity *= 1.0         (no reduction)
                    float denier = lerp(_DenierMin, 1.0,
                    IN.vertexColor.r);
                    opacity *= denier;
                }

                if (_UseProceduralKnit > 0)
                {
                    float gapTransparency = lerp(_GapOpacity, 1.0, knitThreadMask);
                    opacity *= gapTransparency;
                    surfaceCoverage *= gapTransparency;
                    // NOTE: stretch transparency is NOT applied as a separate opacity
                    // multiplier here. stretchAmount already feeds into stretchedOpening
                    // → knitThreadMask → gapTransparency above, so the transparency
                    // effect of stretching is fully captured there. A redundant
                    // stretchOpacity multiplier would compress the entire denier range
                    // uniformly across the mesh, killing per-vertex denier variation.
                }

                if (_FresnelOpacityStrength > 0)
                {
                    float edgeOpacity = pow(1.0 - nov, _FresnelOpacityPower)
                    * _FresnelOpacityStrength;
                    opacity = 1.0 - (1.0 - opacity) * (1.0 - edgeOpacity);
                    opacity = saturate(opacity);
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

                // opacity = saturate(pow(opacity * 4.0, 4.0));

                // // return opacity as red channel for debug
                // return float4(opacity, 0, 0, 1);

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

                float sheenAlbedo = SheenDirectionalAlbedo(_Sheen, _SheenRoughness);

                float3 kS = FresnelSchlickRoughness(nov, F0, roughness);
                float3 kD = (1.0 - kS) * (1.0 - metallic) * (1.0 - sheenAlbedo);

                // ── Fabric specular attenuation ──────────────
                float fabricSpecAtten = 1.0;
                float fabricCCAtten   = 1.0;
                if (_UseProceduralKnit > 0)
                {
                    float threadSpecAtten = lerp(0.15, 1.0, _FabricSpecAttenuation);
                    float threadCCAtten   = lerp(0.25, 1.0, _FabricSpecAttenuation);
                    fabricSpecAtten = lerp(1.0, threadSpecAtten, knitThreadMask);
                    fabricCCAtten   = lerp(1.0, threadCCAtten, knitThreadMask);
                }

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

                IBLComponents ibl = CalculateIBLComponents(
                normalWS, viewDirWS, IN.positionWS, screenUV,
                albedo, roughness,
                kS, kD,
                brdf, envLOD,
                bakedIrradiance);

                float3 indirectBodyLighting = ibl.diffuse;
                float3 indirectReflectLighting = ibl.specular * indirectAO * fabricSpecAtten;

                if (_FuzzIntensity > 0)
                {
                    float fuzzFresnel = pow(1.0 - nov, _FuzzPower);
                    float3 fuzz = _FuzzColor.rgb * _FuzzIntensity * fuzzFresnel;
                    float3 ambientLevel = max(bakedIrradiance, 0.05);
                    indirectBodyLighting += fuzz * ambientLevel * indirectAO;
                }

                if (_Subsurface > 0 && _AmbientTransmission > 0)
                {
                    float3 backIrradiance = max(0, SampleSH(-normalWS));
                    float3 indirectTrans  = _Subsurface * _AmbientTransmission
                    * _SubsurfaceColor.rgb
                    * backIrradiance * rcp(PI);
                    indirectBodyLighting += indirectTrans * indirectAO;
                }

                float3 emission = _EnableEmission > 0
                ? _EmissionColor.rgb : (float3)0;

                // ══════════════════════════════════════════
                //  MAIN LIGHT
                // ══════════════════════════════════════════
                Light  mainLight   = GetMainLight(inputData.shadowCoord);

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

                specular *= fabricSpecAtten;

                // ── Strip specular (Ward BRDF + Fresnel) ────────
                // Ward is a self-contained BRDF (normalization
                // handles geometric spreading); only Fresnel is
                // added for view-angle-dependent reflectance.
                float  D_strip = WardAnisotropicSpecular(
                    h, stripTangentWS, stripBitangentWS, normalWS,
                    _StripSpecRoughness, _StripSpecAnisotropy);
                float3 stripTerm = D_strip * F_direct
                    * _StripSpecIntensity * fabricSpecAtten;

                float3 diffuse = (1.0 - F_direct) * (1.0 - metallic)
                * (1.0 - sheenAlbedo) * albedo / PI;

                float3 sheen = EvaluateSheen(
                _SheenColor.rgb, _Sheen, _SheenRoughness,
                noh, nov, nol);

                float3 clearcoat = EvaluateClearcoat(
                _ClearCoat, 1.0 - _ClearCoatRoughness,
                noh, hol, nov, nol);
                clearcoat *= fabricCCAtten;

                float3 mainRadiance = mainLight.color * mainLight.shadowAttenuation;

                float3 mainBodyLighting = diffuse * nolWrap * mainRadiance;
                float3 mainReflectLighting = (specular + sheen + clearcoat + stripTerm) * nol * mainRadiance;

                if (_UseProceduralKnit > 0 && _GapEdgeHighlight > 0)
                {
                    float edgeNdH  = pow(noh, 4.0);
                    float edgeSpec = knitEdgeMask * _GapEdgeHighlight
                    * (edgeNdH * 0.7 + 0.3 * nol);
                    mainReflectLighting += edgeSpec * mainRadiance;
                }

                mainBodyLighting += EvaluateTransmission(
                normalWS, viewDirWS, mainLight.direction,
                mainLight.color * mainLight.shadowAttenuation,
                _Subsurface, _SubsurfaceColor.rgb,
                _TransmissionDistortion, _TransmissionPower);

                // ══════════════════════════════════════════
                //  ADDITIONAL LIGHTS
                // ══════════════════════════════════════════
                float3 addBodyLighting = 0;
                float3 addReflectLighting = 0;
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
                aSpec *= fabricSpecAtten;

                float  aD_strip = WardAnisotropicSpecular(
                    aH, stripTangentWS, stripBitangentWS, normalWS,
                    _StripSpecRoughness, _StripSpecAnisotropy);
                float3 aStripTerm = aD_strip * aF
                    * _StripSpecIntensity * fabricSpecAtten;

                float3 aDiff = (1.0 - aF) * (1.0 - metallic)
                * (1.0 - sheenAlbedo) * albedo / PI;

                float3 aSheen = EvaluateSheen(
                _SheenColor.rgb, _Sheen, _SheenRoughness,
                aNoH, nov, aNoL);

                float3 aCC = EvaluateClearcoat(
                _ClearCoat, 1.0 - _ClearCoatRoughness,
                aNoH, aHoL, nov, aNoL);
                aCC *= fabricCCAtten;

                float3 lightRad = light.color
                * light.distanceAttenuation
                * light.shadowAttenuation;

                addBodyLighting += aDiff * aNoLWrap * lightRad;
                addReflectLighting += (aSpec + aSheen + aCC + aStripTerm) * aNoL * lightRad;

                if (_UseProceduralKnit > 0 && _GapEdgeHighlight > 0)
                {
                    float aEdge = knitEdgeMask * _GapEdgeHighlight
                    * (pow(aNoH, 4.0) * 0.7 + 0.3 * aNoL);
                    addReflectLighting += aEdge * lightRad;
                }

                addBodyLighting += EvaluateTransmission(
                normalWS, viewDirWS, light.direction,
                light.color * light.distanceAttenuation * light.shadowAttenuation,
                _Subsurface, _SubsurfaceColor.rgb,
                _TransmissionDistortion, _TransmissionPower);
                LIGHT_LOOP_END

                // ══════════════════════════════════════════
                //  FINAL COMPOSITION
                // ══════════════════════════════════════════
                float3 fabricBodyColor = indirectBodyLighting
                + mainBodyLighting
                + addBodyLighting
                + emission;

                float3 fabricReflectColor = indirectReflectLighting
                + mainReflectLighting
                + addReflectLighting;

                if (_TwoLayerDarkening > 0)
                {
                    float edgeDarken = 1.0 - twoLayerGrazing * 0.35;
                    fabricBodyColor *= edgeDarken;
                    fabricReflectColor *= edgeDarken;
                }

                fabricBodyColor = MixFog(fabricBodyColor, IN.fogFactor);
                fabricReflectColor = MixFog(fabricReflectColor, IN.fogFactor);

                // Projected fiber coverage increases toward grazing angles,
                // so front-surface reflection should fade much less than
                // body transmission in sheer regions.
                float reflectCoverage = saturate(surfaceCoverage / max(sqrt(nov), 0.35));

                float3 finalColor = lerp(tintedScene, fabricBodyColor, opacity)
                + fabricReflectColor * reflectCoverage;

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
            #include "FabricPBR_KnitMask_Simple.hlsl"

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
                OUT.uv = IN.texcoord;
                OUT.positionWS = posWS;
                OUT.vertexColor = IN.color;
                return OUT;
            }

            half4 ShadowFrag(Varyings IN) : SV_TARGET
            {
                float opacity;

                if (_UseProceduralKnit > 0)
                {
                    float stretchAmount = ComputeSimpleStretchAmount(IN.uv, IN.positionWS, IN.vertexColor);
                    float threadMask = EvaluateSimpleKnitMask(IN.uv, stretchAmount, IN.positionCS.xy);
                    opacity = _Opacity * _BaseColor.a;
                    opacity *= lerp(_GapOpacity, 1.0, threadMask);
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
                opacity *= lerp(_DenierMin, 1.0, IN.vertexColor.r);

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
            #include "FabricPBR_KnitMask_Simple.hlsl"

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
                OUT.uv = IN.texcoord;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.vertexColor = IN.color;
                return OUT;
            }

            half DepthFrag(Varyings IN) : SV_TARGET
            {
                float opacity;

                if (_UseProceduralKnit > 0)
                {
                    float stretchAmount = ComputeSimpleStretchAmount(IN.uv, IN.positionWS, IN.vertexColor);
                    float threadMask = EvaluateSimpleKnitMask(IN.uv, stretchAmount, IN.positionCS.xy);
                    opacity = _Opacity * _BaseColor.a;
                    opacity *= lerp(_GapOpacity, 1.0, threadMask);
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
                opacity *= lerp(_DenierMin, 1.0, IN.vertexColor.r);

                opacity = saturate(opacity);

                float dither = StableDitherWS(IN.positionWS);
                clip(opacity - dither);
                return 0;
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Lit"
}