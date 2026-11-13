Shader "Custom/FabricPBR_ProceduralPattern"
{
    // ─────────────────────────────────────────────────────────────────────
    // Sheer stocking layer for a toon-shaded leg.
    //
    // The stocking mesh is a shell that sits on top of an opaque leg mesh.
    // This shader does NOT fake the skin: it alpha-blends over the leg that
    // is already in the frame buffer, so the leg's own toon lighting and
    // shadows show through.
    //
    //   density   one optical depth "tau" built from the base sheerness, the
    //             dense-zone mask (welt / heel / toe), stretch and the
    //             optional knit texture
    //   sheerness T = exp(-tau / N.V)  → sheer facing the camera, opaque at
    //             the silhouette
    //   lighting  toon ramp for the fabric colour, one soft sheen band and
    //             one broad highlight
    //
    // Render order: last in the opaque range, depth write on. The leg must
    // be an opaque material drawn before it (any queue below 2500).
    // Depth Priming must stay disabled on the URP renderer, because this
    // shader has no depth prepass.
    // ─────────────────────────────────────────────────────────────────────
    Properties
    {
        [Header(Fabric)]
        _BaseColor("Fabric Color", Color) = (0.05, 0.05, 0.06, 1)

        [Header(Sheerness)]
        // Opacity and strength sliders are perceptual: 0.5 looks half as
        // strong as 1 on screen. They are converted to linear light in the
        // fragment shader.
        _FacingOpacity("Opacity Facing Camera", Range(0, 1)) = 0.5
        _ViewDependence("View Dependence (0 = flat  1 = physical)", Range(0, 1)) = 1.0
        _GrazingLimit("Silhouette Limit (min N.V)", Range(0.02, 0.5)) = 0.12

        [Header(Dense Zones  (welt  heel  toe))]
        _DenseZoneOpacity("Dense Zone Opacity", Range(0, 1)) = 0.7
        [Toggle] _UseDenierFromVertexR("Vertex Red = Dense Zone", Float) = 0
        [Toggle] _UseDensityMask("Use Density Mask Texture", Float) = 0
        [NoScaleOffset] _DensityMask("Density Mask (R = dense, UV0, not tiled)", 2D) = "black" {}

        [Header(Stretch)]
        [Toggle] _UseStretchFromVertexG("Vertex Green = Stretch", Float) = 0
        _StretchSheerness("Stretch Makes Sheerer", Range(0, 1)) = 0.2

        [Header(Live Tension)]
        // Needs the StockingTension component on the same object. It measures
        // how much the fabric is stretched or squashed by the current pose.
        [Toggle(_LIVE_TENSION)] _LiveTension("Live Tension (needs StockingTension)", Float) = 0
        _TensionSheerness("Tension Makes Sheerer (1 = physical)", Range(0, 10)) = 1.0
        [Toggle] _TensionDebug("Debug View (red = stretched  blue = squashed)", Float) = 0

        [Header(Wrinkles  (needs Live Tension))]
        // Folds appear where the fabric is squashed, such as behind a bent knee.
        [Toggle] _UseWrinkleMap("Use Wrinkle Texture", Float) = 0
        // Same packing as the knit detail. Import with sRGB OFF, mip maps ON,
        // Texture Type Default (not Normal map).
        [NoScaleOffset] _WrinkleMap("Wrinkle Map (RG = normal XY, B = fold height)", 2D) = "bump" {}
        _WrinkleTiling("Wrinkle Tiling", Float) = 20
        _WrinkleAngle("Wrinkle Rotation (degrees)", Range(0, 180)) = 0
        _WrinkleStrength("Wrinkle Strength", Range(0, 2)) = 0.6
        _WrinkleDensity("Wrinkle Darkening", Range(0, 1)) = 0.3
        _WrinkleSensitivity("Wrinkle Sensitivity", Range(1, 10)) = 4.0

        [Header(Toon Shading)]
        _ShadeColor("Shade Tint (multiplies fabric color)", Color) = (0.55, 0.5, 0.6, 1)
        _ShadeStep("Shade Step", Range(0, 1)) = 0.5
        _ShadeFeather("Shade Feather", Range(0.0001, 0.5)) = 0.05
        _AmbientIntensity("Ambient Intensity", Range(0, 2)) = 0.5

        [Header(Sheen Band)]
        // A broad soft band on the lit side, just inside the silhouette.
        _SheenColor("Sheen Color", Color) = (1, 1, 1, 1)
        _SheenStrength("Sheen Strength", Range(0, 1)) = 0.3
        _SheenPosition("Sheen Position (0 = edge  1 = centre)", Range(0, 1)) = 0.35
        _SheenWidth("Sheen Width", Range(0.05, 1)) = 0.3
        _SheenLightWrap("Sheen Light Wrap", Range(0, 1)) = 0.5
        _SheenAmbient("Sheen From Ambient", Range(0, 1)) = 0.3

        [Header(Soft Highlight)]
        _HighlightColor("Highlight Color", Color) = (1, 1, 1, 1)
        _HighlightStrength("Highlight Strength", Range(0, 1)) = 0.25
        _HighlightRoughness("Highlight Roughness", Range(0.2, 1)) = 0.55

        [Header(Pearl and Glints)]
        // Pearl: a soft grainy shimmer. Glints: sparse sparkles that twinkle
        // when the light or camera moves. Both are fixed to the UVs.
        _PearlColor("Pearl Color", Color) = (1, 0.95, 0.9, 1)
        _PearlAmount("Pearl Strength", Range(0, 1)) = 0.2
        _PearlRandomness("Pearl Grain Contrast", Range(0, 1)) = 0.5
        _PearlEdge("Pearl Follows Sheen Band", Range(0, 1)) = 0.5
        _PearlGrainScale("Grain Scale (grains per UV)", Float) = 600
        _GlintStrength("Glint Strength", Range(0, 5)) = 0.5
        _GlintDensity("Glint Density", Range(0, 1)) = 0.1
        _GlintSharpness("Glint Sharpness", Range(20, 600)) = 200

        [Header(Knit Detail  (close ups only))]
        [Toggle] _UseKnitDetail("Use Knit Detail Texture", Float) = 0
        // Import with sRGB OFF and mip maps ON.
        [NoScaleOffset] _KnitDetailMap("Knit Detail (RG = normal XY, B = thread coverage)", 2D) = "gray" {}
        _KnitTiling("Knit Tiling", Float) = 200
        // Use when the mesh UVs are stretched and the weave looks like lines.
        _KnitAspect("Knit Vertical Stretch (1 = square)", Range(0.1, 10)) = 1.0
        _KnitDensityStrength("Knit Density Strength", Range(0, 1)) = 0.5
        _KnitNormalStrength("Knit Normal Strength", Range(0, 2)) = 0.5

        [Header(Skin Tint  (coloured tights))]
        // Colours the skin seen through the fabric, for tights that are not
        // black or grey. White = no tint.
        [Toggle] _UseSkinTint("Tint Skin Through Fabric", Float) = 0
        _SkinTint("Skin Tint", Color) = (1, 1, 1, 1)

        [Header(Tears)]
        // The mask is painted and assigned by the StockingTear component.
        // R = hole, G = run (ladder).
        [Toggle] _UseTearMask("Use Tear Mask", Float) = 0
        [NoScaleOffset] _TearMask("Tear Mask (R = hole, G = run)", 2D) = "black" {}
        _TearRagged("Ragged Edge", Range(0, 1)) = 0.5
        _TearNoiseScale("Ragged Edge Scale", Float) = 150
        _TearRimWidth("Rolled Edge Width", Range(0, 0.4)) = 0.15
        _TearRimDensity("Rolled Edge Density", Range(0, 4)) = 2.0
        _TearTensionOpen("Opens Wider When Stretched", Range(0, 4)) = 1.0
        _RunSheerness("Run Sheerness", Range(0, 1)) = 0.85
        _RunThreadStrength("Run Cross Threads", Range(0, 1)) = 0.7
        _RunThreadScale("Run Cross Threads per UV", Float) = 400
        _RunThreadAngle("Run Thread Rotation (degrees)", Range(0, 180)) = 90

        [Header(Outline)]
        // Same unit as the toon shader's Outline Thickness. Make it at least
        // as wide as the leg's outline so it covers it.
        _OutlineWidth("Outline Width (0 = off)", Range(0, 5)) = 0
        _OutlineColor("Outline Color", Color) = (0.02, 0.02, 0.03, 1)

        [Header(Depth)]
        _OffsetFactor("Depth Offset Factor", Float) = -1
        _OffsetUnits("Depth Offset Units", Float) = -1
    }

    // ─────────────────────────────────────────────────────────────────────
    // Shared by every pass. The material values must be identical in all
    // passes for the SRP Batcher.
    // ─────────────────────────────────────────────────────────────────────
    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    TEXTURE2D(_TearMask);   SAMPLER(sampler_TearMask);

    CBUFFER_START(UnityPerMaterial)
        float4 _BaseColor;

        float  _FacingOpacity;
        float  _ViewDependence;
        float  _GrazingLimit;

        float  _DenseZoneOpacity;
        float  _UseDenierFromVertexR;
        float  _UseDensityMask;

        float  _UseStretchFromVertexG;
        float  _StretchSheerness;

        float  _LiveTension;
        float  _TensionSheerness;
        float  _TensionDebug;

        float  _WrinkleStrength;
        float  _WrinkleDensity;
        float  _WrinkleSensitivity;
        float  _WrinkleTiling;
        float  _UseWrinkleMap;
        float  _WrinkleAngle;

        float4 _ShadeColor;
        float  _ShadeStep;
        float  _ShadeFeather;
        float  _AmbientIntensity;

        float4 _SheenColor;
        float  _SheenStrength;
        float  _SheenPosition;
        float  _SheenWidth;
        float  _SheenLightWrap;
        float  _SheenAmbient;

        float4 _HighlightColor;
        float  _HighlightStrength;
        float  _HighlightRoughness;

        float4 _PearlColor;
        float  _PearlAmount;
        float  _PearlRandomness;
        float  _PearlEdge;
        float  _PearlGrainScale;
        float  _GlintStrength;
        float  _GlintDensity;
        float  _GlintSharpness;

        float  _UseKnitDetail;
        float4 _KnitDetailMap_TexelSize;
        float4 _WrinkleMap_TexelSize;
        float  _KnitTiling;
        float  _KnitAspect;
        float  _KnitDensityStrength;
        float  _KnitNormalStrength;

        float  _UseSkinTint;
        float4 _SkinTint;

        float  _UseTearMask;
        float  _TearRagged;
        float  _TearNoiseScale;
        float  _TearRimWidth;
        float  _TearRimDensity;
        float  _TearTensionOpen;
        float  _RunSheerness;
        float  _RunThreadStrength;
        float  _RunThreadScale;
        float  _RunThreadAngle;

        float  _OutlineWidth;
        float4 _OutlineColor;

        float  _OffsetFactor;
        float  _OffsetUnits;
    CBUFFER_END

    #ifdef _LIVE_TENSION
        // One value per vertex, written every frame by StockingTension:
        // current surface area / rest surface area. 1 = relaxed.
        StructuredBuffer<float> _TensionBuffer;
    #endif

    float3 GrainHash(float2 p)
    {
        float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
        p3 += dot(p3, p3.yxz + 33.33);
        return frac((p3.xxy + p3.yzz) * p3.zyx);
    }

    // Soft random brightness 0..1, blended between the four nearest
    // grid points so grains are blobs, not squares.
    float GrainBrightness(float2 gridUV)
    {
        float2 corner = floor(gridUV - 0.5);
        float2 w = frac(gridUV - 0.5);
        w = w * w * (3.0 - 2.0 * w);
        float b00 = GrainHash(corner).x;
        float b10 = GrainHash(corner + float2(1.0, 0.0)).x;
        float b01 = GrainHash(corner + float2(0.0, 1.0)).x;
        float b11 = GrainHash(corner + float2(1.0, 1.0)).x;
        return lerp(lerp(b00, b10, w.x), lerp(b01, b11, w.x), w.y);
    }

    // Tears, from the mask painted by StockingTear.
    //   x = 1 inside a hole
    //   y = 1 on the rolled edge around a hole
    //   z = 1 inside a run (ladder)
    // The mask holds soft blobs; noise makes hole borders ragged, and
    // stretched fabric pulls a hole wider.
    float3 EvaluateTear(float2 uv, float tension)
    {
        float2 mask = SAMPLE_TEXTURE2D(_TearMask, sampler_TearMask, uv).rg;

        float noise = GrainBrightness(uv * _TearNoiseScale) * 0.65
                    + GrainBrightness(uv * _TearNoiseScale * 2.7 + 19.1) * 0.35;

        float opened = mask.r * (1.0 + max(tension - 1.0, 0.0) * _TearTensionOpen);

        // Noise only acts where the mask is present, so it cannot open
        // holes in untouched fabric.
        float value = opened + (noise - 0.5) * _TearRagged * saturate(mask.r * 4.0);

        float soft = max(fwidth(value), 0.01);
        float hole = smoothstep(0.5 - soft, 0.5 + soft, value);
        float rim  = smoothstep(0.5 - _TearRimWidth - soft, 0.5, value) * (1.0 - hole);
        float run  = smoothstep(0.25, 0.6, mask.g) * (1.0 - hole);
        return float3(hole, rim, run);
    }

    ENDHLSL

    SubShader
    {
        // AlphaTest+50 = 2500 = last slot of the opaque range.
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Transparent" "Queue" = "AlphaTest+50" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual
            Offset [_OffsetFactor], [_OffsetUnits]
            // Premultiplied alpha: rgb is already multiplied by coverage.
            Blend One OneMinusSrcAlpha

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            // Live tension reads a per-vertex buffer, which needs target 4.5.
            #pragma target 4.5
            #pragma shader_feature_local _LIVE_TENSION

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH

            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK

            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            TEXTURE2D(_DensityMask);    SAMPLER(sampler_DensityMask);
            TEXTURE2D(_KnitDetailMap);  SAMPLER(sampler_KnitDetailMap);
            TEXTURE2D(_WrinkleMap);     SAMPLER(sampler_WrinkleMap);

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
                #ifdef _LIVE_TENSION
                    uint vertexID        : SV_VertexID;
                #endif
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
                float  tension     : TEXCOORD12;

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

                OUT.tension = 1.0;
                #ifdef _LIVE_TENSION
                    // 0 means the buffer was never filled: treat as relaxed.
                    float tensionValue = _TensionBuffer[IN.vertexID];
                    OUT.tension = tensionValue > 0.0 ? tensionValue : 1.0;
                #endif

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

            // Index of a texture's smallest mip (1x1), from its size in pixels.
            // Sampling it gives the average of the whole texture.
            float SmallestMip(float4 texelSize)
            {
                return log2(max(max(texelSize.z, texelSize.w), 1.0));
            }

            // ── Lighting helpers ─────────────────────────

            // Toon ramp: 0 = shade, 1 = lit. Shadows push the surface into shade.
            float ToonRamp(float3 N, float3 L, float shadowAtten)
            {
                float halfLambert = 0.5 * dot(N, L) + 0.5;
                float feather = max(_ShadeFeather, 0.0001);
                return smoothstep(_ShadeStep - feather, _ShadeStep + feather,
                                  halfLambert * shadowAtten);
            }

            // Slider value (perceptual) → linear light.
            float PerceptualToLinear(float x)
            {
                return pow(saturate(x), 2.2);
            }

            // Perceptual opacity → linear opacity. 0.5 on the slider darkens
            // the skin to half its on-screen brightness.
            float PerceptualOpacity(float x)
            {
                return 1.0 - pow(1.0 - saturate(x), 2.2);
            }

            // Wrapped N.L used to light the sheen band.
            float SheenLight(float3 N, float3 L)
            {
                return saturate((dot(N, L) + _SheenLightWrap) / (1.0 + _SheenLightWrap));
            }

            // GGX lobe normalised to a peak of 1, so intensity and width are
            // independent controls. alphaSq is GGX alpha squared.
            float SoftHighlight(float3 N, float3 V, float3 L, float alphaSq)
            {
                float3 H   = SafeNormalize(V + L);
                float  noh = saturate(dot(N, H));
                float  d   = noh * noh * (alphaSq - 1.0) + 1.0;
                float  lobe = alphaSq / max(d * d, 1e-6);   // peak = 1 / alphaSq
                return lobe * alphaSq * saturate(dot(N, L));
            }

            // ── Pearl grain and glints ───────────────────
            // The surface is divided into a grid of grains fixed to the UVs.
            // Every grain has a random brightness (pearl) and some grains
            // carry a tiny tilted mirror (glint). For glints, two grid sizes
            // are blended so a grain never gets smaller than about two
            // pixels: nothing aliases and the sparkle stays visible at any
            // distance.

            struct GrainLayer
            {
                float  glintMask;   // 1 inside a grain that carries a glint
                float3 glintNormal; // world-space normal of that glint
            };

            GrainLayer EvaluateGrainLayer(float2 gridUV, float3 N, float3 T, float3 B)
            {
                float2 cell  = floor(gridUV);
                float2 local = frac(gridUV) - 0.5;

                float3 hA = GrainHash(cell);
                float3 hB = GrainHash(cell + 71.7);

                GrainLayer g;

                // Round dot, slightly off-centre, only in some grains.
                float d = length(local - (hB.yz - 0.5) * 0.4);
                float dotMask = 1.0 - smoothstep(0.15, 0.3, d);
                g.glintMask = dotMask * step(hB.x, _GlintDensity);

                // Random tilt, so each glint lights up at its own angle.
                float2 tilt = (hA.yz * 2.0 - 1.0) * 0.4;
                g.glintNormal = normalize(N + T * tilt.x + B * tilt.y);
                return g;
            }

            float GlintLobe(GrainLayer g0, GrainLayer g1, float blend, float3 V, float3 L)
            {
                float3 H = SafeNormalize(V + L);
                float a = g0.glintMask * pow(saturate(dot(g0.glintNormal, H)), _GlintSharpness);
                float b = g1.glintMask * pow(saturate(dot(g1.glintNormal, H)), _GlintSharpness);
                return lerp(a, b, blend);
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
                float3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w));

                // Geometric normal drives sheerness, toon ramp and sheen band,
                // so none of them pick up per-thread noise.
                float3 geomNormalWS = normalize(IN.normalWS.xyz);
                float  novG = saturate(dot(geomNormalWS, viewDirWS));

                // ══════════════════════════════════════════
                // Knit detail (optional, close-ups only)
                // Mip mapping averages it out at game distance.
                // ══════════════════════════════════════════
                float  knitDensity  = 1.0;
                float3 detailNormalWS = geomNormalWS;
                if (_UseKnitDetail > 0)
                {
                    float2 knitUV = IN.uv * _KnitTiling * float2(1.0, _KnitAspect);
                    float4 knit = SAMPLE_TEXTURE2D(_KnitDetailMap, sampler_KnitDetailMap, knitUV);

                    // B = thread coverage. It is divided by the texture's own
                    // average (read from the smallest mip), so turning the
                    // detail on never changes the overall sheerness, whatever
                    // the average of the texture is. Needs mip maps.
                    float knitAverage = SAMPLE_TEXTURE2D_LOD(_KnitDetailMap, sampler_KnitDetailMap,
                        float2(0.5, 0.5), SmallestMip(_KnitDetailMap_TexelSize)).b;
                    knitDensity = lerp(1.0, knit.b / max(knitAverage, 0.05),
                                       _KnitDensityStrength);

                    float2 nXY = (knit.rg * 2.0 - 1.0) * _KnitNormalStrength;
                    float  nZ  = sqrt(saturate(1.0 - dot(nXY, nXY)));
                    detailNormalWS = normalize(
                        IN.tangentWS.xyz   * nXY.x
                      + IN.bitangentWS.xyz * nXY.y
                      + geomNormalWS       * nZ);
                }

                // ══════════════════════════════════════════
                // Density → transmittance
                // ══════════════════════════════════════════
                float dense = 0.0;
                if (_UseDenierFromVertexR > 0)
                {
                    dense = saturate(IN.vertexColor.r);
                }
                if (_UseDensityMask > 0)
                {
                    dense = max(dense,
                        SAMPLE_TEXTURE2D(_DensityMask, sampler_DensityMask, IN.uv).r);
                }

                // Opacity when looking straight at the surface.
                float sheerOpacity = PerceptualOpacity(_FacingOpacity);
                float denseOpacity = max(PerceptualOpacity(_DenseZoneOpacity), sheerOpacity);
                float facingOpacity = lerp(sheerOpacity, denseOpacity, dense);

                // Optical depth at normal incidence.
                float tau = -log(max(1.0 - facingOpacity, 1e-4));

                if (_UseStretchFromVertexG > 0)
                {
                    tau *= 1.0 - saturate(IN.vertexColor.g) * _StretchSheerness;
                }

                // Live tension: the same yarn spread over a larger area is
                // thinner, and bunched up over a smaller area is denser.
                float tension = clamp(IN.tension, 0.25, 4.0);
                tau *= pow(tension, -_TensionSheerness);

                if (_TensionDebug > 0)
                {
                    float3 relaxed = float3(0.5, 0.5, 0.5);
                    float3 debugColor = tension > 1.0
                        ? lerp(relaxed, float3(1.0, 0.0, 0.0), saturate((tension - 1.0) * 2.0))
                        : lerp(relaxed, float3(0.0, 0.2, 1.0), saturate((1.0 - tension) * 2.0));
                    return float4(debugColor, 1.0);
                }

                // ══════════════════════════════════════════
                // Wrinkles: folds where the fabric is squashed
                // ══════════════════════════════════════════
                // lightNormalWS feeds the sheen; it is the smooth normal
                // unless wrinkles tilt it.
                float3 lightNormalWS = geomNormalWS;

                if (_UseWrinkleMap > 0)
                {
                    float wrinkleAmount = saturate((1.0 - tension) * _WrinkleSensitivity);

                    float  wrinkleAngle = radians(_WrinkleAngle);
                    float2 wrinkleAxisX = float2(cos(wrinkleAngle), sin(wrinkleAngle));
                    float2 wrinkleAxisY = float2(-wrinkleAxisX.y, wrinkleAxisX.x);
                    float2 wrinkleUV = float2(dot(IN.uv, wrinkleAxisX), dot(IN.uv, wrinkleAxisY))
                                     * _WrinkleTiling;

                    float4 wrinkle = SAMPLE_TEXTURE2D(_WrinkleMap, sampler_WrinkleMap, wrinkleUV);

                    // Fold height relative to the texture's own average (its
                    // smallest mip), so wrinkles never change the overall
                    // sheerness: ridges get denser, valleys thinner.
                    float wrinkleAverage = SAMPLE_TEXTURE2D_LOD(_WrinkleMap, sampler_WrinkleMap,
                        float2(0.5, 0.5), SmallestMip(_WrinkleMap_TexelSize)).b;
                    float heightRatio = wrinkle.b / max(wrinkleAverage, 0.05);
                    tau *= max(1.0 + (heightRatio - 1.0) * _WrinkleDensity * wrinkleAmount, 0.2);

                    // Tilt the normal. The map is in the rotated frame, so
                    // turn it back into the mesh's tangent frame.
                    float2 mapXY  = (wrinkle.rg * 2.0 - 1.0) * _WrinkleStrength * wrinkleAmount;
                    float2 tiltUV = wrinkleAxisX * mapXY.x + wrinkleAxisY * mapXY.y;
                    float3 tiltWS = normalize(IN.tangentWS.xyz)   * tiltUV.x
                                  + normalize(IN.bitangentWS.xyz) * tiltUV.y;

                    lightNormalWS  = normalize(geomNormalWS + tiltWS);
                    detailNormalWS = normalize(detailNormalWS + tiltWS);
                }

                tau *= knitDensity;

                // ══════════════════════════════════════════
                // Tears
                // ══════════════════════════════════════════
                float tearHole = 0.0;
                if (_UseTearMask > 0)
                {
                    float3 tear = EvaluateTear(IN.uv, tension);
                    tearHole = tear.x;

                    // The fabric rolls up into a denser edge around a hole.
                    tau *= 1.0 + tear.y * _TearRimDensity;

                    // A run: most of the yarn is gone, thin cross threads remain.
                    float  threadAngle = radians(_RunThreadAngle);
                    float  threadCoord = dot(IN.uv, float2(cos(threadAngle), sin(threadAngle)))
                                       * _RunThreadScale;
                    float  threadWidth = 0.3;
                    float  threadSoft  = fwidth(threadCoord) * 2.0;
                    float  fromCentre  = abs(frac(threadCoord) - 0.5) * 2.0;
                    float  thread = 1.0 - smoothstep(threadWidth - threadSoft,
                                                     threadWidth + threadSoft, fromCentre);
                    // Too small to resolve: use the average thread coverage.
                    thread = lerp(thread, threadWidth, saturate(threadSoft - 0.5));

                    float runDensity = lerp(1.0 - _RunSheerness, 1.0, thread * _RunThreadStrength);
                    tau *= lerp(1.0, runDensity, tear.z);
                }

                // Light travels through more fabric at grazing angles.
                float pathLength = lerp(1.0,
                                        1.0 / max(novG, _GrazingLimit),
                                        _ViewDependence);

                float transmittance = exp(-tau * pathLength);
                float alpha = (1.0 - transmittance) * (1.0 - tearHole);

                // ══════════════════════════════════════════
                // Lighting setup
                // ══════════════════════════════════════════
                InputData inputData = (InputData)0;
                inputData.positionWS              = IN.positionWS;
                inputData.positionCS              = IN.positionCS;
                inputData.normalWS                = geomNormalWS;
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

                float3 ambient = inputData.bakedGI;

                // Highlight width, with specular anti-aliasing: normal
                // variation inside the pixel is added to alpha², capped so
                // the look does not change with camera distance.
                float3 dNdx = ddx(detailNormalWS);
                float3 dNdy = ddy(detailNormalWS);
                float  aaKernel = min(0.5 * (dot(dNdx, dNdx) + dot(dNdy, dNdy)), 0.18);
                float  hlAlpha   = _HighlightRoughness * _HighlightRoughness;
                float  hlAlphaSq = saturate(hlAlpha * hlAlpha + aaKernel);

                // Sheen band: a soft stripe that peaks where N.V equals
                // _SheenPosition, just inside the silhouette and not on the
                // very edge, so the edge itself stays dark.
                float novSheen = saturate(dot(lightNormalWS, viewDirWS));
                float sheenOffset = (novSheen - _SheenPosition) / max(_SheenWidth, 0.01);
                float sheenBand   = exp(-sheenOffset * sheenOffset);

                // Accumulators.
                //   bodyLight   : light on the fabric colour (toon ramp)
                //   sheenLight  : light that feeds the sheen band and pearl
                //   highlight   : soft highlight
                float3 bodyLight  = ambient * _AmbientIntensity + inputData.vertexLighting;
                float3 sheenLight = ambient * _SheenAmbient;
                float3 highlight  = 0;
                float3 glint      = 0;

                // Grain grid: pick the two grid sizes around "two pixels per grain".
                float2 grainUV = IN.uv * _PearlGrainScale;
                float  grainsPerPixel = max(length(ddx(grainUV)), length(ddy(grainUV)));
                float  grainLod   = max(log2(max(grainsPerPixel * 2.0, 1e-6)), 0.0);
                float  grainLevel = floor(grainLod);
                float  grainBlend = grainLod - grainLevel;

                float3 tangentWS   = normalize(IN.tangentWS.xyz);
                float3 bitangentWS = normalize(IN.bitangentWS.xyz);

                GrainLayer grain0 = EvaluateGrainLayer(grainUV / exp2(grainLevel),
                                                       geomNormalWS, tangentWS, bitangentWS);
                GrainLayer grain1 = EvaluateGrainLayer(grainUV / exp2(grainLevel + 1.0),
                                                       geomNormalWS, tangentWS, bitangentWS);

                // Pearl grain keeps its real size and fades to a smooth
                // average once grains are smaller than a pixel, so it never
                // shows as blotches at game distance. Only glints use the
                // two-size grid above.
                float pearlFade = 1.0 - smoothstep(0.35, 0.7, grainsPerPixel);
                float grainBrightness = lerp(0.5, GrainBrightness(grainUV), pearlFade);

                // ══════════════════════════════════════════
                //  MAIN LIGHT
                // ══════════════════════════════════════════
                Light mainLight = GetMainLight(inputData.shadowCoord);

                float mainRamp = ToonRamp(geomNormalWS, mainLight.direction,
                                          mainLight.shadowAttenuation);

                // The shade side keeps the light colour, tinted by _ShadeColor,
                // the same way the toon skin does.
                bodyLight  += mainLight.color * lerp(_ShadeColor.rgb, (float3)1, mainRamp);
                sheenLight += mainLight.color * mainLight.shadowAttenuation
                            * SheenLight(lightNormalWS, mainLight.direction);
                highlight  += mainLight.color * mainLight.shadowAttenuation
                            * SoftHighlight(detailNormalWS, viewDirWS,
                                            mainLight.direction, hlAlphaSq);
                glint      += mainLight.color * mainLight.shadowAttenuation
                            * saturate(dot(geomNormalWS, mainLight.direction))
                            * GlintLobe(grain0, grain1, grainBlend,
                                        viewDirWS, mainLight.direction);

                // ══════════════════════════════════════════
                //  ADDITIONAL LIGHTS
                // ══════════════════════════════════════════
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

                float3 lightRad = light.color * light.distanceAttenuation;

                bodyLight  += lightRad * ToonRamp(geomNormalWS, light.direction,
                                                  light.shadowAttenuation);
                sheenLight += lightRad * light.shadowAttenuation
                            * SheenLight(lightNormalWS, light.direction);
                highlight  += lightRad * light.shadowAttenuation
                            * SoftHighlight(detailNormalWS, viewDirWS,
                                            light.direction, hlAlphaSq);
                glint      += lightRad * light.shadowAttenuation
                            * saturate(dot(geomNormalWS, light.direction))
                            * GlintLobe(grain0, grain1, grainBlend,
                                        viewDirWS, light.direction);
                LIGHT_LOOP_END

                // ══════════════════════════════════════════
                //  FINAL COMPOSITION
                // ══════════════════════════════════════════
                float3 fabricColor = _BaseColor.rgb * bodyLight;

                float3 gloss = _SheenColor.rgb * PerceptualToLinear(_SheenStrength)
                                 * sheenBand * sheenLight
                             + _HighlightColor.rgb * PerceptualToLinear(_HighlightStrength)
                                 * highlight;

                // Pearl: soft light broken into grains, optionally confined
                // to the sheen band.
                float pearlGrain = lerp(1.0, grainBrightness * 2.0, _PearlRandomness);
                float pearlView  = lerp(1.0, sheenBand, _PearlEdge);
                gloss += _PearlColor.rgb * PerceptualToLinear(_PearlAmount)
                       * pearlGrain * pearlView * sheenLight;

                // Glints: small bright sparkles.
                gloss += _PearlColor.rgb * _GlintStrength * glint;

                // Fog. MixFog(x) = lerp(fogColor, x, k); subtracting MixFog(0)
                // leaves x * k, so the additive gloss does not add fog twice.
                float3 fogOnly = MixFog((float3)0, IN.fogFactor);
                fabricColor = MixFog(fabricColor, IN.fogFactor);
                gloss       = MixFog(gloss, IN.fogFactor) - fogOnly;

                // Both terms scale with coverage: no fabric, no fibres to shine.
                float3 premultiplied = (fabricColor + gloss) * alpha;

                // The SkinTint pass multiplies the finished pixel by the tint
                // afterwards. Dividing the fabric by it here cancels that out
                // for the fabric, so only the skin underneath ends up tinted.
                if (_UseSkinTint > 0)
                {
                    premultiplied /= max(_SkinTint.rgb, 0.05);
                }

                return float4(premultiplied, alpha);
            }
            ENDHLSL
        }

        // ═══════════════════════════════════════════════
        // Skin tint: multiplies the pixel by a colour after the fabric has
        // been blended. Together with the division in ForwardLit this gives
        //     skin * tint * (1 - alpha) + fabric
        // Must draw after ForwardLit.
        // ═══════════════════════════════════════════════
        Pass
        {
            Name "SkinTint"
            Tags { "LightMode" = "UniversalForwardOnly" }

            Cull Back
            ZWrite Off
            ZTest LEqual
            Offset [_OffsetFactor], [_OffsetUnits]
            Blend DstColor Zero
            ColorMask RGB

            HLSLPROGRAM
            #pragma vertex TintVert
            #pragma fragment TintFrag
            #pragma multi_compile_instancing

            // Same tension input as ForwardLit, so holes match in both passes.
            #pragma target 4.5
            #pragma shader_feature_local _LIVE_TENSION

            struct TintAttributes
            {
                float4 positionOS : POSITION;
                float2 texcoord   : TEXCOORD0;
                #ifdef _LIVE_TENSION
                    uint vertexID : SV_VertexID;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct TintVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float  tension    : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TintVaryings TintVert(TintAttributes IN)
            {
                TintVaryings OUT = (TintVaryings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                OUT.uv = IN.texcoord;

                OUT.tension = 1.0;
                #ifdef _LIVE_TENSION
                    float tensionValue = _TensionBuffer[IN.vertexID];
                    OUT.tension = tensionValue > 0.0 ? tensionValue : 1.0;
                #endif

                // Switched off: collapse every triangle so nothing is drawn.
                OUT.positionCS = _UseSkinTint > 0
                    ? TransformObjectToHClip(IN.positionOS.xyz)
                    : float4(0.0, 0.0, 0.0, 1.0);
                return OUT;
            }

            float4 TintFrag(TintVaryings IN) : SV_Target
            {
                float3 tint = max(_SkinTint.rgb, 0.05);

                // Skin seen through a hole is bare, so it is not tinted.
                if (_UseTearMask > 0)
                {
                    float tension = clamp(IN.tension, 0.25, 4.0);
                    tint = lerp(tint, (float3)1.0, EvaluateTear(IN.uv, tension).x);
                }

                return float4(tint, 1.0);
            }
            ENDHLSL
        }

        // ═══════════════════════════════════════════════
        // Outline: inverted hull in the stocking's colour. Made at least as
        // wide as the leg's own outline, it covers it.
        // ═══════════════════════════════════════════════
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            Cull Front
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex OutlineVert
            #pragma fragment OutlineFrag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            struct OutlineAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct OutlineVaryings
            {
                float4 positionCS : SV_POSITION;
                half   fogFactor  : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            OutlineVaryings OutlineVert(OutlineAttributes IN)
            {
                OutlineVaryings OUT = (OutlineVaryings)0;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                // Push the surface out along its normal.
                float3 positionOS = IN.positionOS.xyz
                                  + normalize(IN.normalOS) * (_OutlineWidth * 0.001);

                // Switched off: collapse every triangle so nothing is drawn.
                OUT.positionCS = _OutlineWidth > 0
                    ? TransformObjectToHClip(positionOS)
                    : float4(0.0, 0.0, 0.0, 1.0);
                OUT.fogFactor = ComputeFogFactor(OUT.positionCS.z);
                return OUT;
            }

            float4 OutlineFrag(OutlineVaryings IN) : SV_Target
            {
                return float4(MixFog(_OutlineColor.rgb, IN.fogFactor), 1.0);
            }
            ENDHLSL
        }

        // No ShadowCaster pass: the leg under the stocking casts the shadow.
        // No DepthOnly pass: depth is written by the forward pass above.
    }

    Fallback Off
}
