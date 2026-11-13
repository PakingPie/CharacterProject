#ifndef URP_MY_TOON_SHADER_OUTLINE_INCLUDED_HLSL
#define URP_MY_TOON_SHADER_OUTLINE_INCLUDED_HLSL

struct VertexInput
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
    float4 positionHCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normalDir : TEXCOORD1;
    float3 tangentDir : TEXCOORD2;
    float3 bitangentDir : TEXCOORD3;
    UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutput vert(VertexInput v)
{
    VertexOutput o = (VertexOutput)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    float4 objPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));

    o.uv = v.texcoord;

    float4 outlineSampler = tex2Dlod(_OutlineSampler, float4(TRANSFORM_TEX(o.uv, _OutlineSampler), 0.0, 0));

    //Baked Normal Texture for Outline
    o.normalDir = TransformObjectToWorldNormal(v.normalOS);
    o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangentOS.xyz, 0.0)).xyz);
    o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangentOS.w);
    float3x3 tangentTransform = float3x3(o.tangentDir, o.bitangentDir, o.normalDir);
    //UnpackNormal() can't be used, and so as follows. Do not specify a bump for the texture to be used.
    float4 bakedNormal = (tex2Dlod(_BakedNormalTex, float4(TRANSFORM_TEX(o.uv, _BakedNormalTex), 0.0, 0)) * 2 - 1);
    float3 bakedNormalDir = normalize(mul(bakedNormal.rgb, tangentTransform));
    //end
    float outlineThickness = (_OutlineThickness * 0.001 * smoothstep(_FarthestDistance, _NearestDistance, distance(objPos.rgb, _WorldSpaceCameraPos)) * outlineSampler.rgb).r;
    outlineThickness *= (1.0f - _ZOverDrawMode);

    float4 clipCameraPos = mul(UNITY_MATRIX_VP, float4(_WorldSpaceCameraPos.xyz, 1));

#if defined(UNITY_REVERSED_Z)
    _OffsetZ *= (-0.01);
#else
    _OffsetZ *= 0.01;
#endif

#ifdef _OUTLINE_NML
    o.positionHCS = TransformObjectToHClip(lerp(float4(v.positionOS.xyz + v.normalOS * outlineThickness, 1), float4(v.positionOS.xyz + bakedNormalDir * outlineThickness,1), _UseBakedNormal));
#elif _OUTLINE_POS
    outlineThickness *= 2;
    float sign = FastSign(dot(normalize(v.positionOS), normalize(v.normalOS)));
    o.positionHCS = TransformObjectToHClip(float4(v.positionOS.xyz + sign * normalize(v.positionOS) * outlineThickness, 1));
#endif
    o.positionHCS.z += _OffsetZ * clipCameraPos.z;
    return o;
}

float4 frag(VertexOutput i) : SV_Target
{
    if (_ZOverDrawMode > 0.99f)
    {
        return float4(1.0f, 1.0f, 1.0f, 1.0f);  // but nothing should be drawn except Z value as colormask is set to 0
    }
    _Color = _BaseColor;
            
    float3 envLightSource_GradientEquator = unity_AmbientEquator.rgb > 0.05 ? unity_AmbientEquator.rgb : half3(0.05, 0.05, 0.05);
    float3 envLightSource_SkyboxIntensity = max(ShadeSH9(half4(0.0, 0.0, 0.0, 1.0)), ShadeSH9(half4(0.0, -1.0, 0.0, 1.0))).rgb;
    float3 ambientSkyColor = envLightSource_SkyboxIntensity.rgb > 0.0 ? envLightSource_SkyboxIntensity * _UnlitIntensity : envLightSource_GradientEquator * _UnlitIntensity;

    float3 lightColor = _MainLightColor.rgb > 0.05 ? _MainLightColor.rgb : ambientSkyColor.rgb;
    float lightColorIntensity = (0.299 * lightColor.r + 0.587 * lightColor.g + 0.114 * lightColor.b);
    lightColor = lightColorIntensity < 1 ? lightColor : lightColor / lightColorIntensity;
    lightColor = lerp(half3(1.0, 1.0, 1.0), lightColor, _IsBlendLightColorToOutline);

    float2 uv = i.uv;
    float4 mainTexVal = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(uv, _MainTex));
    float3 baseCol = _BaseColor.rgb * mainTexVal.rgb;
    float3 blendBaseColVal = lerp(_OutlineColor.rgb * lightColor, (_OutlineColor.rgb * baseCol * baseCol * lightColor), _IsBlendBaseColorToOutline);

    float3 outlineTexColor = tex2D(_OutlineTex, TRANSFORM_TEX(uv, _OutlineTex)).rgb;

#ifdef _OUTLINE_CLIPPING_DISABLE
    float3 outputOutlineColor = lerp(blendBaseColVal, outlineTexColor * _OutlineColor.rgb * lightColor, _UseOutlineTex);
    return float4(outputOutlineColor, 1);
#elif _OUTLINE_CLIPPING_ENABLE
    float4 clippingMask = SAMPLE_TEXTURE2D(_ClippingMask, sampler_MainTex, TRANSFORM_TEX(uv, _ClippingMask));
    float mainTexAlpha = mainTexVal.a;
    float isBaseMapAlphaAsClippingMask = lerp(clippingMask.r, mainTexAlpha, _UseBaseMapAlphaAsClippingMask);
    float inverseClipping = lerp( isBaseMapAlphaAsClippingMask, (1.0 - isBaseMapAlphaAsClippingMask), _InverseClipping );
    float clipping = saturate((inverseClipping + _ClippingLevel));
    clip(clipping - 0.5);
    float4 outputOutlineColor = lerp( float4(blendBaseColVal, clipping), float4((outlineTexColor.rgb * _OutlineColor.rgb * lightColor), clipping), _UseOutlineTex);
    return float4(outputOutlineColor, 1);
#endif
}

#endif