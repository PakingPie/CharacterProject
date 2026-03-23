#ifndef URP_MY_TOON_SHADER_WITH_FEATHER_INCLUDED_HLSL
    #define URP_MY_TOON_SHADER_WITH_FEATHER_INCLUDED_HLSL

    struct a2v
    {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float4 tangent : TANGENT;
        float2 uv0 : TEXCOORD0;

        #ifdef _DISABLE_ANGELRING
            float2 lightmapUV : TEXCOORD1;
        #elif _ENABLE_ANGELRING
            float2 uv1 : TEXCOORD1;
            float2 lightmapUV : TEXCOORD2;
        #endif

        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
        float2 uv0 : TEXCOORD0;
        #ifdef _DISABLE_ANGELRING
            float4 posWorld : TEXCOORD1;
            float3 normalDir : TEXCOORD2;
            float3 tangentDir : TEXCOORD3;
            float3 bitangentDir : TEXCOORD4;
            float mirrorFlag : TEXCOORD5;

            DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
            
            #if defined(_ADDITIONAL_LIGHTS_VERTEX) || (VERSION_LOWER(12, 0))
                half4 fogFactorAndVertexLight : TEXCOORD7; // x: fogFactor, yzw: vertex light
            #else
                half fogFactor : TEXCOORD7;
            #endif

            #ifndef _MAIN_LIGHT_SHADOWS
                float4 positionCS : TEXCOORD8;
                int mainLightID : TEXCOORD9;
            #else
                float4 shadowCoord : TEXCOORD8;
                float4 positionCS : TEXCOORD9;
                int mainLightID : TEXCOORD10;
            #endif

            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        #elif _ENABLE_ANGELRING
            float2 uv1 : TEXCOORD1;
            float4 posWorld : TEXCOORD2;
            float3 normalDir : TEXCOORD3;
            float3 tangentDir : TEXCOORD4;
            float3 bitangentDir : TEXCOORD5;
            float mirrorFlag : TEXCOORD6;

            DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 7);
            
            #if defined(_ADDITIONAL_LIGHTS_VERTEX) || (VERSION_LOWER(12, 0))
                half4 fogFactorAndVertexLight : TEXCOORD8; // x: fogFactor, yzw: vertex light
            #else
                half fogFactor : TEXCOORD8; // x: fogFactor, yzw: vertex light
            #endif

            #ifndef _MAIN_LIGHT_SHADOWS
                float4 positionCS : TEXCOORD9;
                int mainLightID : TEXCOORD10;
            #else
                float4 shadowCoord : TEXCOORD9;
                float4 positionCS : TEXCOORD10;
                int mainLightID : TEXCOORD11;
            #endif

            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO

        #else
            // No need implementation
        #endif
    };

    v2f vert(a2v i) 
    {
        v2f o = (v2f)0;

        UNITY_SETUP_INSTANCE_ID(i);
        UNITY_TRANSFER_INSTANCE_ID(i, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        o.uv0 = i.uv0;
        #ifdef _DISABLE_ANGELRING
            // No need implementation
        #elif _ENABLE_ANGELRING
            o.uv1 = i.uv1;
        #endif

        o.normalDir = UnityObjectToWorldNormal(i.normal);
        o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(i.tangent.xyz, 0.0)).xyz);
        o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * i.tangent.w);
        o.posWorld = mul(unity_ObjectToWorld, i.vertex);
        o.pos = UnityObjectToClipPos(i.vertex);

        // Detection of the inside the mirror (right or left-handed) o.mirrorFlag = -1 then "inside the mirror".
        float3 crossFwd = cross(UNITY_MATRIX_V[0].xyz, UNITY_MATRIX_V[1].xyz);
        o.mirrorFlag = dot(crossFwd, UNITY_MATRIX_V[2].xyz) < 0 ? 1 : -1;

        float3 positionWS = TransformObjectToWorld(i.vertex.xyz);
        float4 positionCS = TransformWorldToHClip(positionWS);
        half3 vertexLight = VertexLighting(o.posWorld.xyz, o.normalDir);
        half fogFactor = ComputeFogFactor(positionCS.z);

        OUTPUT_LIGHTMAP_UV(i.lightmapUV, unity_LightmapST, o.lightmapUV);
        OUTPUT_SH(o.normalDir.xyz, o.vertexSH);

        #if defined(_ADDITIONAL_LIGHTS_VERTEX) || (VERSION_LOWER(12, 0))
            o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
        #else
            o.fogFactor = fogFactor;
        #endif

        o.positionCS = positionCS;

        #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
            #if SHADOWS_SCREEN
                o.shadowCoord = ComputeScreenPos(positionCS);
            #else
                o.shadowCoord = TransformWorldToShadowCoord(o.posWorld.xyz);
            #endif
            o.mainLightID = GetToonMainLightIndex(o.posWorld.xyz, o.shadowCoord, positionCS);
        #else
            o.mainLightID = GetToonMainLightIndex(o.posWorld.xyz, 0, positionCS);
        #endif
        return o;
    }

    float4 frag(v2f i, half facing : VFACE) : SV_Target
    {
        i.normalDir = normalize(i.normalDir);
        float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
        float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
        float2 uv = i.uv0;

        // Normal can be sampled from normal map and perturbed
        // If not using normal map, all related code is removed
        float3 normalMapNormal = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_MainTex, TRANSFORM_TEX(uv, _NormalMap)), _BumpScale);
        float3 normalDirection = normalize(mul( normalMapNormal, tangentTransform )); // Perturbed normals
        float3 localNormal = i.normalDir;

        SurfaceData surfaceData;
        InitializeStandardLitSurfaceDataToon(i.uv0, surfaceData);
        
        InputData inputData;
        Varyings input = (Varyings)0;

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        #ifdef LIGHTMAP_ON
            // No need implementation
        #else
            input.vertexSH = i.vertexSH;
        #endif

        input.uv = i.uv0;

        #if defined(_ADDITIONAL_LIGHTS_VERTEX) || (VERSION_LOWER(12, 0))
            input.fogFactorAndVertexLight = i.fogFactorAndVertexLight;
        #else
            input.fogFactor = i.fogFactor;
        #endif

        #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
            input.shadowCoord = i.shadowCoord;
        #endif

        #ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
            input.positionWS = i.posWorld.xyz;
        #endif

        #ifdef _NORMALMAP
            input.normalWS = half4(i.normalDir, viewDirection.x);   // xyz: normal, w: viewDir.x
            input.tangentWS = half4(i.tangentDir, viewDirection.y); // xyz: tangent, w: viewDir.y
            #if (VERSION_LOWER(7, 5))
                input.bitangentWS = half4(i.bitangentDir, viewDirection.z); // xyz: bitangent, w: viewDir.z
            #endif
        #else
            input.normalWS = half3(i.normalDir);
            #if (VERSION_LOWER(12, 0))
                input.viewDirWS = half3(viewDirection);
            #endif
        #endif

        InitializeInputData(input, surfaceData.normalTS, inputData);
        BRDFData brdfData;
        InitializeBRDFData(surfaceData.albedo,
                            surfaceData.metallic,
                            surfaceData.specular,
                            surfaceData.smoothness,
                            surfaceData.alpha, brdfData);
        
        half3 envColor = GetGlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.normalWS, inputData.viewDirectionWS);
        envColor *= 1.8f;

        ToonLight mainLight = GetToonMainLightByID(i.mainLightID, i.posWorld.xyz, inputData.shadowCoord, i.positionCS);
        // This returns black due to mainlight.distanceAttenuation being 0, fixed by setting it to 1
        half3 mainLightColor = GetLightColor(mainLight);
        
        float4 mainTexColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(uv, _MainTex));

        #if defined(_CLIPPING_ENABLE_STDMODE)
            float4 clippingMaskVal = SAMPLE_TEXTURE2D(_ClippingMask, sampler_MainTex, TRANSFORM_TEX(uv, _ClippingMask));
            float clipping = saturate(lerp(clippingMaskVal.r, (1.0 - clippingMaskVal.r), _InverseClipping) + _ClippingLevel);
            clip(clipping - 0.5);
        #elif defined(_ENABLE_TRANSCLIPPING) || defined(_CLIPPING_ENABLE_TRANSMODE)
            float4 clippingMaskVal = SAMPLE_TEXTURE2D(_ClippingMask, sampler_MainTex, TRANSFORM_TEX(uv, _ClippingMask));
            float mainTexAlpha = mainTexColor.a;
            float baseMapAlphaAsClippingMask = lerp(clippingMaskVal.r, mainTexAlpha, _UseBaseMapAlphaAsClippingMask);
            float invClippingVal = lerp(baseMapAlphaAsClippingMask, (1.0 - baseMapAlphaAsClippingMask), _InverseClipping);
            float cliping = saturate((invClippingVal + _ClippingLevel));
            clip(cliping - 0.5);
        #elif defined(_CLIPPING_DISABLE) || defined(_DISABLE_TRANSCLIPPING)
            // No need implementation
        #endif

        float shadowAttenuation = 1.0;

        #if defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) || defined(_MAIN_LIGHT_SHADOWS_SCREEN)
            shadowAttenuation = mainLight.shadowAttenuation;
        #endif

        // Add bias to light direction; BLD - Biased Light Direction
        float3 defaultLightDirection = normalize(UNITY_MATRIX_V[2].xyz + UNITY_MATRIX_V[1].xyz);
        float3 defaultLightColor = saturate(max(half3(0.05, 0.05, 0.05) * _UnlitIntensity, max(ShadeSH9(half4(0.0, 0.0, 0.0, 1.0)), ShadeSH9(half4(0.0, -1.0, 0.0, 1.0)).rgb) * _UnlitIntensity));
        float3 customLightDirection = normalize(mul(unity_ObjectToWorld, float4(((float3(1.0, 0.0, 0.0) * _OffsetXAxisBLD * 10) + (float3(0.0, 1.0, 0.0) * _OffsetYAxisBLD * 10) + (float3(0.0, 0.0, -1.0) * lerp(-1.0, 1.0, _InverseZAxisBLD))), 0)).xyz);
        float3 lightDirection = normalize(lerp(defaultLightDirection, mainLight.direction.xyz, any(mainLight.direction.xyz)));
        lightDirection = lerp(lightDirection, customLightDirection, _IsBLD);

        half3 originalLightColor = mainLightColor.rgb;
        float3 lightColor = lerp(max(defaultLightColor, originalLightColor), max(defaultLightColor, saturate(originalLightColor)), _IsFilterLightColor);

        float3 halfDirection = normalize(viewDirection + lightDirection); // half vector
        
        _Color = _BaseColor;

        #ifdef _IS_PASS_FWDBASE
            float3 baseColor = lerp((mainTexColor.rgb * _BaseColor.rgb), ((mainTexColor.rgb * _BaseColor.rgb)* lightColor), _BlendLightColorAndBaseColor);

            float4 firstShadowColor = lerp(SAMPLE_TEXTURE2D(_FirstShadowTex, sampler_MainTex, TRANSFORM_TEX(uv, _FirstShadowTex)), mainTexColor, _UseBaseTexAsFirstShadowTex);        
            float3 blendFirstShadowColorWithLightColor = lerp( (firstShadowColor.rgb * _FirstShadowTexColor.rgb), ((firstShadowColor.rgb * _FirstShadowTexColor.rgb) * lightColor), _BlendFirstShadowAndLightColor);
            
            float4 secondShadowColor = lerp(SAMPLE_TEXTURE2D(_SecondShadowTex, sampler_MainTex, TRANSFORM_TEX(uv, _SecondShadowTex)), firstShadowColor, _UseFirstShadowTexAsSecondShadowTex);
            float3 blendSecondShadowColorWithLightColor = lerp((secondShadowColor * _SecondShadowTexColor.rgb), ((secondShadowColor * _SecondShadowTexColor.rgb) * lightColor), _BlendSecondShadowAndLightColor);
            // Removed perturded normal
            float halfLambert = 0.5 * dot(lerp(localNormal, normalDirection, _UseNormalMapOverBase), lightDirection) + 0.5;

            float4 firstShadowPosition = tex2D(_FirstShadowPositionTex, TRANSFORM_TEX(uv, _FirstShadowPositionTex));
            float4 secondShadowPosition = tex2D(_SecondShadowPositionTex, TRANSFORM_TEX(uv, _SecondShadowPositionTex));
            
            float systemShadowLevel = shadowAttenuation * 0.5 + 0.5 + _TweakSystemShadowsLevel > 0.001 ? shadowAttenuation * 0.5 + 0.5 + _TweakSystemShadowsLevel : 0.0001;
            
            float finalShadowMask = saturate((1.0 + ((lerp(halfLambert, halfLambert * saturate(systemShadowLevel), _SetSystemShadowsToBase) - (_BaseColorStep - _BaseShadeFeather)) * ((1.0 - firstShadowPosition.rgb).r - 1.0)) / (_BaseColorStep - (_BaseColorStep - _BaseShadeFeather))));

            float3 finalBaseColor = lerp(baseColor, lerp(blendFirstShadowColorWithLightColor, blendSecondShadowColorWithLightColor, saturate((1.0 + ((halfLambert - (_ShadeColorStep - _FirstAndSecondShadesFeather)) * ((1.0 - secondShadowPosition.rgb).r - 1.0)) / (_ShadeColorStep - _FirstAndSecondShadesFeather)))), finalShadowMask);

            float4 highLightMask = tex2D(_HighlightMaskTex, TRANSFORM_TEX(uv, _HighlightMaskTex));
            float specular = 0.5 * dot(halfDirection, lerp(localNormal, normalDirection, _SetNormalMapToHighlight)) + 0.5; // Specular
            float tweakHighlightMask = (saturate((highLightMask.g + _TweakHighlightMaskLevel)) * lerp( (1.0 - step(specular, (1.0 - pow(abs(_HighlightPower), 5)))), pow(abs(specular), exp2(lerp(11, 1, _HighlightPower))), _SetSpecularColorToHighlightColor));

            float4 highlightColor = tex2D(_HighlightTex, TRANSFORM_TEX(uv, _HighlightTex));

            float3 highlight = (lerp((highlightColor.rgb * _HighlightColor.rgb), ((highlightColor.rgb * _HighlightColor.rgb) * lightColor), _SetLightColorToHighlightColor ) * tweakHighlightMask);
            highlight = (lerp(SATURATE_IF_SDR((finalBaseColor - tweakHighlightMask)), finalBaseColor, lerp(_IsBlendAddToHighlighColor, 1.0, _SetSpecularColorToHighlightColor)) + lerp(highlight, (highlight * ((1.0 - finalShadowMask) + (finalShadowMask * _TweakHighlightOnShadow))), _IsUseTweakHighlightColorOnShadow));
        
            float4 rimLightMask = tex2D(_RimLightMaskTex, TRANSFORM_TEX(uv, _RimLightMaskTex));
        
            float3 rimLightColor = lerp( _RimLightColor.rgb, (_RimLightColor.rgb * lightColor), _BlendLightColorToRimLightColor );
            float rimArea = abs(1.0 - dot(lerp(localNormal, normalDirection, _SetNormalMapToRimLight), viewDirection));
            float rimLightPower = pow(rimArea, exp2(lerp(3,0,_RimLightPower)));
            float rimLightInsideMask = saturate(lerp((0.0 + ((rimLightPower - _RimLightInsideMask) * (1.0 - 0.0) ) / (1.0 - _RimLightInsideMask)), step(_RimLightInsideMask, rimLightPower), _RimLightFeatherOff));
            float halfLambertObj = 0.5*dot(i.normalDir, lightDirection) + 0.5;
            float3 lightDirectionMaskOn = lerp((rimLightColor * rimLightInsideMask), (rimLightColor * saturate((rimLightInsideMask-((1.0 - halfLambertObj) + _TweakLightDirectionMaskLevel)))), _LightDirectionMaskOn);
            // AP means Antipodean, opposite side of a globe
            float apRimLightPower = pow(rimArea, exp2(lerp(3,0, _ApRimLightPower)));
            float3 rimLight = (SATURATE_IF_SDR((rimLightMask.g + _TweakRimLightMaskLevel))*lerp( lightDirectionMaskOn, (lightDirectionMaskOn + (lerp( _ApRimLightColor.rgb, (_ApRimLightColor.rgb * lightColor), _SetLightColorToApRimLightColor) * saturate((lerp((0.0 + ((apRimLightPower - _RimLightInsideMask) * (1.0 - 0.0)) / (1.0 - _RimLightInsideMask)), step(_RimLightInsideMask, apRimLightPower), _ApRimLightFeatherOff) - (saturate(halfLambertObj) + _TweakLightDirectionMaskLevel))))), _AddAntipodeanRimLight));
            // Composite rim light with highlight
            float3 rimSpecular = lerp(highlight, (highlight + rimLight), _RimLight);

            half mirrorFlag = i.mirrorFlag;

            // MatCap(Matrix Caption) is a technique that allows you to capture the lighting environment in a texture and then use it to light objects.
            float3 cameraRight = UNITY_MATRIX_V[0].xyz;
            float3 cameraFront = UNITY_MATRIX_V[2].xyz;
            float3 upVector = float3(0, 1, 0);
            float3 rightAxis = cross(cameraFront, upVector);
            // Invert UV if it's "inside the mirror".
            if (mirrorFlag < 0)
            {
                rightAxis = -1 * rightAxis;
                _RotateMatCapUV = -1 * _RotateMatCapUV;
            }
            else
            {
                rightAxis = rightAxis;
            }

            float cameraRightMagnitude = sqrt(cameraRight.x * cameraRight.x + cameraRight.y * cameraRight.y + cameraRight.z * cameraRight.z);
            float rightAxisMagnitude = sqrt(rightAxis.x * rightAxis.x + rightAxis.y * rightAxis.y + rightAxis.z * rightAxis.z);
            float cameraRollCos = dot(rightAxis, cameraRight) / (rightAxisMagnitude * cameraRightMagnitude);
            float cameraRollAngle = acos(clamp(cameraRollCos, -1, 1));
            half cameraDir = cameraRight.y < 0 ? -1 : 1;

            float rotMatCapUVAngle = (_RotateMatCapUV * 3.141592654) - cameraDir * cameraRollAngle * _CameraRollingStabilizer;

            float2 rotatedMatCapNormalMapUV = RotateUV(uv, (_RotateNormalMapForMatCapUV * 3.141592654), float2(0.5, 0.5), 1.0);

            float3 normalMapForMatCap = UnpackNormalScale(tex2D(_NormalMapForMatCapTex, TRANSFORM_TEX(rotatedMatCapNormalMapUV, _NormalMapForMatCapTex)), _BumpScaleMatCap);

            // MatCap with camera skew correction; skew means distort.
            float3 viewNormal = (mul(UNITY_MATRIX_V, float4(lerp(i.normalDir, mul(normalMapForMatCap.rgb, tangentTransform).rgb, _UseNormalMapForMatCap), 0))).rgb;
            float3 normalBlendMatCapUVDetail = viewNormal.rgb * float3(-1, -1, 1);
            float3 normalBlendMatCapUVBase = (mul(UNITY_MATRIX_V, float4(viewDirection, 0)).rgb * float3(-1, -1, 1)) + float3(0, 0, 1);
            float3 noSkewViewNormal = normalBlendMatCapUVBase * dot(normalBlendMatCapUVBase, normalBlendMatCapUVDetail) / normalBlendMatCapUVBase.b - normalBlendMatCapUVDetail;
            float2 viewNormalAsMatCapUV = (lerp(noSkewViewNormal, viewNormal, _IsOrtho).rg * 0.5) + 0.5;
            float2 rotMatCapUV = RotateUV((0.0 + ((viewNormalAsMatCapUV - (0.0 + _TweakMatCapUV)) * (1.0 - 0.0)) / ((1.0 - _TweakMatCapUV) - (0.0 + _TweakMatCapUV))), rotMatCapUVAngle, float2(0.5, 0.5), 1.0);

            // If it is "inside the mirror", flip the UV left and right.
            if (mirrorFlag < 0)
            {
                rotMatCapUV.x = 1 - rotMatCapUV.x;
            }
            else
            {
                rotMatCapUV = rotMatCapUV;
            }

            float4 matCapSamplerVal = tex2Dlod(_MatCapTex, float4(TRANSFORM_TEX(rotMatCapUV, _MatCapTex), 0.0, _BlurLevelMatCap));
            float4 matCapMaskVal = tex2D(_MatCapMaskTex, TRANSFORM_TEX(uv, _MatCapMaskTex));

            // MatCapMask
            float tweakMatCapMaskLevel = saturate(lerp(matCapMaskVal.g, (1.0 - matCapMaskVal.g), _InverseMatCapMask) + _TweakMatCapMaskLevel);
            float3 lightColorMatCap = lerp((matCapSamplerVal.rgb * _MatCapColor.rgb), ((matCapSamplerVal.rgb * _MatCapColor.rgb) * lightColor), _IsLightColorMatCap);
            // ShadowMask on MatCap in Blend mode : multiply
            float3 matCap = lerp(lightColorMatCap, (lightColorMatCap * ((1.0 - finalShadowMask) + (finalShadowMask * _TweakMatCapOnShadow)) + lerp(highlight * finalShadowMask * (1.0 - _TweakMatCapOnShadow), float3(0.0, 0.0, 0.0), _IsBlendAddToMatCap)), _IsUseTweakMatCapOnShadow);

            // Composition: RimLight and MatCap as finalColor
            // Broke down finalColor composition
            float3 matCapColorOnAddMode = rimSpecular + matCap * tweakMatCapMaskLevel;
            float tweakMatCapMaskLevelMultiplyMode = tweakMatCapMaskLevel * lerp(1, (1 - (finalShadowMask) * (1 - _TweakMatCapOnShadow)), _IsUseTweakMatCapOnShadow);
            float3 matCapColorOnMultiplyMode = highlight * (1 - tweakMatCapMaskLevelMultiplyMode) + highlight * matCap * tweakMatCapMaskLevelMultiplyMode + lerp(float3(0, 0, 0), rimLight, _RimLight);
            float3 matCapColorFinal = lerp(matCapColorOnMultiplyMode, matCapColorOnAddMode, _IsBlendAddToMatCap);
            #ifdef _DISABLE_ANGELRING
                float3 finalColor = lerp(rimSpecular, matCapColorFinal, _MatCap); // Final Composition before Emissive
            #elif _ENABLE_ANGELRING
                float3 finalColor = lerp(rimSpecular, matCapColorFinal, _MatCap); // Final Composition before Emissive
                float3 angelRingOffsetU = lerp(mul(UNITY_MATRIX_V, float4(i.normalDir, 0)).xyz, float3(0, 0, 1), _AngelRingOffsetU);
                float2 angelRingVN = angelRingOffsetU.xy * 0.5 + float2(0.5, 0.5);
                float2 angelRingVNRotate = RotateUV(angelRingVN, -(cameraDir * cameraRollAngle), float2(0.5, 0.5), 1.0);
                float2 angelRingOffsetV = float2(angelRingVNRotate.x, lerp(i.uv1.y, angelRingVNRotate.y, _AngelRingOffsetV));
                float4 angelRingVal = tex2D(_AngelRingTex, TRANSFORM_TEX(angelRingOffsetV, _AngelRingTex));
                float3 angleRingColor = lerp((angelRingVal.rgb * _AngelRingColor.rgb), ((angelRingVal.rgb * _AngelRingColor.rgb) * lightColor), _UseLightColorAsAngelRingColor);
                float angelRingTexAlpha = angelRingVal.a;
                float3 angelRingWithAlpha = (angleRingColor * angelRingVal.a);
                finalColor = lerp(finalColor, lerp((finalColor + angleRingColor), ((finalColor * (1.0 - angelRingTexAlpha)) + angelRingWithAlpha), _AngelRingSamplerAlphaOn), _AngelRing); // Final Composition before Emissive
            #endif

            #ifdef _EMISSIVE_SIMPLE
                float4 emissiveColor = tex2D(_EmissiveTex,TRANSFORM_TEX(uv, _EmissiveTex));
                float emissiveMask = emissiveColor.a;
                emissive = emissiveColor.rgb * _EmissiveColor.rgb * emissiveMask;
            #elif _EMISSIVE_ANIMATION
                // Calculation View Coord UV for Scroll
                float3 viewNormalEmissive = (mul(UNITY_MATRIX_V, float4(i.normalDir, 0))).xyz;
                float3 normalBlendEmissiveDetail = viewNormalEmissive * float3(-1, -1, 1);
                float3 normalBlendEmissiveBase = (mul(UNITY_MATRIX_V, float4(viewDirection, 0)).xyz * float3(-1, -1, 1)) + float3(0, 0, 1);
                float3 noSknewViewNormalEmissive = normalBlendEmissiveBase * dot(normalBlendEmissiveBase, normalBlendEmissiveDetail) / normalBlendEmissiveBase.z - normalBlendEmissiveDetail;
                float2 viewNormalAsEmissiveUV = noSknewViewNormalEmissive.xy * 0.5 + 0.5;
                float2 viewCoordUV = RotateUV(viewNormalAsEmissiveUV, -(cameraDir * cameraRollAngle), float2(0.5, 0.5), 1.0);

                if (mirrorFlag < 0)
                {
                    viewCoordUV.x = 1 - viewCoordUV.x;
                }
                else
                {
                    viewCoordUV = viewCoordUV;
                }

                float2 emissiveUV = lerp(i.uv0, viewCoordUV, _IsViewCoordScroll);
                float4 time = _Time;
                float baseSpeed = (time.g * _BaseSpeed);
                float isPingPongBase = lerp(baseSpeed, sin(baseSpeed), _IsPingPongBase);
                float2 scrolledUV = emissiveUV + float2(_ScrollEmissiveU, _ScrollEmissiveV) * isPingPongBase;
                float rotateVelocity = _RotateEmissiveUV * 3.141592654;
                float2 rotateEmissiveUV = RotateUV(scrolledUV, rotateVelocity, float2(0.5, 0.5), isPingPongBase);
                
                float4 emissiveTex = tex2D(_EmissiveTex, TRANSFORM_TEX(uv, _EmissiveTex));
                float emissiveMask = emissiveTex.a;

                emissiveTex = tex2D(_EmissiveTex, TRANSFORM_TEX(rotateEmissiveUV, _EmissiveTex));
                float colorShiftSpeed = 1.0 - cos(time.g * _ColorShiftSpeed);
                float viewShift = smoothstep(0.0, 1.0, max(0, dot(normalDirection, viewDirection)));
                float4 colorShiftColor = lerp(_EmissiveColor, lerp(_EmissiveColor, _ColorShift, colorShiftSpeed), _IsColorShift);
                float4 viewShiftColor = lerp(_ViewShift, colorShiftColor, viewShift);
                float4 emissiveColor = lerp(colorShiftColor, viewShiftColor, _IsViewShift);
                
                emissive = emissiveColor.rgb * emissiveTex.rgb * emissiveMask;
            #endif

            float3 envLightColor = envColor.rgb;

            float envLightIntensity = 0.299*envLightColor.r + 0.587*envLightColor.g + 0.114*envLightColor.b <1 ? (0.299*envLightColor.r + 0.587*envLightColor.g + 0.114*envLightColor.b) : 1;

            float3 pointLightColor = 0;
            #ifdef _ADDITIONAL_LIGHTS
                int pixelLightCount = GetAdditionalLightsCount();
                // Determine main light inorder to apply light culling properly
                // when the loop counter start from negative value, MAINLIGHT_IS_MAINLIGHT = -1, some compiler doesn't work well.
                for(int loopCount = 0; loopCount < pixelLightCount - MAINLIGHT_IS_MAINLIGHT; loopCount++)
                {
                    int iLight = loopCount + MAINLIGHT_IS_MAINLIGHT;
                    if (iLight != i.mainLightID)
                    {
                        float notDirectional = 1.0f; //_WorldSpaceLightPos0.w of the legacy code.
                        ToonLight additionalLight = GetToonMainLight(0,0);
                        if (iLight != MAINLIGHT_IS_MAINLIGHT)
                        {
                            additionalLight = GetAdditionalToonLight(iLight, inputData.positionWS, i.positionCS);
                        }
                        half3 additionalLightColor = GetLightColor(additionalLight);

                        float3 lightDirection = additionalLight.direction;
                        float3 addPassLightColor = (0.5*dot(lerp(i.normalDir, normalDirection, _UseNormalMapOverBase), lightDirection) + 0.5) * additionalLightColor.rgb;
                        float  pureIntensity = max(0.001, (0.299 * additionalLightColor.r + 0.587 * additionalLightColor.g + 0.114 * additionalLightColor.b));
                        float3 lightColor = max(0, lerp(addPassLightColor, lerp(0, min(addPassLightColor, addPassLightColor / pureIntensity), notDirectional), _IsFilterLightColor));
                        float3 halfDirection = normalize(viewDirection + lightDirection); // has to be recalced here.

                        _BaseColorStep = saturate(_BaseColorStep + _StepOffset);
                        _ShadeColorStep = saturate(_ShadeColorStep + _StepOffset);

                        // If Added lights is directional, set 0 as lightIntensity
                        float lightIntensity = lerp(0, (0.299 * additionalLightColor.r + 0.587 * additionalLightColor.g + 0.114 * additionalLightColor.b), notDirectional);

                        lightColor = lerp(lightColor, lerp(lightColor, min(lightColor, additionalLightColor.rgb * _BaseColorStep), notDirectional), _IsFilterHiCutPointLightColor);

                        float3 baseColor = lerp((_BaseColor.rgb * mainTexColor.rgb * lightIntensity), ((_BaseColor.rgb * mainTexColor.rgb) * lightColor), _BlendLightColorAndBaseColor);

                        float4 firstShadowTexVal = lerp(SAMPLE_TEXTURE2D(_FirstShadowTex, sampler_MainTex,TRANSFORM_TEX(uv, _FirstShadowTex)), mainTexColor, _UseBaseTexAsFirstShadowTex);

                        float3 firstShadowColor = lerp((_FirstShadowTexColor.rgb * firstShadowTexVal.rgb * lightIntensity), ((_FirstShadowTexColor.rgb * firstShadowTexVal.rgb) * lightColor), _BlendFirstShadowAndLightColor);

                        float4 secondShadowTexVal = lerp(SAMPLE_TEXTURE2D(_SecondShadowTex, sampler_MainTex, TRANSFORM_TEX(uv, _SecondShadowTex)), firstShadowTexVal, _UseFirstShadowTexAsSecondShadowTex);

                        float3 secondShadowColor = lerp((_SecondShadowTexColor.rgb * secondShadowTexVal.rgb * lightIntensity), ((_SecondShadowTexColor.rgb * secondShadowTexVal.rgb) * lightColor), _BlendSecondShadowAndLightColor);

                        float halfLambert = 0.5 * dot(lerp(i.normalDir, normalDirection, _UseNormalMapOverBase), lightDirection) + 0.5;

                        float4 firstShadowPosition = tex2D(_FirstShadowPositionTex, TRANSFORM_TEX(uv, _FirstShadowPositionTex));
                        float4 secondShadowPosition = tex2D(_SecondShadowPositionTex, TRANSFORM_TEX(uv, _SecondShadowPositionTex));
                        
                        float finalShadowMask = saturate((1.0 + ((lerp(halfLambert, (halfLambert * saturate(1.0 + _TweakSystemShadowsLevel)), _SetSystemShadowsToBase) - (_BaseColorStep - _BaseShadeFeather)) * ((1.0 - firstShadowPosition.rgb).r - 1.0)) / (_BaseColorStep - (_BaseColorStep - _BaseShadeFeather))));
                        
                        float3 finalColor = lerp(baseColor, lerp(firstShadowColor, lerp(secondShadowColor, secondShadowColor, saturate(1.0 + ((halfLambert - (_ShadeColorStep - _FirstAndSecondShadesFeather)) * ((1.0 - secondShadowPosition.rgb).r - 1.0)) / (_ShadeColorStep - (_ShadeColorStep - _FirstAndSecondShadesFeather)))), finalShadowMask), finalShadowMask);

                        float4 highLightMask = tex2D(_HighlightMaskTex, TRANSFORM_TEX(uv, _HighlightMaskTex));

                        float specular = 0.5 * dot(halfDirection, lerp(i.normalDir, normalDirection, _SetNormalMapToHighlight)) + 0.5; // Specular

                        float tweakHighlightMask = saturate((highLightMask.g + _TweakHighlightMaskLevel) * lerp((1.0 - step(specular, (1.0 - step(abs(_HighlightPower), 5)))), pow(abs(specular), exp2(lerp(11, 1, _HighlightPower))), _SetSpecularColorToHighlightColor));

                        float4 highlightColor = tex2D(_HighlightTex, TRANSFORM_TEX(uv, _HighlightTex));

                        float3 highlight = (lerp((highlightColor.rgb * _HighlightColor.rgb), ((highlightColor.rgb * _HighlightColor.rgb) * lightColor), _SetLightColorToHighlightColor) * tweakHighlightMask);

                        finalColor = finalColor + lerp(lerp(highlight, (highlight * ((1.0 - finalShadowMask) + (finalShadowMask * _TweakHighlightOnShadow))), _IsUseTweakHighlightColorOnShadow), float3(0, 0, 0), _IsFilterHiCutPointLightColor);
                        
                        // finalColor = SATURATE_IF_SDR(finalColor);
                        pointLightColor += finalColor;
                    }   
                }
            #endif
            finalColor += pointLightColor;
        #endif
        finalColor = SATURATE_IF_SDR(finalColor) + (envLightColor*envLightIntensity * _GIIntensity * smoothstep(1, 0, envLightIntensity/2)) + emissive;
        finalColor = envLightColor;
        return half4(finalColor, 1.0);

        // return half4(finalColor, 1.0);     
    }
#endif