Shader "Custom/URP/Cloth/Stockings"
{
    Properties
    {
        [Header(Base Properties)]
        [MainTexture] _BaseMap("基础贴图 (RGB: 颜色, A: 透明度)", 2D) = "white" {}
        [MainColor] _BaseColor("基础颜色", Color) = (1, 1, 1, 1)
        _Transparency("透明度", Range(0, 1)) = 0.3
        
        [Header(Surface Properties)]
        _Smoothness("光滑度", Range(0, 1)) = 0.85
        _Metallic("金属度", Range(0, 1)) = 0.0
        [Normal] _BumpMap("法线贴图 (织物微纹理)", 2D) = "bump" {}
        _BumpScale("法线强度", Range(0, 2)) = 0.3
        
        [Header(Stockings Sheen)]
        _SheenColor("光泽颜色", Color) = (1, 1, 1, 1)
        _SheenRoughness("光泽粗糙度", Range(0, 1)) = 0.25
        _SheenIntensity("光泽强度", Range(0, 1)) = 0.6
        
        [Header(Subsurface Scattering)]
        _SSSColor("SSS颜色 (模拟肤色透出)", Color) = (1, 0.8, 0.7, 1)
        _SSSIntensity("SSS强度", Range(0, 2)) = 0.8
        _SSSDistortion("SSS扭曲", Range(0, 1)) = 0.3
        _SSSPower("SSS衰减", Range(0.1, 10)) = 2.0
        _SSSScale("SSS缩放", Range(0, 10)) = 2.0
        
        [Header(Anisotropic Highlights)]
        [Toggle(_ANISOTROPIC)] _Anisotropic("启用各向异性", Float) = 1
        _AnisotropicDirection("各向异性方向 (切线空间)", Vector) = (0, 1, 0, 0)
        _AnisotropicIntensity("各向异性强度", Range(0, 1)) = 0.3
        _AnisotropicRoughness("各向异性粗糙度", Range(0, 1)) = 0.6
        
        [Header(Rim Light)]
        _RimColor("边缘光颜色", Color) = (1, 1, 1, 1)
        _RimPower("边缘光强度", Range(0.1, 10)) = 3.0
        _RimIntensity("边缘光倍增", Range(0, 2)) = 0.8
        
        [Header(Fabric Detail)]
        _FabricDetailMap("织物细节贴图 (可选)", 2D) = "white" {}
        _FabricDetailStrength("织物细节强度", Range(0, 1)) = 0.1
        _FabricTiling("织物平铺", Float) = 50.0
        
        [Header(Render Settings)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("剔除模式", Float) = 2
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("源混合", Float) = 5  // SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("目标混合", Float) = 10 // OneMinusSrcAlpha
        [Toggle] _ZWrite("深度写入", Float) = 0
    }
    
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        LOD 300
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]
            
            HLSLPROGRAM
            #pragma target 3.5
            
            // URP 关键字
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            
            // Shader 功能关键字
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ANISOTROPIC
            
            #pragma vertex StockingsVertex
            #pragma fragment StockingsFragment
            
            // URP 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            // 材质属性缓冲区 (SRP Batcher 兼容)
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _Transparency;
                float _Smoothness;
                float _Metallic;
                float4 _BumpMap_ST;
                float _BumpScale;
                
                float4 _SheenColor;
                float _SheenRoughness;
                float _SheenIntensity;
                
                float4 _SSSColor;
                float _SSSIntensity;
                float _SSSDistortion;
                float _SSSPower;
                float _SSSScale;
                
                float4 _AnisotropicDirection;
                float _AnisotropicIntensity;
                float _AnisotropicRoughness;
                
                float4 _RimColor;
                float _RimPower;
                float _RimIntensity;
                
                float4 _FabricDetailMap_ST;
                float _FabricDetailStrength;
                float _FabricTiling;
            CBUFFER_END
            
            // 纹理
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_FabricDetailMap);    SAMPLER(sampler_FabricDetailMap);
            
            // 顶点输入结构
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
                float2 staticLightmapUV : TEXCOORD1;
                float2 dynamicLightmapUV : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            // 片元输入结构
            struct Varyings
            {
                float4 positionCS               : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                float3 positionWS               : TEXCOORD1;
                float3 normalWS                 : TEXCOORD2;
                float4 tangentWS                : TEXCOORD3;
                float3 viewDirWS                : TEXCOORD4;
                half4 fogFactorAndVertexLight   : TEXCOORD5;
                
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord          : TEXCOORD6;
                #endif
                
                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
                
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            // ==================== 辅助函数 ====================
            
            // Charlie Sheen BRDF - 用于模拟丝袜光泽
            half CharlieSheen(half NdotH, half roughness)
            {
                half invR = 1.0 / roughness;
                half cos2h = NdotH * NdotH;
                half sin2h = 1.0 - cos2h;
                return (2.0 + invR) * pow(sin2h, invR * 0.5) / (2.0 * PI);
            }
            
            // 简化的次表面散射 (薄层近似)
            half3 SubsurfaceScattering(half3 lightDir, half3 viewDir, half3 normal, half3 sssColor, 
                                       half intensity, half distortion, half power, half scale)
            {
                // 计算透射光方向
                half3 H = normalize(lightDir + normal * distortion);
                half VdotH = pow(saturate(dot(viewDir, -H)), power) * scale;
                return sssColor * (VdotH * intensity);
            }
            
            // 各向异性高光 (简化版 Ward 模型)
            half AnisotropicSpecular(half3 H, half3 T, half3 B, half3 N, half roughness, half anisotropy)
            {
                half TdotH = dot(T, H);
                half BdotH = dot(B, H);
                half NdotH = dot(N, H);
                
                half roughnessT = roughness * (1.0 + anisotropy);
                half roughnessB = roughness * (1.0 - anisotropy);
                
                half normalization = 1.0 / (PI * roughnessT * roughnessB);
                half term1 = TdotH * TdotH / (roughnessT * roughnessT);
                half term2 = BdotH * BdotH / (roughnessB * roughnessB);
                half exponent = -(term1 + term2) / (NdotH * NdotH + 0.0001);
                
                return normalization * exp(exponent);
            }
            
            // 生成程序化织物噪声
            half FabricNoise(float2 uv, float tiling)
            {
                float2 scaledUV = uv * tiling;
                // 简单的编织图案
                half weaveX = sin(scaledUV.x * PI * 2.0) * 0.5 + 0.5;
                half weaveY = sin(scaledUV.y * PI * 2.0) * 0.5 + 0.5;
                half weave = weaveX * weaveY;
                
                // 添加高频噪声
                half noise = frac(sin(dot(scaledUV, float2(12.9898, 78.233))) * 43758.5453);
                return lerp(weave, noise, 0.3);
            }
            
            // ==================== 顶点着色器 ====================
            Varyings StockingsVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.normalWS = normalInput.normalWS;
                
                real sign = input.tangentOS.w * GetOddNegativeScale();
                output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
                
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                
                // 光照和雾效
                half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                
                // 光照贴图和阴影
                OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
                
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    output.shadowCoord = GetShadowCoord(vertexInput);
                #endif
                
                return output;
            }
            
            // ==================== 片元着色器 ====================
            half4 StockingsFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                // 采样基础纹理
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = baseMap.rgb * _BaseColor.rgb;
                half alpha = baseMap.a * _BaseColor.a * (1.0 - _Transparency);
                
                // 法线映射
                #ifdef _NORMALMAP
                    half4 normalMap = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                    half3 normalTS = UnpackNormalScale(normalMap, _BumpScale);
                #else
                    half3 normalTS = half3(0, 0, 1);
                #endif
                
                // 添加程序化织物细节
                half fabricNoise = FabricNoise(input.uv, _FabricTiling);
                normalTS.xy += (fabricNoise - 0.5) * _FabricDetailStrength;
                
                // 构建切线空间到世界空间的矩阵
                float sgn = input.tangentWS.w;
                float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz);
                half3 normalWS = normalize(mul(normalTS, tangentToWorld));
                
                // 视图方向
                half3 viewDirWS = normalize(input.viewDirWS);
                
                // 光照数据初始化
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = viewDirWS;
                inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                inputData.fogCoord = input.fogFactorAndVertexLight.x;
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, normalWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
                
                // 表面数据
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo;
                surfaceData.metallic = _Metallic;
                surfaceData.specular = half3(0, 0, 0);
                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS = normalTS;
                surfaceData.emission = half3(0, 0, 0);
                surfaceData.occlusion = 1.0;
                surfaceData.alpha = alpha;
                surfaceData.clearCoatMask = 0.0;
                surfaceData.clearCoatSmoothness = 0.0;
                
                // 主光源
                Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
                
                // 基础 PBR 光照
                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                
                // ==================== 丝袜特有效果 ====================
                
                half3 L = normalize(mainLight.direction);
                half3 N = normalWS;
                half3 V = viewDirWS;
                half3 H = normalize(L + V);
                
                half NdotL = saturate(dot(N, L));
                half NdotV = saturate(dot(N, V));
                half NdotH = saturate(dot(N, H));
                
                // 1. Charlie Sheen 光泽层 (丝袜特有的柔和光泽)
                half sheenTerm = CharlieSheen(NdotH, _SheenRoughness);
                half3 sheen = _SheenColor.rgb * sheenTerm * _SheenIntensity * mainLight.color * NdotL;
                color.rgb += sheen;
                
                // 2. 次表面散射 (模拟肤色透出)
                half3 sss = SubsurfaceScattering(L, V, N, _SSSColor.rgb, _SSSIntensity, 
                                                  _SSSDistortion, _SSSPower, _SSSScale);
                sss *= mainLight.color * mainLight.shadowAttenuation;
                color.rgb += sss;
                
                // 3. 各向异性高光 (沿腿部方向的纤维高光)
                #ifdef _ANISOTROPIC
                    half3 tangentWS = normalize(input.tangentWS.xyz);
                    half3 bitangentWS = normalize(bitangent);
                    
                    // 应用自定义方向
                    half3 anisoDir = normalize(_AnisotropicDirection.xyz);
                    tangentWS = normalize(tangentWS * anisoDir.x + bitangentWS * anisoDir.y + N * anisoDir.z);
                    bitangentWS = normalize(cross(N, tangentWS));
                    
                    half anisoSpec = AnisotropicSpecular(H, tangentWS, bitangentWS, N, 
                                                         _AnisotropicRoughness, _AnisotropicIntensity);
                    half3 anisotropic = anisoSpec * mainLight.color * NdotL * 0.5;
                    color.rgb += anisotropic;
                #endif
                
                // 4. 边缘光 (增强透明感和轮廓)
                half rim = 1.0 - NdotV;
                rim = pow(rim, _RimPower);
                half3 rimLight = _RimColor.rgb * rim * _RimIntensity;
                color.rgb += rimLight;
                
                // 应用雾效
                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                
                // 输出最终颜色
                color.a = alpha;
                return color;
            }
            
            ENDHLSL
        }
        
        // 阴影投射 Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]
            
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _Transparency;
                float _Smoothness;
                float _Metallic;
                float4 _BumpMap_ST;
                float _BumpScale;
                
                float4 _SheenColor;
                float _SheenRoughness;
                float _SheenIntensity;
                
                float4 _SSSColor;
                float _SSSIntensity;
                float _SSSDistortion;
                float _SSSPower;
                float _SSSScale;
                
                float4 _AnisotropicDirection;
                float _AnisotropicIntensity;
                float _AnisotropicRoughness;
                
                float4 _RimColor;
                float _RimPower;
                float _RimIntensity;
                
                float4 _FabricDetailMap_ST;
                float _FabricDetailStrength;
                float _FabricTiling;
            CBUFFER_END
            
            // 纹理
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_FabricDetailMap);    SAMPLER(sampler_FabricDetailMap);
            
            float3 _LightDirection;
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
            };
            
            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                
                return positionCS;
            }
            
            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }
            
            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
        
        // 深度 Pass
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ZWrite On
            ColorMask 0
            Cull [_Cull]
            
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseColor;
                float _Transparency;
                float _Smoothness;
                float _Metallic;
                float4 _BumpMap_ST;
                float _BumpScale;
                
                float4 _SheenColor;
                float _SheenRoughness;
                float _SheenIntensity;
                
                float4 _SSSColor;
                float _SSSIntensity;
                float _SSSDistortion;
                float _SSSPower;
                float _SSSScale;
                
                float4 _AnisotropicDirection;
                float _AnisotropicIntensity;
                float _AnisotropicRoughness;
                
                float4 _RimColor;
                float _RimPower;
                float _RimIntensity;
                
                float4 _FabricDetailMap_ST;
                float _FabricDetailStrength;
                float _FabricTiling;
            CBUFFER_END
            
            // 纹理
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_FabricDetailMap);    SAMPLER(sampler_FabricDetailMap);
            
            struct Attributes
            {
                float4 position     : POSITION;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = TransformObjectToHClip(input.position.xyz);
                return output;
            }
            
            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                return 0;
            }
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
}