Shader "SchoolLife/Study/SceneLitNPR"
{
 Properties
 {
  _BaseMap("Source color / alpha",2D)="white" {}
  _BaseColor("Tint",Color)=(1,1,1,1)
  _ShadowTint("Form shadow tint",Color)=(0.78,0.73,0.78,1)
  _Threshold("Form threshold",Range(-1,1))=0.15
  _Feather("Transition half width",Range(0.001,0.5))=0.12
  _ShadowValue("Form shadow value",Range(0,1))=0.35
  _HeadForward("Evaluated head forward",Vector)=(0,0,1,0)
  _Flatten("Face normal simplification",Range(0,1))=0
  _Cutoff("Alpha cutoff",Range(0,1))=0
  [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull",Float)=2
  [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source blend",Float)=1
  [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination blend",Float)=0
  _ZWrite("Depth write",Float)=1
 }
 SubShader
 {
  Tags {"RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry"}
  Pass
  {
   Name "StudyForward"
   Tags {"LightMode"="UniversalForward"}
   Cull [_Cull] ZWrite [_ZWrite] Blend [_SrcBlend] [_DstBlend]
   HLSLPROGRAM
   #pragma vertex Vert
   #pragma fragment Frag
   #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
   #pragma multi_compile _ _ADDITIONAL_LIGHTS
   #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
   #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
   #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
   #pragma multi_compile_fog
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
   CBUFFER_START(UnityPerMaterial)
   float4 _BaseMap_ST,_BaseColor,_ShadowTint,_HeadForward;
   float _Threshold,_Feather,_ShadowValue,_Flatten,_Cutoff;
   CBUFFER_END
   struct A {float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0;};
   struct V {float4 positionCS:SV_POSITION; float3 positionWS:TEXCOORD0; float3 normalWS:TEXCOORD1; float2 uv:TEXCOORD2; float4 shadowCoord:TEXCOORD3; float fog:TEXCOORD4;};
   V Vert(A a)
   {
    V o; VertexPositionInputs p=GetVertexPositionInputs(a.positionOS.xyz);
    o.positionCS=p.positionCS; o.positionWS=p.positionWS;
    o.normalWS=TransformObjectToWorldNormal(a.normalOS);
    o.uv=TRANSFORM_TEX(a.uv,_BaseMap); o.shadowCoord=GetShadowCoord(p);
    o.fog=ComputeFogFactor(p.positionCS.z); return o;
   }
   half4 Frag(V i):SV_Target
   {
    half4 tex=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor;
    clip(tex.a-_Cutoff);
    float3 geometricN=normalize(i.normalWS);
    float3 n=normalize(lerp(geometricN,normalize(_HeadForward.xyz),_Flatten));
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
     float4 sc=i.shadowCoord;
    #else
     float4 sc=TransformWorldToShadowCoord(i.positionWS);
    #endif
    Light key=GetMainLight(sc);
    float band=smoothstep(_Threshold-_Feather,_Threshold+_Feather,dot(n,key.direction));
    // Form design is artistic. Real visibility multiplies AFTER the ramp, so an
    // occluded key contributes zero even with a nonzero form-shadow endpoint.
    float3 form=lerp(_ShadowTint.rgb*_ShadowValue,float3(1,1,1),band);
    float3 direct=form*key.color*(key.distanceAttenuation*key.shadowAttenuation)*(1.0/PI);
    // Shared probe illumination only: no emissive compensation or fixed face floor.
    float3 indirect=max(SampleSH(geometricN),0);
    #if defined(_ADDITIONAL_LIGHTS)
     InputData inputData=(InputData)0;
     inputData.positionWS=i.positionWS;
     inputData.normalizedScreenSpaceUV=GetNormalizedScreenSpaceUV(i.positionCS);
     uint count=GetAdditionalLightsCount();
     LIGHT_LOOP_BEGIN(count)
      Light l=GetAdditionalLight(lightIndex,i.positionWS,half4(1,1,1,1));
      // Secondary sources remain soft to avoid competing graphic face bands.
      direct+=l.color*(saturate(dot(n,l.direction))*l.distanceAttenuation*l.shadowAttenuation)*(1.0/PI);
     LIGHT_LOOP_END
    #endif
    return half4(MixFog(tex.rgb*(direct+indirect),i.fog),tex.a);
   }
   ENDHLSL
  }
  UsePass "Universal Render Pipeline/Lit/ShadowCaster"
  UsePass "Universal Render Pipeline/Lit/DepthOnly"
 }
}
