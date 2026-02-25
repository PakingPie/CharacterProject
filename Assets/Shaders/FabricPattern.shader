Shader "Custom/FabricPattern"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _NumberOfThreads("Number of Threads", Float) = 8
        _FabricIntensity("Fabric Intensity", Float) = 1
        _AmbientColorAmp("Ambient Color Amplifier", Float) = 1
        _AmbientColor("Ambient Color", Color) = (1, 1, 1, 1)
        _NormalStrength("Normal Strength", Float) = 1
        _NoiseScale("Noise Scale", Float) = 10
        _ThreadThickness("Thread Thickness", Float) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _NumberOfThreads;
                float _FabricIntensity;
                float _AmbientColorAmp;
                half4 _AmbientColor;
                float _NormalStrength;
                float _NoiseScale;
                float _ThreadThickness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.texcoord, _BaseMap);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.tangentWS = TransformObjectToWorldDir(IN.tangentOS.xyz);
                OUT.bitangentWS = cross(OUT.normalWS, OUT.tangentWS) * IN.tangentOS.w;
                return OUT;
            }

            void Hash_Tchou_2_1_uint(uint2 v, out uint o)
            {
                // ~6 alu (2 mul)
                v.y ^= 1103515245U;
                v.x += v.y;
                v.x *= v.y;
                v.x ^= v.x >> 5u;
                v.x *= 0x27d4eb2du;
                o = v.x;
            }

            void Hash_Tchou_2_1_float(float2 i, out float o)
            {
                uint r;
                uint2 v = (uint2) (int2) round(i);
                Hash_Tchou_2_1_uint(v, r);
                o = (r >> 8) * (1.0 / float(0x00ffffff));
            }

            float SimpleNoiseValueNoiseDeterministic (float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);
                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0; Hash_Tchou_2_1_float(c0, r0);
                float r1; Hash_Tchou_2_1_float(c1, r1);
                float r2; Hash_Tchou_2_1_float(c2, r2);
                float r3; Hash_Tchou_2_1_float(c3, r3);
                float bottomOfGrid = lerp(r0, r1, f.x);
                float topOfGrid = lerp(r2, r3, f.x);
                float t = lerp(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            float SimpleNoiseDeterministic(float2 UV, float Scale)
            {
                float freq, amp;
                float noise = 0.0f;
                freq = pow(2.0, float(0));
                amp = pow(0.5, float(3-0));
                noise += SimpleNoiseValueNoiseDeterministic(float2(UV.xy*(Scale/freq)))*amp;
                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3-1));
                noise += SimpleNoiseValueNoiseDeterministic(float2(UV.xy*(Scale/freq)))*amp;
                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3-2));
                noise += SimpleNoiseValueNoiseDeterministic(float2(UV.xy*(Scale/freq)))*amp;
                return noise;
            }

            float ColorMask(float3 In, float3 MaskColor, float Range, float Fuzziness)
            {
                float Distance = distance(MaskColor, In);
                return saturate(1 - (Distance - Range) / max(Fuzziness, 1e-5));
            }

            // Computes the fabric weave height at a given scaledUV — must match frag pattern logic exactly
            float FabricHeight(float2 scaledUV)
            {
                float vertPattern = floor(fmod(scaledUV.x, 2.0));
                float horiPattern = floor(fmod(scaledUV.y, 2.0));
                float pattern = vertPattern * horiPattern + (1.0 - vertPattern) * (1.0 - horiPattern);

                float vertNoise = SimpleNoiseDeterministic(scaledUV * float2(10, 1), _NoiseScale);
                vertNoise = (vertNoise * 2.0 - 1.0) * _FabricIntensity;
                float2 vertNoiseUV = scaledUV + (float2)vertNoise;
                vertNoiseUV.x = abs(vertNoiseUV.x - round(vertNoiseUV.x));

                float horiNoise = SimpleNoiseDeterministic(scaledUV * float2(1, 10), _NoiseScale);
                horiNoise = (horiNoise * 2.0 - 1.0) * _FabricIntensity;
                float2 horiNoiseUV = scaledUV + (float2)horiNoise;
                horiNoiseUV.y = abs(horiNoiseUV.y - round(horiNoiseUV.y));

                return max(pattern * vertNoiseUV.x, (1 - pattern) * horiNoiseUV.y);
            }

            // Sobel filter over the fabric height field to derive a tangent-space normal
            float3 NormalFromHeight(float2 scaledUV, float strength)
            {
                // texelSize in scaledUV space; ~1/20th of a thread width gives good edge detection
                float texelSize = 0.05;

                float h00 = FabricHeight(scaledUV + float2(-texelSize, -texelSize));
                float h10 = FabricHeight(scaledUV + float2( 0,         -texelSize));
                float h20 = FabricHeight(scaledUV + float2( texelSize, -texelSize));
                float h01 = FabricHeight(scaledUV + float2(-texelSize,  0        ));
                float h21 = FabricHeight(scaledUV + float2( texelSize,  0        ));
                float h02 = FabricHeight(scaledUV + float2(-texelSize,  texelSize));
                float h12 = FabricHeight(scaledUV + float2( 0,          texelSize));
                float h22 = FabricHeight(scaledUV + float2( texelSize,  texelSize));

                float sobelX = h00 - h20 + 2.0 * h01 - 2.0 * h21 + h02 - h22;
                float sobelY = h00 + 2.0 * h10 + h20 - h02 - 2.0 * h12 - h22;

                return normalize(float3(-sobelX * strength, -sobelY * strength, 1.0));
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 scaledUV = IN.uv * (ceil(_NumberOfThreads * 0.5) * 2);

                float vertPattern = floor(fmod(scaledUV.x, 2.0));
                float horiPattern = floor(fmod(scaledUV.y, 2.0));

                float pattern = vertPattern * horiPattern + (1.0 - vertPattern) * (1.0 - horiPattern);

                float vertNoise = SimpleNoiseDeterministic(scaledUV * float2(10, 1), _NoiseScale);
                vertNoise = vertNoise * 2.0 - 1.0; // remap to [-1, 1]
                vertNoise *= _FabricIntensity;
                float2 vertNoiseUV = scaledUV + (float2)vertNoise;
                vertNoiseUV.x = abs(vertNoiseUV.x - round(vertNoiseUV.x));
                float3 vertPatternColor = _BaseColor.rgb * pattern * vertNoiseUV.x;

                float horiNoise = SimpleNoiseDeterministic(scaledUV * float2(1, 10), _NoiseScale);
                horiNoise = horiNoise * 2.0 - 1.0; // remap to [-1, 1]
                horiNoise *= _FabricIntensity;
                float2 horiNoiseUV = scaledUV + (float2)horiNoise;
                horiNoiseUV.y = abs(horiNoiseUV.y - round(horiNoiseUV.y));
                float3 horiPatternColor = _BaseColor.rgb * (1 - pattern) * horiNoiseUV.y;
                
                float4 color = float4(0, 0, 0, 1);
                color.rgb = max(vertPatternColor, horiPatternColor);

                float3 maskedColor = ColorMask(color.rgb, float3(1, 1, 1), 1, 1);

                // Derive tangent-space normal from the fabric weave height field
                float3 normalTS = NormalFromHeight(scaledUV, _NormalStrength);
                
                // Transform tangent-space normal to world space using TBN matrix
                float3x3 TBN = float3x3(IN.tangentWS, IN.bitangentWS, IN.normalWS);
                float3 normalWS = normalize(mul(normalTS, TBN));

                // Optional: encode normal into color for visualization/storage
                // color.rgb = normalWS * 0.5 + 0.5;

                Light mainLight = GetMainLight();
                float nol = saturate(dot(mainLight.direction, normalWS));

                return nol;
            }
            ENDHLSL
        }
    }
}
