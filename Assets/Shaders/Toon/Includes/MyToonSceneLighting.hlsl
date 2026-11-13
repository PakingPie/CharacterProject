#ifndef MY_TOON_SCENE_LIGHTING_INCLUDED
#define MY_TOON_SCENE_LIGHTING_INCLUDED
// Reuses MyToonShader's color layers, thresholds, masks and normal controls.
// Legacy materials never enter this opt-in path. MatCap/rim/AngelRing are not
// evaluated here; this bounded mode uses scene light plus optional sharp glints.
float3 CleanToonAlbedo(float3 source)
{
    float darkMark=1.0-smoothstep(0.012,0.10,Luminance(source));
    return lerp(source,_AlbedoFlatColor.rgb,_AlbedoFlatten*(1.0-darkMark*_AlbedoPreserveDark));
}
float ToonHardBand(float value,float threshold,float feather)
{
    float edge=max(feather,0.65*fwidth(value));
    return smoothstep(threshold-edge,threshold+edge,value);
}
float DesignedFaceLit(float3 p,float3 lightDirection,float normalLit)
{
    float lr=dot(lightDirection,normalize(_HeadRightWS.xyz));
    float lf=dot(lightDirection,normalize(_HeadForwardWS.xyz));
    float horizontal=length(float2(lr,lf));
    float sweep=abs(atan2(lr,lf))/PI;
    float3 d=p-_FaceOriginWS.xyz;
    float2 face=float2(dot(d,normalize(_HeadRightWS.xyz)),dot(d,normalize(_HeadUpWS.xyz)))/max(_FaceExtents.xy,0.001);
    face.x*=lr<0?-1.0:1.0;
    float2 uv=saturate(face*0.5+0.5);
    // R records the largest horizontal light sweep that keeps each point lit.
    float allowed=SAMPLE_TEXTURE2D(_FaceShadowTex,sampler_FaceShadowTex,uv).r;
    float authored=ToonHardBand(allowed,sweep,_FaceShadowFeather);
    // Near vertical light has no stable horizontal side: use the declared normal fallback.
    return lerp(normalLit,authored,smoothstep(0.08,0.25,horizontal));
}
float3 SceneToonFill(float3 source,float3 shade1,float3 n,Light l)
{
    // Secondary lights are soft fill; no derivatives in the variable light loop.
    float3 colors=lerp(shade1,source,saturate(dot(n,l.direction)));
    return colors*l.color*(l.distanceAttenuation*l.shadowAttenuation)*_SceneDirectScale;
}
float4 EvaluateSceneAwareToon(float4 tex,float2 uv,float3 p,float3 geometricN,float3 mappedN,
                              float3 viewDir,float4 shadowCoord,float2 screenUV,float fog)
{
    float3 n=normalize(lerp(geometricN,mappedN,_UseNormalMapOverBase));
    float3 base=CleanToonAlbedo(tex.rgb)*_BaseColor.rgb;
    float3 first=lerp(SAMPLE_TEXTURE2D(_FirstShadowTex,sampler_MainTex,TRANSFORM_TEX(uv,_FirstShadowTex)).rgb,tex.rgb,_UseBaseTexAsFirstShadowTex);
    float3 second=lerp(SAMPLE_TEXTURE2D(_SecondShadowTex,sampler_MainTex,TRANSFORM_TEX(uv,_SecondShadowTex)).rgb,first,_UseFirstShadowTexAsSecondShadowTex);
    first=CleanToonAlbedo(first)*_BaseColor.rgb*_FirstShadowTexColor.rgb;
    second=CleanToonAlbedo(second)*_BaseColor.rgb*_SecondShadowTexColor.rgb;
    Light key=GetMainLight(shadowCoord,p,half4(1,1,1,1));
    #if defined(_RECEIVE_SHADOWS_OFF)
        key.shadowAttenuation=1;
    #endif
    float3 color=base*max(SampleSH(normalize(geometricN)),0)*_SceneAmbientScale;
    float h=dot(n,key.direction)*0.5+0.5;
    float lit=ToonHardBand(h,_BaseColorStep,_BaseShadeFeather);
    if(_UseAuthoredFaceShadow>0.5)lit=DesignedFaceLit(p,key.direction,lit);
    float secondBand=1.0-ToonHardBand(h,_ShadeColorStep,_FirstAndSecondShadesFeather);
    float3 keyPalette=lerp(lerp(first,second,secondBand),base,lit);
    color+=keyPalette*key.color*(key.distanceAttenuation*key.shadowAttenuation)*_SceneDirectScale;
    if(any(_HighlightColor.rgb>0))
    {
        float3 halfVector=SafeNormalize(key.direction+viewDir);
        float highlight=pow(saturate(dot(n,halfVector)),exp2(lerp(11,3,_HighlightPower)));
        float mask=saturate(tex2D(_HighlightMaskTex,TRANSFORM_TEX(uv,_HighlightMaskTex)).g+_TweakHighlightMaskLevel);
        color+=highlight*mask*_HighlightColor.rgb*key.color*key.distanceAttenuation*key.shadowAttenuation*_SceneDirectScale;
    }
    InputData inputData=(InputData)0;inputData.positionWS=p;inputData.normalizedScreenSpaceUV=screenUV;
    #if defined(_ADDITIONAL_LIGHTS)
        #if USE_CLUSTER_LIGHT_LOOP
        for(uint lightIndex=0;lightIndex<min(URP_FP_DIRECTIONAL_LIGHTS_COUNT,MAX_VISIBLE_LIGHTS);lightIndex++)
        {
            CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
            Light l=GetAdditionalLight(lightIndex,p,half4(1,1,1,1));
            color+=SceneToonFill(base,first,n,l);
        }
        #endif
        uint count=GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(count)
            Light l=GetAdditionalLight(lightIndex,p,half4(1,1,1,1));
            color+=SceneToonFill(base,first,n,l);
        LIGHT_LOOP_END
    #endif
    // Source alpha remains in force, including the original clipping options.
    return float4(MixFog(color,fog),tex.a*_BaseColor.a);
}
#endif
