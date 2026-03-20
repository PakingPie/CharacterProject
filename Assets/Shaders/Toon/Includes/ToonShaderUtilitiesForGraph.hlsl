#ifndef TOON_SHADER_UTILITIES_FOR_GRAPH_INCLUDED_HLSL
#define TOON_SHADER_UTILITIES_FOR_GRAPH_INCLUDED_HLSL

// void GetToonMainLight_float(
//     float3 PositionWS,
//     float4 ScreenPosition,
//     float4 UV,
//     out float3 Direction,
//     out float3 Color,
//     out float ShadowAttenuation)
// {
//     Direction = float3(0, 0, 0);
//     Color = float3(0, 0, 0);
//     ShadowAttenuation = 1.0;

// #ifndef SHADERGRAPH_PREVIEW
// #if USE_CLUSTER_LIGHT_LOOP
//     SurfaceData surfaceData;
//     InitializeStandardLitSurfaceDataToon(UV, surfaceData);
//     // for Foward+ LIGHT_LOOP_BEGIN macro uses inputData.normalizedScreenSpaceUV and inputData.positionWS
//     InputData inputData = (InputData)0;
//     inputData.normalizedScreenSpaceUV = ScreenPosition;
//     inputData.positionWS = PositionWS;

//     float4 positionCS = TransformWorldToHClip(PositionWS);

// #if SHADOWS_SCREEN
//     inputData.shadowCoord = ComputeScreenPos(positionCS);
// #else
//     inputData.shadowCoord = TransformWorldToShadowCoord(PositionWS);
// #endif
// #endif
// #endif
// }

#define SATURATE_IF_SDR(x) (x)
void CalculateRimlight_float(
    float3 LightColor, float3 LightDirection, float3 LocalNormal, float3 NormalDirection, float2 UV, float3 ViewDirection,
    float3 RimlightColor, bool BlendLightColorToRimlightColor, bool SetNormalMapToRimLight, float RimlightPower, float RimlightInsideMask, bool RimlightFeatherOff, bool LightDirectionMaskOn, float TweakLightDirectionMaskLevel, bool AddAPRimlight, float3 APRimlightColor, bool SetLightColorToAPRimlightColor, float APRimlightPower, bool APRimlightFeatherOff, UnityTexture2D RimlightMaskTex, float TweakRimlightMaskLevel,
    out float3 outColor)
{
    float4 rimLightMask = tex2D(RimlightMaskTex, UV);

    float3 rimLightColor = lerp(RimlightColor.rgb, (RimlightColor.rgb * LightColor), BlendLightColorToRimlightColor);
    float rimArea = abs(1.0 - dot(lerp(LocalNormal, NormalDirection, SetNormalMapToRimLight), ViewDirection));
    float rimLightPower = pow(rimArea, exp2(lerp(3, 0, RimlightPower)));
    float rimLightInsideMask = saturate(lerp((0.0 + ((rimLightPower - RimlightInsideMask) * (1.0 - 0.0)) / (1.0 - RimlightInsideMask)), step(RimlightInsideMask, rimLightPower), RimlightFeatherOff));
    float halfLambertObj = 0.5 * dot(LocalNormal, LightDirection) + 0.5;
    float3 lightDirectionMaskOn = lerp((rimLightColor * rimLightInsideMask), (rimLightColor * saturate((rimLightInsideMask - ((1.0 - halfLambertObj) + TweakLightDirectionMaskLevel)))), LightDirectionMaskOn);
    // AP means Antipodean, opposite side of a globe
    float apRimLightPower = pow(rimArea, exp2(lerp(3, 0, APRimlightPower)));
    // outColor = rimLightColor;
    outColor = (SATURATE_IF_SDR((rimLightMask.g + TweakRimlightMaskLevel)) * lerp(lightDirectionMaskOn, (lightDirectionMaskOn + (lerp(APRimlightColor.rgb, (APRimlightColor.rgb * LightColor), SetLightColorToAPRimlightColor) * saturate((lerp((0.0 + ((apRimLightPower - RimlightInsideMask) * (1.0 - 0.0)) / (1.0 - RimlightInsideMask)), step(RimlightInsideMask, apRimLightPower), APRimlightFeatherOff) - (saturate(halfLambertObj) + TweakLightDirectionMaskLevel))))), AddAPRimlight));
}

void RotateUV_float(float2 uv, float radian, float2 piv, float time, out float2 rotatedUV)
{
    float cosVal = cos(time * radian);
    float sinVal = sin(time * radian);
    rotatedUV = (mul(uv - piv, float2x2(cosVal, -sinVal, sinVal, cosVal)) + piv);
}

// Normal should be normalized, w=1.0
float3 SHEvalLinearL0L1(half4 normal)
{
    float3 x;

    // Linear (L1) + constant (L0) polynomial terms
    x.r = dot(unity_SHAr, normal);
    x.g = dot(unity_SHAg, normal);
    x.b = dot(unity_SHAb, normal);

    return x;
}

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

inline float3 LinearToGammaSpace(float3 linRGB)
{
    linRGB = max(linRGB, float3(0.f, 0.f, 0.f));
    // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return max(1.055f * pow(linRGB, 0.416666667f) - 0.055f, 0.f);
}

// Normal should be normalized, w=1.0
// output in active color space
void ShadeSH9_float(half4 normal, out float3 result)
{
    // Linear + constant polynomial terms
    result = SHEvalLinearL0L1(normal);

    // Quadratic polynomials
    result += SHEvalLinearL2(normal);

#ifdef UNITY_COLORSPACE_GAMMA
    result = LinearToGammaSpace(result);
#endif
}

void ToonAdditionalLights_float(
    float3 PositionWS, 
    float3 ViewDirection,
    float2 UV, 
    float2 ScreenPosition,
    float4 MainTexColor, 
    float3 LocalNormal, 
    float3 NormalDirection, 
    float4 BaseColor, 
    bool BlendLightColorAndBaseColor, 
    bool UseNormalMapOverBase, 
    bool SetSystemShadowsToBase,
    float TweakSystemShadowsLevel,
    float BaseColorStep, 
    float BaseShadeFeather,
    float ShadeColorStep, 
    float FirstAndSecondShadesFeather,
    float StepOffset, 
    bool IsFilterHiCutPointLightColor,
    UnityTexture2D FirstShadowPositionTex,
    UnityTexture2D SecondShadowPositionTex,
    UnityTexture2D FirstShadowTex, 
    bool UseBaseTexAsFirstShadowTex, 
    float4 FirstShadowTexColor, 
    bool BlendFirstShadowAndLightColor, 
    UnityTexture2D SecondShadowTex, 
    bool UseFirstShadowTexAsSecondShadowTex,
    float4 SecondShadowTexColor, 
    bool BlendSecondShadowAndLightColor, 
    float4 HighlightColor,
    UnityTexture2D HighlightTex,
    bool SetLightColorToHighlightColor,
    bool SetNormalMapToHighlight,
    float HighlightPower,
    bool SetSpecularColorToHighlightColor,
    bool IsUseTweakHighlightColorOnShadow,
    float TweakHighlightOnShadow,
    UnityTexture2D HighlightMaskTex,
    float TweakHighlightMaskLevel,
    bool IsFilterLightColor, 
    out float3 Color)
{
    Color = 0;
#ifndef SHADERGRAPH_PREVIEW
    uint pixelLightCount = GetAdditionalLightsCount();
#if USE_CLUSTER_LIGHT_LOOP
    InputData inputData = (InputData)0;
    inputData.normalizedScreenSpaceUV = ScreenPosition;
    inputData.positionWS = PositionWS;
#endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
#if !USE_CLUSTER_LIGHT_LOOP
    lightIndex = GetPerObjectLightIndex(lightIndex);
#endif
    float notDirectionalLight = 1.0;
    // Call the URP additional light algorithm. This will not calculate shadows, since swe don't pass a shadow mask value
    Light light = GetAdditionalPerObjectLight(lightIndex, PositionWS);
    // Manually set the shadow attenuation by calculating realtime shadows
    light.shadowAttenuation = AdditionalLightRealtimeShadow(lightIndex, PositionWS);

    float atten = light.shadowAttenuation * light.distanceAttenuation;
    
    float halfLambert = 0.5 * dot(lerp(LocalNormal, NormalDirection, UseNormalMapOverBase), light.direction) + 0.5;
    
    float3 addPassLightColor = halfLambert * light.color;
    float pureIntensity = max(0.001, 0.299 * light.color.r + 0.587 * light.color.g + 0.114 * light.color.b);
    float3 lightColor = max(0, lerp(addPassLightColor, lerp(0, min(addPassLightColor, addPassLightColor / pureIntensity), notDirectionalLight), IsFilterLightColor));

    float3 halfDirection = normalize(ViewDirection + light.direction);

    BaseColorStep = saturate(BaseColorStep + StepOffset);
    ShadeColorStep = saturate(ShadeColorStep + StepOffset);

    float lightIntensity = lerp(0, (0.299 * light.color.r + 0.587 * light.color.g + 0.114 * light.color.b), notDirectionalLight);

    lightColor = lerp(lightColor, lerp(lightColor, min(lightColor, light.color.rgb * BaseColorStep), notDirectionalLight), IsFilterHiCutPointLightColor);

    float3 baseColor = lerp((BaseColor.rgb * MainTexColor.rgb * lightIntensity), ((BaseColor.rgb * MainTexColor.rgb) * lightColor), BlendLightColorAndBaseColor);

    float4 firstShadowTexVal = lerp(tex2D(FirstShadowTex, UV), MainTexColor, UseBaseTexAsFirstShadowTex);

    float3 firstShadowColor = lerp((FirstShadowTexColor.rgb * firstShadowTexVal.rgb * lightIntensity), ((FirstShadowTexColor.rgb * firstShadowTexVal.rgb) * lightColor), BlendFirstShadowAndLightColor);
    
    float4 secondShadowTexVal = lerp(tex2D(SecondShadowTex,UV), firstShadowTexVal, UseFirstShadowTexAsSecondShadowTex);

    float3 secondShadowColor = lerp((SecondShadowTexColor.rgb * secondShadowTexVal.rgb * lightIntensity), ((SecondShadowTexColor.rgb * secondShadowTexVal.rgb) * lightColor), BlendSecondShadowAndLightColor);

    float4 firstShadowPosition = tex2D(FirstShadowPositionTex, UV);
    float4 secondShadowPosition = tex2D(SecondShadowPositionTex, UV);

    float finalShadowMask = saturate((1.0 + ((lerp(halfLambert, (halfLambert * saturate(1.0 + TweakSystemShadowsLevel)), SetSystemShadowsToBase) - (BaseColorStep - BaseShadeFeather)) * ((1.0 - firstShadowPosition.rgb).r - 1.0)) / (BaseColorStep - (BaseColorStep - BaseShadeFeather))));

    float3 finalColor =  lerp(baseColor, lerp(firstShadowColor, lerp(secondShadowColor, secondShadowColor, saturate(1.0 + ((halfLambert - (ShadeColorStep - FirstAndSecondShadesFeather)) * ((1.0 - secondShadowPosition.rgb).r - 1.0)) / (ShadeColorStep - (ShadeColorStep - FirstAndSecondShadesFeather)))), finalShadowMask), finalShadowMask);

    float4 highLightMask = tex2D(HighlightMaskTex, UV);

    float specular = 0.5 * dot(halfDirection, lerp(LocalNormal, NormalDirection, SetNormalMapToHighlight)) + 0.5;
    
    float tweakHighlightMask = saturate((highLightMask.g + TweakHighlightMaskLevel) * lerp((1.0 - step(specular, (1.0 - step(abs(HighlightPower), 5)))), pow(abs(specular), exp2(lerp(11, 1, HighlightPower))), SetSpecularColorToHighlightColor));

    float4 highlightColor = tex2D(HighlightTex, UV);

    float3 highlight = (lerp((highlightColor.rgb * HighlightColor.rgb), ((highlightColor.rgb * HighlightColor.rgb) * lightColor), SetLightColorToHighlightColor) * tweakHighlightMask);

    finalColor = finalColor + lerp(lerp(highlight, (highlight * ((1.0 - finalShadowMask) + (finalShadowMask * TweakHighlightOnShadow))), IsUseTweakHighlightColorOnShadow), float3(0, 0, 0), IsFilterHiCutPointLightColor);

    Color += saturate(finalColor) * atten; //lightColor * light.shadowAttenuation * light.distanceAttenuation;
    LIGHT_LOOP_END
#endif
}

#endif