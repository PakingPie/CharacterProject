#ifndef MARCHNER_HAIR_MODEL_UTILITIES_HLSL
#define MARCHNER_HAIR_MODEL_UTILITIES_HLSL

    // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
    #define SQRT2PI 2.50663

    #define square(x) ((x) * (x))

    void ScreenDitherToAlpha_float(float x, float y, float c0, out float out_dither)
    {
        const float dither[64] = {
            0, 32, 8, 40, 2, 34, 10, 42,
            48, 16, 56, 24, 50, 18, 58, 26 ,
            12, 44, 4, 36, 14, 46, 6, 38 ,
            60, 28, 52, 20, 62, 30, 54, 22,
            3, 35, 11, 43, 1, 33, 9, 41,
            51, 19, 59, 27, 49, 17, 57, 25,
            15, 47, 7, 39, 13, 45, 5, 37,
            63, 31, 55, 23, 61, 29, 53, 21 };

        int xMat = int(x) & 7;
        int yMat = int(y) & 7;

        float limit = (dither[yMat * 8 + xMat] + 11.0) / 64.0;
        out_dither = lerp(limit*c0, 1.0, c0);
    }

    void RGB2HSV_float(float3 c, out float3 out_hsv)
    {
        float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
        float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
        float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;
        out_hsv = float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    }

    void HSV2RGB_float(float3 c, out float3 out_rgb)
    {
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
        out_rgb = c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }

    void HairGaussianDistribution_float(float Beta, float Theta, out float out_Gaussian)
    {
        out_Gaussian = exp(-0.5 * square(Theta) / square(Beta)) / (SQRT2PI * Beta);
    }
    
    float HairGaussian(float Beta, float Theta)
    {
        return exp(-0.5 * square(Theta) / square(Beta)) / (SQRT2PI * Beta);
    }

    float HairIOF(float Eccentric) 
    {
        float n = 1.55;
        float a = 1 - Eccentric;
        float ior1 = 2 * (n - 1) * (a * a) - n + 2;
        float ior2 = 2 * (n - 1) / (a * a) - n + 2;
        return 0.5 * ((ior1 + ior2) + 0.5 * (ior1 - ior2)); //assume cos2PhiH = 0.5f 
    }

    float3 SpecularFresnel(float3 F0, float vDotH) 
    {
        return F0 + (1.0 - F0) * pow(1 - vDotH, 5);
    }

    inline float3 SpecularFresnelLayer(float3 F0, float vDotH, float layer) 
    {
        float3 fresnel = SpecularFresnel(F0,  vDotH);
        return (fresnel * layer) / (1 + (layer-1) * fresnel);
    }

    void HairDiffuseKajiyaUE_float(float3 L, float3 V, half3 N, float3 Albedo, half Shadow, float Backlit, float Area, out float3 Scattering) 
    {
        Scattering = 0;
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
    }

    void HairSpecularMarschner_float(
        float3 L, float3 V, half3 N, 
        float3 Albedo, float Roughness, float Eccentric,
        float Shadow, float Backlit, float Area, 
        out float3 Scattering)
    {
        Scattering = 0;

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
        Mp = HairGaussian(B[0], ThetaH - Alpha[0]);
        Np = 0.25 * CosHalfPhi;
        Fp = SpecularFresnel(F0, sqrt(saturate(0.5 + 0.5 * VoL)));
        Scattering += (Mp * Np) * (Fp * lerp(1, Backlit, saturate(-VoL)));

        // TT
        Mp = HairGaussian(B[1], ThetaH - Alpha[1]);
        a = (1.55f / hairIOF) * rcp(n_prime);
        h = CosHalfPhi * (1 + a * (0.6 - 0.8 * CosPhi));
        f = SpecularFresnel(F0, CosThetaD * sqrt(saturate(1 - h * h)));
        Fp = square(1 - f);
        Tp = pow(Albedo, 0.5 * sqrt(1 - square((h * a))) / CosThetaD);
        Np = exp(-3.65 * CosPhi - 3.98);
        Scattering += (Mp * Np) * (Fp * Tp) * Backlit;

        // TRT
        Mp = HairGaussian(B[2], ThetaH - Alpha[2]);
        f = SpecularFresnel(F0, CosThetaD * 0.5f);
        Fp = square(1 - f) * f;
        Tp = pow(Albedo, 0.8 / CosThetaD);
        Np = exp(17 * CosPhi - 16.78);

        Scattering += (Mp * Np) * (Fp * Tp);
    }

#endif