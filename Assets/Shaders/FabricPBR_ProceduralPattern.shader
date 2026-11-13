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
    //   lighting  toon ramp for the fabric colour, one soft rim sheen and
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
        _SheerOpacity("Opacity Facing Camera", Range(0, 0.98)) = 0.45
        _ViewDependence("View Dependence (0 = flat  1 = physical)", Range(0, 1)) = 1.0
        _GrazingLimit("Silhouette Limit (min N.V)", Range(0.02, 0.5)) = 0.12

        [Header(Dense Zones  (welt  heel  toe))]
        _DenseOpacity("Dense Zone Opacity", Range(0, 0.999)) = 0.95
        [Toggle] _UseDenierFromVertexR("Vertex Red = Dense Zone", Float) = 0
        [Toggle] _UseDensityMask("Use Density Mask Texture", Float) = 0
        [NoScaleOffset] _DensityMask("Density Mask (R = dense, UV0, not tiled)", 2D) = "black" {}

        [Header(Stretch)]
        [Toggle] _UseStretchFromVertexG("Vertex Green = Stretch", Float) = 0
        _StretchSheerness("Stretch Makes Sheerer", Range(0, 1)) = 0.5

        [Header(Toon Shading)]
        _ShadeColor("Shade Tint (multiplies fabric color)", Color) = (0.55, 0.5, 0.6, 1)
        _ShadeStep("Shade Step", Range(0, 1)) = 0.5
        _ShadeFeather("Shade Feather", Range(0.0001, 0.5)) = 0.05
        _AmbientIntensity("Ambient Intensity", Range(0, 2)) = 0.5

        [Header(Rim Sheen)]
        _SheenColor("Sheen Color", Color) = (1, 1, 1, 1)
        _SheenIntensity("Sheen Intensity", Range(0, 2)) = 0.35
        _SheenPower("Sheen Falloff", Range(0.5, 8)) = 3.0
        _SheenLightWrap("Sheen Light Wrap", Range(0, 1)) = 0.5
        _SheenAmbient("Sheen From Ambient", Range(0, 1)) = 0.3

        [Header(Soft Highlight)]
        _HighlightColor("Highlight Color", Color) = (1, 1, 1, 1)
        _HighlightIntensity("Highlight Intensity", Range(0, 2)) = 0.1
        _HighlightRoughness("Highlight Roughness", Range(0.2, 1)) = 0.55

        [Header(Pearl and Glints)]
        // Pearl: a soft grainy shimmer. Glints: sparse sparkles that twinkle
        // when the light or camera moves. Both are fixed to the UVs.
        _PearlColor("Pearl Color", Color) = (1, 0.95, 0.9, 1)
        _PearlStrength("Pearl Strength", Range(0, 2)) = 0.2
        _PearlRandomness("Pearl Grain Contrast", Range(0, 1)) = 0.5
        _PearlEdge("Pearl Towards Edge", Range(0, 1)) = 0.5
        _PearlGrainScale("Grain Scale (grains per UV)", Float) = 600
        _GlintStrength("Glint Strength", Range(0, 5)) = 0.5
        _GlintDensity("Glint Density", Range(0, 1)) = 0.1
        _GlintSharpness("Glint Sharpness", Range(20, 600)) = 200

        [Header(Knit Detail  (close ups only))]
        [Toggle] _UseKnitDetail("Use Knit Detail Texture", Float) = 0
        // Import with sRGB OFF and mip maps ON.
        [NoScaleOffset] _KnitDetailMap("Knit Detail (RG = normal XY, B = thread coverage)", 2D) = "gray" {}
        _KnitTiling("Knit Tiling", Float) = 200
        _KnitDensityStrength("Knit Density Strength", Range(0, 1)) = 0.5
        _KnitNormalStrength("Knit Normal Strength", Range(0, 2)) = 0.5

        [Header(Depth)]
        _OffsetFactor("Depth Offset Factor", Float) = -1
        _OffsetUnits("Depth Offset Units", Float) = -1
    }

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

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;

                float  _SheerOpacity;
                float  _ViewDependence;
                float  _GrazingLimit;

                float  _DenseOpacity;
                float  _UseDenierFromVertexR;
                float  _UseDensityMask;

                float  _UseStretchFromVertexG;
                float  _StretchSheerness;

                float4 _ShadeColor;
                float  _ShadeStep;
                float  _ShadeFeather;
                float  _AmbientIntensity;

                float4 _SheenColor;
                float  _SheenIntensity;
                float  _SheenPower;
                float  _SheenLightWrap;
                float  _SheenAmbient;

                float4 _HighlightColor;
                float  _HighlightIntensity;
                float  _HighlightRoughness;

                float4 _PearlColor;
                float  _PearlStrength;
                float  _PearlRandomness;
                float  _PearlEdge;
                float  _PearlGrainScale;
                float  _GlintStrength;
                float  _GlintDensity;
                float  _GlintSharpness;

                float  _UseKnitDetail;
                float  _KnitTiling;
                float  _KnitDensityStrength;
                float  _KnitNormalStrength;

                float  _OffsetFactor;
                float  _OffsetUnits;
            CBUFFER_END

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

            // ── Lighting helpers ─────────────────────────

            // Toon ramp: 0 = shade, 1 = lit. Shadows push the surface into shade.
            float ToonRamp(float3 N, float3 L, float shadowAtten)
            {
                float halfLambert = 0.5 * dot(N, L) + 0.5;
                float feather = max(_ShadeFeather, 0.0001);
                return smoothstep(_ShadeStep - feather, _ShadeStep + feather,
                                  halfLambert * shadowAtten);
            }

            // Wrapped N.L used to light the rim sheen.
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
            // carry a tiny tilted mirror (glint). Two grid sizes are blended
            // so a grain never gets smaller than about two pixels: there is
            // nothing to alias, and the sparkle stays visible at any distance.

            float3 GrainHash(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yxz + 33.33);
                return frac((p3.xxy + p3.yzz) * p3.zyx);
            }

            struct GrainLayer
            {
                float  brightness;  // random 0..1 per grain
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
                g.brightness = hA.x;

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

                // Geometric normal drives sheerness, toon ramp and rim sheen,
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
                    float4 knit = SAMPLE_TEXTURE2D(_KnitDetailMap, sampler_KnitDetailMap,
                                                   IN.uv * _KnitTiling);

                    // B = thread coverage. It is divided by the texture's own
                    // average (read from the smallest mip), so turning the
                    // detail on never changes the overall sheerness, whatever
                    // the average of the texture is. Needs mip maps.
                    float knitAverage = SAMPLE_TEXTURE2D_LOD(_KnitDetailMap, sampler_KnitDetailMap,
                                                             float2(0.5, 0.5), 16.0).b;
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
                float facingOpacity = lerp(_SheerOpacity,
                                           max(_DenseOpacity, _SheerOpacity), dense);

                // Optical depth at normal incidence.
                float tau = -log(max(1.0 - facingOpacity, 1e-4));

                if (_UseStretchFromVertexG > 0)
                {
                    tau *= 1.0 - saturate(IN.vertexColor.g) * _StretchSheerness;
                }

                tau *= knitDensity;

                // Light travels through more fabric at grazing angles.
                float pathLength = lerp(1.0,
                                        1.0 / max(novG, _GrazingLimit),
                                        _ViewDependence);

                float transmittance = exp(-tau * pathLength);
                float alpha = 1.0 - transmittance;

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

                float rim = pow(1.0 - novG, _SheenPower);

                // Accumulators.
                //   bodyLight   : light on the fabric colour (toon ramp)
                //   sheenLight  : light that feeds the rim sheen
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
                float grainBrightness = lerp(grain0.brightness, grain1.brightness, grainBlend);

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
                            * SheenLight(geomNormalWS, mainLight.direction);
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
                            * SheenLight(geomNormalWS, light.direction);
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

                float3 gloss = _SheenColor.rgb * _SheenIntensity * rim * sheenLight
                             + _HighlightColor.rgb * _HighlightIntensity * highlight;

                // Pearl: soft light broken into grains, optionally pushed
                // towards the silhouette. Averages to _PearlStrength.
                float pearlGrain = lerp(1.0, grainBrightness * 2.0, _PearlRandomness);
                float pearlView  = lerp(1.0, (1.0 - novG) * (1.0 - novG), _PearlEdge);
                gloss += _PearlColor.rgb * _PearlStrength * pearlGrain * pearlView * sheenLight;

                // Glints: small bright sparkles.
                gloss += _PearlColor.rgb * _GlintStrength * glint;

                // Fog. MixFog(x) = lerp(fogColor, x, k); subtracting MixFog(0)
                // leaves x * k, so the additive gloss does not add fog twice.
                float3 fogOnly = MixFog((float3)0, IN.fogFactor);
                fabricColor = MixFog(fabricColor, IN.fogFactor);
                gloss       = MixFog(gloss, IN.fogFactor) - fogOnly;

                // Both terms scale with coverage: no fabric, no fibres to shine.
                float3 premultiplied = (fabricColor + gloss) * alpha;

                return float4(premultiplied, alpha);
            }
            ENDHLSL
        }

        // No ShadowCaster pass: the leg under the stocking casts the shadow.
        // No DepthOnly pass: depth is written by the forward pass above.
    }

    Fallback Off
}
