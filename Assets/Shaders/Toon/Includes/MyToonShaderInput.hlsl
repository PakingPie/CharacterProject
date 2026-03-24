#ifndef URP_MY_TOON_SHADER_INPUT_INCLUDED_HLSL
    #define URP_MY_TOON_SHADER_INPUT_INCLUDED_HLSL

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

    CBUFFER_START(UnityPerMaterial)
        // Main color attributes
        float4 _Color;
        half _BlendLightColorAndBaseColor;
        float4 _FirstShadowTexColor;
        float4 _SecondShadowTexColor;
        half _BlendFirstShadowAndLightColor;
        half _BlendSecondShadowAndLightColor;
        // Main texture attributes
        float4 _MainTex_ST;
        float4 _FirstShadowTex_ST;
        float4 _SecondShadowTex_ST;
        float4 _NormalMap_ST;
        float4 _GrediantMap_ST;

        float4 _FirstShadowPositionTex_ST;
        float4 _SecondShadowPositionTex_ST;
        float _ShadeColorStep;
        float _FirstAndSecondShadesFeather;
        float _BaseColorStep;
        float _BaseShadeFeather;
        half _SetSystemShadowsToBase;

        // Shadow attributes
        half _UseBaseTexAsFirstShadowTex;
        half _UseFirstShadowTexAsSecondShadowTex;
        float _FirstShadowColorStep;
        float _FirstShadowColorFeather;
        float _SecondShadowColorStep;
        float _SecondShadowColorFeather;
        float _TweakSystemShadowsLevel;
        half _BlendSystemShadowsToBase;
        float _TweakShadingGradeMapLevel;
        half _BlurLevelSGM;
        half _UseNormalMapOverBase;

        // Specular
        float4 _HighlightColor;
        float4 _HighlightTex_ST;
        float4 _HighlightMaskTex_ST;
        float _HighlightPower;
        half _SetLightColorToHighlightColor;
        half _SetSpecularColorToHighlightColor;

        half _SetNormalMapToHighlight;
        float _TweakHighlightMaskLevel;
        half _IsBlendAddToHighlighColor;
        half _IsUseTweakHighlightColorOnShadow;
        half _TweakHighlightOnShadow;
        half _SetNormalMapToRimLight;

        // Rim Light attributes
        half _RimLight;
        float4 _RimLightMaskTex_ST;
        float4 _RimLightColor;
        half _BlendLightColorToRimLightColor;
        float _RimLightPower;
        float _RimLightInsideMask;
        half _RimLightFeatherOff;
        half _LightDirectionMaskOn;
        half _TweakLightDirectionMaskLevel;
        half _TweakRimLightMaskLevel;
        
        // Antipode Rim Light attributes
        float4 _ApRimLightColor;
        half _SetLightColorToApRimLightColor;
        float _ApRimLightPower;
        half _AddAntipodeanRimLight;
        half _ApRimLightFeatherOff;

        // Clipping Attributes
        float4 _ClippingMask_ST;
        half _UseBaseMapAlphaAsClippingMask;
        float _ClippingLevel;
        half _InverseClipping;
        float _TweakTransparency;

        // MatCap attributes
        half _MatCap;
        float4 _MatCapTex_ST;
        half _BlurLevelMatCap;
        float4 _MatCapColor;
        half _IsLightColorMatCap;
        half _IsBlendAddToMatCap;
        float _TweakMatCapUV;
        float _RotateMatCapUV;
        float _CameraRollingStabilizer;
        half _UseNormalMapForMatCap;
        float4 _NormalMapForMatCapTex_ST;
        float _BumpScaleMatCap;
        float _RotateNormalMapForMatCapUV;
        half _IsUseTweakMatCapOnShadow;
        float _TweakMatCapOnShadow;
        float4 _MatCapMaskTex_ST;
        float _TweakMatCapMaskLevel;
        half _InverseMatCapMask;
        half _IsOrtho;

        // Angel Ring attributes
        half  _AngelRing;
        float4 _AngelRingTex_ST;
        float4 _AngelRingColor;
        half _UseLightColorAsAngelRingColor;
        float _AngelRingOffsetU;
        float _AngelRingOffsetV;
        half _AngelRingSamplerAlphaOn;

        // Emissive attributes
        float3 emissive;
        float4 _EmissiveTex_ST;
        float4 _EmissiveColor;
        float _BaseSpeed;
        float _ScrollEmissiveU;
        float _ScrollEmissiveV;
        float _RotateEmissiveUV;
        half _IsPingPongBase;
        half _IsColorShift;
        float4 _ColorShift;
        float _ColorShiftSpeed;
        half _IsViewShift;
        float4 _ViewShift;
        uniform half _IsViewCoordScroll;


        // Outline attributes
        float4 _OutlineTex_ST;
        half _UseOutlineTex;
        float _IsBlendLightColorToOutline;
        float _OutlineThickness;
        float4 _OutlineColor;
        float _IsBlendBaseColorToOutline;
        float _FarthestDistance;
        float _NearestDistance;
        float _OffsetZ;
        float _Cutoff;
        float4 _OutlineSampler_ST;

        float4 _BakedNormalTex_ST;
        half _UseBakedNormal;

        // GI attributes
        half _UnlitIntensity = 1.0;
        float _GIIntensity;

        half _IsFilterHiCutPointLightColor;
        half _IsFilterLightColor;

        // Pipeline attributes
        float _ZOverDrawMode;

        // Biased Light Direction Attributes
        half _StepOffset;
        half _IsBLD;
        float _OffsetXAxisBLD;
        float _OffsetYAxisBLD;
        half _InverseZAxisBLD;

        // Base Attributes
        float4 _BaseMap_ST;
        half4 _BaseColor;
        half4 _EmissionColor;
        half _Surface;
        half _BumpScale;

        half _Metallic;
        half _Smoothness;
        half4 _SpecColor;
    CBUFFER_END

    TEXTURE2D(_MainTex);
    SAMPLER(sampler_MainTex);
    TEXTURE2D(_FirstShadowTex);
    TEXTURE2D(_SecondShadowTex);
    TEXTURE2D(_NormalMap);

    sampler2D _FirstShadowPositionTex;
    sampler2D _SecondShadowPositionTex;
    sampler2D _HighlightMaskTex;
    sampler2D _HighlightTex;
    sampler2D _RimLightMaskTex;
    sampler2D _GrediantMap;
    sampler2D _MatCapTex;
    sampler2D _NormalMapForMatCapTex;
    sampler2D _MatCapMaskTex;
    sampler2D _EmissiveTex;
    TEXTURE2D(_ClippingMask);
    sampler2D _AngelRingTex;
    sampler2D _OutlineSampler;
    sampler2D _OutlineTex;
    sampler2D _BakedNormalTex;

    TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
    TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
    TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);

    #ifdef _SPECULAR_SETUP
        #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
    #else
        #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
    #endif

    half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
    {
        half4 specGloss;

        #ifdef _METALLICSPECGLOSSMAP
            specGloss = SAMPLE_METALLICSPECULAR(uv);
            #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                specGloss.a = albedoAlpha * _Smoothness;
            #else
                specGloss.a *= _Smoothness;
            #endif
        #else // _METALLICSPECGLOSSMAP
            #if _SPECULAR_SETUP
                specGloss.rgb = _SpecColor.rgb;
            #else
                specGloss.rgb = _Metallic.rrr;
            #endif

            #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                specGloss.a = albedoAlpha * _Smoothness;
            #else
                specGloss.a = _Smoothness;
            #endif
        #endif

        return specGloss;
    }

    // Implement LitForwardPass Functions
    half SampleOcclusion(float2 uv)
    {
        #ifdef _OCCLUSIONMAP
            // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
            #if defined(SHADER_API_GLES)
                return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
            #else
                half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
                return LerpWhiteTo(occ, _OcclusionStrength);
            #endif
        #else
            return 1.0;
        #endif
    }

    inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
    {
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
        outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

        #if _SPECULAR_SETUP
            outSurfaceData.metallic = 1.0h;
            outSurfaceData.specular = specGloss.rgb;
        #else
            outSurfaceData.metallic = specGloss.r;
            outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
        #endif

        outSurfaceData.smoothness = specGloss.a;
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        outSurfaceData.occlusion = SampleOcclusion(uv);
        outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    }

#endif