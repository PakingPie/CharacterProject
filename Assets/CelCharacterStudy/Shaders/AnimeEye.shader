Shader "SchoolLife/CelStudy/AnimeEye"
{
 Properties
 {
  _BaseMap("Source alpha / optional iris detail",2D)="white"{}
  [Enum(Sclera,0,Iris,1)] _EyeRegion("Eye Region",Float)=1
  _ScleraColor("Sclera",Color)=(0.8,0.8,0.76,1)
  _IrisTop("Iris upper color",Color)=(0.02,0.09,0.075,1)
  _IrisBottom("Iris lower color",Color)=(0.3,0.6,0.2,1)
  _PupilColor("Pupil and limbal ring",Color)=(0.008,0.016,0.02,1)
  _CatchlightColor("Illustrated catchlights",Color)=(0.8,0.9,1,1)
  _IrisCenter("Iris center UV",Vector)=(0.5,0.525,0,0)
  _IrisRadius("Iris UV radii",Vector)=(0.18,0.30,0,0)
  _PupilSize("Pupil radius",Range(0.05,0.5))=0.24
  _LimbalWidth("Outer ring width",Range(0.01,0.3))=0.09
  _IrisDetail("Retained source detail",Range(0,1))=0.12
  _UpperShadow("Upper eye shadow",Range(0,1))=0.3
  _CatchlightStrength("Catchlight strength",Range(0,1))=0.75
  _GazeOffset("Gaze UV offset",Vector)=(0,0,0,0)
  _EyeForwardWS("Eye forward",Vector)=(0,0,1,0)
  _DirectScale("Direct light scale",Range(0,2))=1
  _AmbientScale("Ambient scale",Range(0,2))=1
  _Cutoff("Source alpha cutoff",Range(0,1))=0.2
  _BaseColor("Shadow pass color",Color)=(1,1,1,1)
  [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull",Float)=2
 }
 SubShader
 {
  Tags {"RenderPipeline"="UniversalPipeline" "RenderType"="TransparentCutout" "Queue"="AlphaTest"}
  Pass
  {
   Name "EyeForward" Tags{"LightMode"="UniversalForward"} Cull [_Cull] ZWrite On
   HLSLPROGRAM
   #pragma vertex Vert
   #pragma fragment Frag
   #pragma target 3.5
   #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
   #pragma multi_compile _ _ADDITIONAL_LIGHTS
   #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
   #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
   #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   #include "EyeUVUtilities.hlsl"
   TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
   CBUFFER_START(UnityPerMaterial)
   float4 _BaseMap_ST,_BaseColor,_ScleraColor,_IrisTop,_IrisBottom,_PupilColor,_CatchlightColor;
   float4 _IrisCenter,_IrisRadius,_GazeOffset,_EyeForwardWS;
   float _EyeRegion,_PupilSize,_LimbalWidth,_IrisDetail,_UpperShadow,_CatchlightStrength,_DirectScale,_AmbientScale,_Cutoff;
   CBUFFER_END
   struct A{float4 p:POSITION;float3 n:NORMAL;float2 uv:TEXCOORD0;};
   struct V{float4 p:SV_POSITION;float3 ws:TEXCOORD0;float3 n:TEXCOORD1;float2 uv:TEXCOORD2;float4 sc:TEXCOORD3;};
   V Vert(A a){V o;VertexPositionInputs p=GetVertexPositionInputs(a.p.xyz);o.p=p.positionCS;o.ws=p.positionWS;o.n=TransformObjectToWorldNormal(a.n);o.uv=TRANSFORM_TEX(a.uv,_BaseMap);o.sc=GetShadowCoord(p);return o;}
   float Disk(float2 p,float2 center,float radius){float d=length(p-center);return 1-smoothstep(radius-fwidth(d),radius+fwidth(d),d);}
   float3 EyeLight(float3 forward,Light l){float band=dot(forward,l.direction)>0.15?1.0:0.65;return l.color*(band*l.distanceAttenuation*l.shadowAttenuation)*_DirectScale;}
   half4 Frag(V i):SV_Target
   {
    float4 source=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);
    float3 base=_ScleraColor.rgb;
    float2 p=(i.uv-_IrisCenter.xy-_GazeOffset.xy)/_IrisRadius.xy;
    if(_EyeRegion>0.5)
    {
     float r=length(p);clip(1-r);
     float bottom=saturate(0.5-p.y*0.5);
     base=lerp(_IrisTop.rgb,_IrisBottom.rgb,smoothstep(0.15,0.95,bottom));
     float2 detailUV=_IrisCenter.xy+RemapAnimePupilUV(p*0.5,_PupilSize*0.5,0.085)*(_IrisRadius.xy*2);
     float3 irisTexture=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,detailUV).rgb;
     float detail=clamp(Luminance(irisTexture)*2.2,0.75,1.2);
     base*=lerp(1,detail,_IrisDetail);
     float ring=smoothstep(1-_LimbalWidth-fwidth(r),1-_LimbalWidth+fwidth(r),r);
     base=lerp(base,_PupilColor.rgb,ring);
     float pupil=Disk(p*float2(1.0,0.88),float2(0,0),_PupilSize);
     base=lerp(base,_PupilColor.rgb,pupil);
     float upper=smoothstep(0.18,0.21,(i.uv.y-_IrisCenter.y)/_IrisRadius.y);
     base*=1-_UpperShadow*upper;
     // Authored illustration marks follow the iris and are still lit by the scene.
     float marks=max(Disk(p,float2(-0.30,0.38),0.105),Disk(p,float2(0.34,-0.14),0.048));
     base=lerp(base,_CatchlightColor.rgb,marks*_CatchlightStrength);
    }
    else
    {
     clip(source.a-_Cutoff);
     float y=saturate((i.uv.y-.80)/.17);
     base*=lerp(1,1-_UpperShadow,smoothstep(.68,.72,y));
    }
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
     float4 sc=i.sc;
    #else
     float4 sc=TransformWorldToShadowCoord(i.ws);
    #endif
    float3 forward=normalize(_EyeForwardWS.xyz);
    Light key=GetMainLight(sc,i.ws,half4(1,1,1,1));
    float3 light=max(SampleSH(normalize(i.n)),0)*_AmbientScale+EyeLight(forward,key);
    InputData inputData=(InputData)0;inputData.positionWS=i.ws;inputData.normalizedScreenSpaceUV=GetNormalizedScreenSpaceUV(i.p);
    #if defined(_ADDITIONAL_LIGHTS)
     #if USE_CLUSTER_LIGHT_LOOP
      for(uint lightIndex=0;lightIndex<min(URP_FP_DIRECTIONAL_LIGHTS_COUNT,MAX_VISIBLE_LIGHTS);lightIndex++)
      {CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK Light l=GetAdditionalLight(lightIndex,i.ws,half4(1,1,1,1));light+=EyeLight(forward,l);}
     #endif
     uint count=GetAdditionalLightsCount();LIGHT_LOOP_BEGIN(count)
      Light l=GetAdditionalLight(lightIndex,i.ws,half4(1,1,1,1));light+=EyeLight(forward,l);
     LIGHT_LOOP_END
    #endif
    return half4(base*light,1);
   }
   ENDHLSL
  }
 }
}
