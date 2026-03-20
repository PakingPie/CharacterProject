#ifndef URP_MY_TOON_SHADER_UTILITIES_INCLUDED_HLSL
    #define URP_MY_TOON_SHADER_UTILITIES_INCLUDED_HLSL
    
    #define MAINLIGHT_NOT_FOUND -2
    #define MAINLIGHT_IS_MAINLIGHT -1

    #define SATURATE_IF_SDR(x) (x)
    #define SATURATE_BASE_COLOR_IF_SDR(x) (x)

    #ifndef DIRECTIONAL
        #define DIRECTIONAL
    #endif

    #if defined(UNITY_PASS_PREPASSBASE) || defined(UNITY_PASS_DEFERRED) || defined(UNITY_PASS_SHADOWCASTER)
        #undef FOG_LINEAR
        #undef FOG_EXP
        #undef FOG_EXP2
    #endif

    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #define UNITY_FOG_COORDS(idx) UNITY_FOG_COORDS_PACKED(idx, float1)
        #if (SHADER_TARGET < 30) || defined(SHADER_API_MOBILE)
            // mobile or SM2.0: calculate fog factor per-vertex
            #define UNITY_TRANSFER_FOG(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.fogCoord.x = unityFogFactor
        #else
            // SM3.0 and PC/console: calculate fog distance per-vertex, and fog factor per-pixel
            #define UNITY_TRANSFER_FOG(o,outpos) o.fogCoord.x = (outpos).z
        #endif
    #else
        #define UNITY_FOG_COORDS(idx)
        #define UNITY_TRANSFER_FOG(o,outpos)
    #endif

    #define UNITY_FOG_LERP_COLOR(col,fogCol,fogFac) col.rgb = lerp((fogCol).rgb, (col).rgb, saturate(fogFac))

    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #if (SHADER_TARGET < 30) || defined(SHADER_API_MOBILE)
            // mobile or SM2.0: fog factor was already calculated per-vertex, so just lerp the color
            #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_FOG_LERP_COLOR(col,fogCol,(coord).x)
        #else
            // SM3.0 and PC/console: calculate fog factor and lerp fog color
            #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_CALC_FOG_FACTOR((coord).x); UNITY_FOG_LERP_COLOR(col,fogCol,unityFogFactor)
        #endif
    #else
        #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol)
    #endif

    #ifdef UNITY_PASS_FORWARDADD
        #define UNITY_APPLY_FOG(coord,col) UNITY_APPLY_FOG_COLOR(coord,col,fixed4(0,0,0,0))
    #else
        #define UNITY_APPLY_FOG(coord,col) UNITY_APPLY_FOG_COLOR(coord,col,unity_FogColor)
    #endif

    #ifdef DIRECTIONAL
        // #define LIGHTING_COORDS(idx1,idx2) SHADOW_COORDS(idx1)
        #define TRANSFER_VERTEX_TO_FRAGMENT(a) TRANSFER_SHADOW(a)
        #define LIGHT_ATTENUATION(a)    SHADOW_ATTENUATION(a)
    #endif

    inline half3 LinearToGammaSpace(half3 linRGB)
    {
        linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
        // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
        return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
    }

    struct ToonLight
    {
        float3 direction;
        float3 color;
        float distanceAttenuation;
        float shadowAttenuation;
        int type;
    };

    #define INIT_TOONLIGHT(toonLight)      \
        toonLight.direction = 0;           \
        toonLight.color = 0;               \
        toonLight.distanceAttenuation = 0; \
        toonLight.shadowAttenuation = 0;   \
        toonLight.type = 0

    inline float4 UnityObjectToClipPosInstanced(in float3 pos)
    {
        return mul(UNITY_MATRIX_VP, mul(unity_ObjectToWorld, float4(pos, 1.0)));
    }
    inline float4 UnityObjectToClipPosInstanced(float4 pos)
    {
        return UnityObjectToClipPosInstanced(pos.xyz);
    }
    #define UnityObjectToClipPos UnityObjectToClipPosInstanced

    inline float3 UnityObjectToWorldNormal(in float3 norm)
    {
        #ifdef UNITY_ASSUME_UNIFORM_SCALING
            return UnityObjectToWorldDir(norm);
        #else
            // mul(IT_M, norm) => mul(norm, I_M) => {dot(norm, I_M.col0), dot(norm, I_M.col1), dot(norm, I_M.col2)}
            return normalize(mul(norm, (float3x3)unity_WorldToObject));
        #endif
    }

    // Normal should be normalized, w=1.0
    half3 SHEvalLinearL0L1(half4 normal)
    {
        half3 x;

        // Linear (L1) + constant (L0) polynomial terms
        x.r = dot(unity_SHAr, normal);
        x.g = dot(unity_SHAg, normal);
        x.b = dot(unity_SHAb, normal);

        return x;
    }

    // Normal should be normalized, w=1.0
    half3 SHEvalLinearL2(half4 normal)
    {
        half3 x1, x2;
        // 4 of the quadratic (L2) polynomials
        half4 vB = normal.xyzz * normal.yzzx;
        x1.r = dot(unity_SHBr, vB);
        x1.g = dot(unity_SHBg, vB);
        x1.b = dot(unity_SHBb, vB);

        // Final (5th) quadratic (L2) polynomial
        half vC = normal.x * normal.x - normal.y * normal.y;
        x2 = unity_SHC.rgb * vC;

        return x1 + x2;
    }

    // Normal should be normalized, w=1.0
    // output in active color space
    half3 ShadeSH9(half4 normal)
    {
        // Linear + constant polynomial terms
        half3 res = SHEvalLinearL0L1(normal);

        // Quadratic polynomials
        res += SHEvalLinearL2(normal);

        #ifdef UNITY_COLORSPACE_GAMMA
            res = LinearToGammaSpace(res);
        #endif

        return res;
    }

    #if (SHADER_LIBRARY_VERSION_MAJOR == 7 && SHADER_LIBRARY_VERSION_MINOR >= 3) || (SHADER_LIBRARY_VERSION_MAJOR >= 8)
        #ifdef _ADDITIONAL_LIGHTS
            #ifndef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                #define REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
            #endif
        #endif
    #else
        #ifdef _MAIN_LIGHT_SHADOWS
            // #  if !defined(_MAIN_LIGHT_SHADOWS_CASCADE)
            #ifndef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                #define REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
            #endif
        #endif
        #ifdef _ADDITIONAL_LIGHTS
            #ifndef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                #define REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
            #endif
        #endif
    #endif

    float2 RotateUV(float2 uv, float radian, float2 piv, float time)
    {
        float cosVal = cos(time * radian);
        float sinVal = sin(time * radian);
        return (mul(uv - piv, float2x2(cosVal, -sinVal, sinVal, cosVal)) + piv);
    }

    half3 DecodeLightProbe(half3 N)
    {
        return ShadeSH9(float4(N, 1));
    }

    inline void InitializeStandardLitSurfaceDataToon(float2 uv, out SurfaceData outSurfaceData)
    {
        outSurfaceData = (SurfaceData)0;
        // This value can be sampled from a texture
        half4 albedoAlpha = half4(1.0, 1.0, 1.0, 1.0);

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

    half3 GetGlobalIllumination(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
    {
        half3 reflectVector = reflect(-viewDirectionWS, normalWS);
        half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

        half3 indirectDiffuse = bakedGI * occlusion;
        half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion);

        return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
    }

    half GetMainLightRealTimeShadow(float4 shadowCoord, float4 positionCS)
    {
        #if !defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            return 1.0;
        #endif

        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        half4 shadowParams = GetMainLightShadowParams();
        #if defined(USE_TOON_RAYTRACING_SHADOW)
            float w = (positionCS.w == 0) ? 0.00001 : positionCS.w;
            float4 screenPos = ComputeScreenPos(positionCS / w);
            return SAMPLE_TEXTURE2D(_RaytracedHardShadow, sampler_RaytracedHardShadow, screenPos);
        #elif defined(_MAIN_LIGHT_SHADOWS_SCREEN)
            return SampleScreenSpaceShadowmap(shadowCoord);
        #endif
        return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
    }

    half GetAdditionalLightRealTimeShadow(int lightIndex, float3 positionWS, float4 positionCS)
    {
        #if defined(USE_TOON_RAYTRACING_SHADOW)
            float w = (positionCS.w == 0) ? 0.00001 : positionCS.w;
            float4 screenPos = ComputeScreenPos(positionCS / w);
            return SAMPLE_TEXTURE2D(_RaytracedHardShadow, sampler_RaytracedHardShadow, screenPos);
        #endif // USE_TOON_RAYTRACING_SHADOW

        #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
            return 1.0h;
        #endif

        #if (SHADER_LIBRARY_VERSION_MAJOR >= 13 && UNITY_VERSION >= 202220)
            ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData(lightIndex);
        #else
            ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData();
        #endif

        #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
            lightIndex = _AdditionalShadowsIndices[lightIndex];
            // We have to branch here as otherwise we would sample buffer with lightIndex == -1.
            // However this should be ok for platforms that store light in SSBO.
            UNITY_BRANCH
            if (lightIndex < 0) return 1.0;

            float4 shadowCoord = mul(_AdditionalShadowsBuffer[lightIndex].worldToShadowMatrix, float4(positionWS, 1.0));
        #else
            #if defined(_ADDITIONAL_LIGHT_SHADOWS)
                float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[lightIndex], float4(positionWS, 1.0));
            #else
                float4 shadowCoord = 0;
            #endif
        #endif

        half4 shadowParams = GetAdditionalLightShadowParams(lightIndex);
        return SampleShadowmap(TEXTURE2D_ARGS(_AdditionalLightsShadowmapTexture, sampler_AdditionalLightsShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, true);
    }

    ToonLight GetToonMainLight()
    {
        ToonLight light;
        light.direction = _MainLightPosition.xyz;
        // unity_LightData.z is 1 when not culled by the culling mask, otherwise 0.
        // set to 1 in here, so that the light is always considered.
        light.distanceAttenuation = 1; // unity_LightData.z;
        #if defined(LIGHTMAP_ON) || defined(_MIXED_LIGHTING_SUBTRACTIVE)
            // unity_ProbesOcclusion.x is the mixed light probe occlusion data
            light.distanceAttenuation *= unity_ProbesOcclusion.x;
        #endif
        light.shadowAttenuation = 1.0;
        light.color = _MainLightColor.rgb;
        light.type = _MainLightPosition.w;
        return light;
    }

    ToonLight GetToonMainLight(float4 shadowCoord, float4 positionCS)
    {
        ToonLight light = GetToonMainLight();
        light.shadowAttenuation = GetMainLightRealTimeShadow(shadowCoord, positionCS);
        return light;
    }

    ToonLight GetAdditionalPerObjectToonLight(int perObjectLightIndex, float3 positionWS, float4 positionCS)
    {
        // Abstraction over Light input constants
        #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
            float4 lightPositionWS = _AdditionalLightsBuffer[perObjectLightIndex].position;
            half3 color = _AdditionalLightsBuffer[perObjectLightIndex].color.rgb;
            half4 distanceAndSpotAttenuation = _AdditionalLightsBuffer[perObjectLightIndex].attenuation;
            half4 spotDirection = _AdditionalLightsBuffer[perObjectLightIndex].spotDirection;
            half4 lightOcclusionProbeInfo = _AdditionalLightsBuffer[perObjectLightIndex].occlusionProbeChannels;
        #else
            float4 lightPositionWS = _AdditionalLightsPosition[perObjectLightIndex];
            half3 color = _AdditionalLightsColor[perObjectLightIndex].rgb;
            half4 distanceAndSpotAttenuation = _AdditionalLightsAttenuation[perObjectLightIndex];
            half4 spotDirection = _AdditionalLightsSpotDir[perObjectLightIndex];
            half4 lightOcclusionProbeInfo = _AdditionalLightsOcclusionProbes[perObjectLightIndex];
        #endif

        // Directional lights store direction in lightPosition.xyz and have .w set to 0.0.
        // This way the following code will work for both directional and punctual lights.
        float3 lightVector = lightPositionWS.xyz - positionWS * lightPositionWS.w;
        float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);

        half3 lightDirection = half3(lightVector * rsqrt(distanceSqr));
        half attenuation = DistanceAttenuation(distanceSqr, distanceAndSpotAttenuation.xy) * AngleAttenuation(spotDirection.xyz, lightDirection, distanceAndSpotAttenuation.zw);

        ToonLight light;
        light.direction = lightDirection;
        light.distanceAttenuation = attenuation;
        light.shadowAttenuation = GetAdditionalLightRealTimeShadow(perObjectLightIndex, positionWS, positionCS);
        light.color = color;
        light.type = lightPositionWS.w;

        // In case we're using light probes, we can sample the attenuation from the `unity_ProbesOcclusion`
        #if defined(LIGHTMAP_ON) || defined(_MIXED_LIGHTING_SUBTRACTIVE)
            // First find the probe channel from the light.
            // Then sample `unity_ProbesOcclusion` for the baked occlusion.
            // If the light is not baked, the channel is -1, and we need to apply no occlusion.

            // probeChannel is the index in 'unity_ProbesOcclusion' that holds the proper occlusion value.
            int probeChannel = lightOcclusionProbeInfo.x;

            // lightProbeContribution is set to 0 if we are indeed using a probe, otherwise set to 1.
            half lightProbeContribution = lightOcclusionProbeInfo.y;

            half probeOcclusionValue = unity_ProbesOcclusion[probeChannel];
            light.distanceAttenuation *= max(probeOcclusionValue, lightProbeContribution);
        #endif

        return light;
    }

    ToonLight GetAdditionalToonLight(uint i, float3 positionWS, float4 positionCS)
    {
        int perObjectLightIndex = GetPerObjectLightIndex(i);
        return GetAdditionalPerObjectToonLight(perObjectLightIndex, positionWS, positionCS);
    }

    half3 GetLightColor(ToonLight light)
    {
        return light.color * light.distanceAttenuation;
    }

    int GetToonMainLightIndex(float3 posW, float4 shadowCoord, float4 positionCS)
    {
        ToonLight mainLight;
        INIT_TOONLIGHT(mainLight);

        int mainLightIndex = MAINLIGHT_NOT_FOUND;

        ToonLight nextLight = GetToonMainLight(shadowCoord, positionCS);
        if (nextLight.distanceAttenuation > mainLight.distanceAttenuation && nextLight.type == 0)
        {
            mainLight = nextLight;
            mainLightIndex = MAINLIGHT_IS_MAINLIGHT;
        }
        int lightCount = GetAdditionalLightsCount();
        for (int ii = 0; ii < lightCount; ++ii)
        {
            nextLight = GetAdditionalToonLight(ii, posW, positionCS);
            if (nextLight.distanceAttenuation > mainLight.distanceAttenuation && nextLight.type == 0)
            {
                mainLight = nextLight;
                mainLightIndex = ii;
            }
        }

        return mainLightIndex;
    }

    ToonLight GetToonMainLightByID(int index, float3 posW, float4 shadowCoord, float4 positionCS)
    {
        ToonLight mainLight;
        INIT_TOONLIGHT(mainLight);
        if (index == MAINLIGHT_NOT_FOUND)
        {
            return mainLight;
        }
        if (index == MAINLIGHT_IS_MAINLIGHT)
        {
            return GetToonMainLight(shadowCoord, positionCS);
        }
        return GetAdditionalToonLight(index, posW, positionCS);
    }
#endif