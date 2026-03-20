Shader "Unlit/MarschnerHairLightingModel"
{
    Properties
    {
        _MainTex("PropertyMap R-Depth G-ID B-Root A-Alpha", 2D) = "white" {}
        _Flowmap("Flowmap", 2D) = "white" {}
        _RootColor("RootColor", Color) = (0,0,0,1)
        _TipColor("TipColor", Color) = (0,0,0,1)
        _ColorVariationRange("ColorVariation-HSV", Vector) = (0,0,0,1)
        _EccentricityMean("EccentricityMean", Float) = 0.07
        _RoughnessRange("RoughnessRange", Vector) = (0.3, 0.5,0,0)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "AlphaTest"
        }

        LOD 200
        Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

        #pragma vertex vert
        #pragma fragment frag
        #pragma target 4.5

        sampler2D _MainTex;
        sampler2D _Flowmap;
        float4 _RootColor;
        float4 _TipColor;
        float4 _ColorVariationRange;
        float _EccentricityMean;
        float4 _RoughnessRange;

        float4 _MainTex_ST;
        float4 _Flowmap_ST;

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float4 screenUV : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float4 tangentWS : TEXCOORD3;
            float3 positionWS : TEXCOORD4;
            UNITY_VERTEX_OUTPUT_STEREO
        };

        v2f vert(appdata v)
        {
            v2f o = (v2f)0;
            o.positionCS = TransformObjectToHClip(v.vertex);
            o.uv = TRANSFORM_TEX(v.uv, _MainTex);
            o.screenUV = ComputeScreenPos(o.positionCS);
            o.normalWS = TransformObjectToWorld(v.normal.xyz);
            o.tangentWS.xyz = TransformObjectToWorld(v.tangent.xyz);
            o.tangentWS.w = v.tangent.w;
            o.positionWS = TransformObjectToWorld(v.vertex.xyz);
            return o;
        }

        #define square(x) ((x)*(x))
        #define SQRT2PI 2.50663

        float ScreenDitherToAlpha(float x, float y, float c0)
        {
            float out_dither = 0;
            const float dither[64] = 
            {
                0, 32, 8, 40, 2, 34, 10, 42,
                48, 16, 56, 24, 50, 18, 58, 26 ,
                12, 44, 4, 36, 14, 46, 6, 38 ,
                60, 28, 52, 20, 62, 30, 54, 22,
                3, 35, 11, 43, 1, 33, 9, 41,
                51, 19, 59, 27, 49, 17, 57, 25,
                15, 47, 7, 39, 13, 45, 5, 37,
                63, 31, 55, 23, 61, 29, 53, 21 
            };

            int xMat = int(x) & 7;
            int yMat = int(y) & 7;

            float limit = (dither[yMat * 8 + xMat] + 11.0) / 64.0;
            out_dither = lerp(limit*c0, 1.0, c0);

            return out_dither;
        }

        float3 RGB2HSV(float3 c)
        {
            float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
            float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

            float d = q.x - min(q.w, q.y);
            float e = 1.0e-10;
            float3 out_hsv = float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);

            return out_hsv;
        }

        float3 HSV2RGB(float3 c)
        {
            float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
            float3 out_rgb = c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);

            return out_rgb;
        }

        inline float HairGaussianDistribution(float B, float Theta)
        {
            return exp(-0.5 * square(Theta) / (B*B)) / (SQRT2PI * B);
        }

        float HairIOF(float Eccentric) 
        {
            float n = 1.55;
            float a = 1 - Eccentric;
            float ior1 = 2 * (n - 1) * (a * a) - n + 2;
            float ior2 = 2 * (n - 1) / (a * a) - n + 2;
            return 0.5f * ((ior1 + ior2) + 0.5f * (ior1 - ior2)); //assume cos2PhiH = 0.5f 
        }

        inline float3 SpecularFresnel(float3 F0, float vDotH) 
        {
            return F0 + (1.0f - F0) * pow(1 - vDotH, 5);
        }

        float3 HairDiffuseKajiyaUE(float3 L, float3 V, half3 N, float3 Albedo, half Shadow, float Backlit, float Area) 
        {
            float3 Scattering = 0;
            float KajiyaDiffuse = 1 - abs(dot(N, L));

            float3 FakeNormal = normalize(V - N * dot(V, N));
            N = FakeNormal;

            // Hack approximation for multiple scattering.
            float Wrap = 1;
            float NoL = saturate((dot(N, L) + Wrap) / ((1 + Wrap) * (1 + Wrap)));
            float DiffuseScatter = (1 / PI) * lerp(NoL, KajiyaDiffuse, 0.33);// *s.Metallic;
            float Luma = Luminance(Albedo);
            float3 ScatterTint = pow(Albedo / Luma, 1 - Shadow);
            Scattering = sqrt(Albedo) * DiffuseScatter * ScatterTint;

            return Scattering;
        }

        float3 HairSpecularMarschner(float3 L, float3 V, half3 N, float3 Albedo, float Roughness, float Eccentric, float Shadow, float Backlit, float Area)
        {
            float3 Scattering = 0;

            const float VoL = dot(V, L);
            const float SinThetaL = dot(N, L);
            const float SinThetaV = dot(N, V);
            float cosThetaL = sqrt(max(0, 1 - SinThetaL * SinThetaL));
            float cosThetaV = sqrt(max(0, 1 - SinThetaV * SinThetaV));
            float CosThetaD = sqrt((1 + cosThetaL * cosThetaV + SinThetaV * SinThetaL) / 2.0);

            const float3 Lp = L - SinThetaL * N;
            const float3 Vp = V - SinThetaV * N;
            const float CosPhi = dot(Lp, Vp) * rsqrt(dot(Lp, Lp) * dot(Vp, Vp) + 1e-4);
            const float CosHalfPhi = sqrt(saturate(0.5 + 0.5 * CosPhi));

            float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

            float Shift = 0.0499f;
            float Alpha[] =
            {
                -0.0998,//-Shift * 2,
                0.0499f,// Shift,
                0.1996  // Shift * 4
            };
            float B[] =
            {
                Area + square(Roughness),
                Area + square(Roughness) / 2,
                Area + square(Roughness) * 2
            };

            float hairIOF = HairIOF(Eccentric);
            float F0 = square((1 - hairIOF) / (1 + hairIOF));

            float3 Tp;
            float Mp, Np, Fp, a, h, f;
            float ThetaH = SinThetaL + SinThetaV;
            // R
            Mp = HairGaussianDistribution(B[0], ThetaH - Alpha[0]);
            Np = 0.25 * CosHalfPhi;
            Fp = SpecularFresnel(F0, sqrt(saturate(0.5 + 0.5 * VoL)));
            Scattering += (Mp * Np) * (Fp * lerp(1, Backlit, saturate(-VoL)));

            // TT
            Mp = HairGaussianDistribution(B[1], ThetaH - Alpha[1]);
            a = (1.55f / hairIOF) * rcp(n_prime);
            h = CosHalfPhi * (1 + a * (0.6 - 0.8 * CosPhi));
            f = SpecularFresnel(F0, CosThetaD * sqrt(saturate(1 - h * h)));
            Fp = square(1 - f);
            Tp = pow(Albedo, 0.5 * sqrt(1 - square((h * a))) / CosThetaD);
            Np = exp(-3.65 * CosPhi - 3.98);
            Scattering += (Mp * Np) * (Fp * Tp) * Backlit;

            // TRT
            Mp = HairGaussianDistribution(B[2], ThetaH - Alpha[2]);
            f = SpecularFresnel(F0, CosThetaD * 0.5f);
            Fp = square(1 - f) * f;
            Tp = pow(Albedo, 0.8 / CosThetaD);
            Np = exp(17 * CosPhi - 16.78);

            Scattering += (Mp * Np) * (Fp * Tp);

            return Scattering;
        }

        float3 ComputeHairBxDF(float3 L, float3 V, half3 N, float3 Albedo, float Roughness, float Eccentric, float Shadow, float Backlit, float Area)
        {
            float3 marschnerSpecular = HairSpecularMarschner(L, V, N, Albedo, Roughness, Eccentric, Shadow, Backlit,Area);
            float3 KajiyaDiffuse = HairDiffuseKajiyaUE(L, V, N, Albedo, Shadow, Backlit, Area);
            float3 hairBxDF = marschnerSpecular + KajiyaDiffuse;
            hairBxDF = -min(-hairBxDF, 0.0);
            return hairBxDF;
        }
        ENDHLSL

        Pass
        {
            Cull Off
            HLSLPROGRAM
            float4 frag(v2f i) : SV_Target
            {
                // return 1;
                float4 property = tex2D(_MainTex, i.uv);
                float4 flowmap = tex2D(_Flowmap, i.uv);

                float3 baseColor = lerp(_RootColor.rgb, _TipColor.rgb, property.b);
                float3 baseColorHSV = RGB2HSV(baseColor);
                baseColorHSV += (property.g - 0.5) * _ColorVariationRange.rgb * _ColorVariationRange.a;
                float3 albedo = HSV2RGB(baseColorHSV);

                float eccentric = lerp(0.0, _EccentricityMean * 2, property.r);

                float3 normal = UnpackNormal(flowmap);
                // Convert normal to world space, the flowmap is in tangent space.
                float renormFactor = 1.0 / length(i.normalWS);
                float crossSign = (i.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
                float3 bitang = crossSign * cross(i.normalWS, i.tangentWS.xyz);
                float3 normalWS = renormFactor * i.normalWS;
                float3 tangentWS = renormFactor * i.tangentWS.xyz;
                float3 bitangentWS = renormFactor * bitang;
                normal = TransformTangentToWorld(normal, float3x3(tangentWS, bitangentWS, normalWS)); 

                float roughness = lerp(_RoughnessRange.x, _RoughnessRange.y, property.g);

                float2 screenPixel = (i.screenUV.xy / i.screenUV.w) * _ScreenParams.xy + _Time.yz * 100;
                float dither = ScreenDitherToAlpha(screenPixel.x, screenPixel.y, property.a);
                float alpha = dither;

                clip(alpha - 0.5);

                float4 color = float4(0, 0, 0, alpha);

                Light mainLight = GetMainLight(0);

                float3 viewDirWS = normalize(GetCameraPositionWS() - i.positionWS);
                float3 lightDirWS = normalize(mainLight.direction);

                float3 hairBxDF = ComputeHairBxDF(lightDirWS, viewDirWS, normal, albedo, roughness, eccentric, 1.0, 1.0, 0.0);
                color.rgb = mainLight.color * hairBxDF;
                float3 indirectLightDir = normalize(viewDirWS - i.normalWS * dot(i.normalWS, viewDirWS));
                color.rgb += .1 * 6.28f * ComputeHairBxDF(indirectLightDir, viewDirWS, normal, albedo, roughness, eccentric, 1.0, 0.0, 0.2);
                // color.rgb += GetBakedGI(i.positionWS, normal, albedo);
                return color;
            }
            ENDHLSL
        }
    }
}