Shader "Unlit/MyToonShader"
{
    Properties
    {
        // Clipping
        [Header(Clipping Attributes)]
        [KeywordEnum(DISABLE, ENABLE_STDMODE, ENABLE_TRANSMODE)] _CLIPPING ("Use Clipping", Float) = 0
        _ClippingMask("ClippingMask", 2D) = "white" {}
        [Toggle(_)] _InverseClipping("Inverse Clipping", Float) = 0
        _ClippingLevel("Clipping Level", Range(0, 1)) = 0
        _TweakTransparency("Tweak_transparency", Range(-1, 1)) = 0
        [HideInInspector] _UseBaseMapAlphaAsClippingMask("IsBaseMapAlphaAsClippingMask", Float) = 0
        
        // Main Textures
        [Space(10)]
        [Header(Main Texture Attributes)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        [Toggle(_)] _BlendLightColorAndBaseColor("Blend Light Color And Base Color", Float) = 0
        [HideInInspector] _Color ("Color", Color) = (1,1,1,1)
        [HideInInspector] _BaseMap ("BaseMap", 2D) = "white" {}
        
        // Normal Attributes
        [Space(10)]
        [Header(Custom Normal Attributes)]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Range(0, 1)) = 1
        [Toggle(_)] _UseNormalMapOverBase ("Use Normal Map Over Base", Float ) = 0
        
        // First Shadow Textures
        [Space(10)]
        [Header(First Shadow Texture Attributes)]
        _FirstShadowTex("First Shadow Texture", 2D) = "white" {}
        [Toggle(_)] _UseBaseTexAsFirstShadowTex("Use Base Texture As First Shadow Texture", Float) = 1
        _FirstShadowTexColor("First Shadow Color", Color) = (1,1,1,1)
        [Toggle(_)] _BlendFirstShadowAndLightColor("Blend First Shadow Texture And Light Color", Float) = 0
        // Second Shadow Textures
        [Space(10)]
        [Header(Second Shadow Texture Attributes)]
        _SecondShadowTex("Second Shadow Texture", 2D) = "white" {}
        [Toggle(_)] _UseFirstShadowTexAsSecondShadowTex("Use First Shadow Texture As Second Shadow Texture", Float) = 1
        _SecondShadowTexColor("Second Shadow Color", Color) = (1,1,1,1)
        [Toggle(_)] _BlendSecondShadowAndLightColor("Blend Second Shadow Texture And Light Color", Float) = 0
        
        // Shadow Attributes
        [Space(10)]
        [Header(Overall Shadow Attributes)]
        [Toggle(_)] _SetSystemShadowsToBase ("Set System Shadows To Base", Float ) = 1
        _TweakSystemShadowsLevel ("Tweak System Shadows Level", Range(-0.5, 0.5)) = 0
        _BaseColorStep ("Base Color Step", Range(0, 1)) = 0.5
        _BaseShadeFeather ("Base/Shade Feather", Range(0.0001, 1)) = 0.0001
        _ShadeColorStep ("Shade Color Step", Range(0, 1)) = 0
        _FirstAndSecondShadesFeather ("1st/2nd Shades Feather", Range(0.0001, 1)) = 0.0001
        [HideInInspector] _FirstShadowColorStep("First Shadow Color Step", Range(0, 1)) = 0.5
        [HideInInspector] _FirstShadowColorFeather("First Shadow Color Feather", Range(0.0001, 1)) = 0.0001
        [HideInInspector] _SecondShadowColorStep("Second Shadow Color Step", Range(0, 1)) = 0
        [HideInInspector] _SecondShadowColorFeather("Second Shadow Color Feather", Range(0.0001, 1)) = 0.0001
        
        _StepOffset ("Step Offset (ForwardAdd Only)", Range(-0.5, 0.5)) = 0
        [Toggle(_)] _IsFilterHiCutPointLightColor ("PointLights HiCut_Filter (ForwardAdd Only)", Float ) = 1
        _FirstShadowPositionTex ("First Shade Position", 2D) = "white" {}
        _SecondShadowPositionTex ("Second Shade Position", 2D) = "white" {}
        
        // GrediantMap
        [Space(10)]
        [Header(Grediant Attributes)]
        _GrediantMap("GrediantMap", 2D) = "white" {}

        _TweakShadingGradeMapLevel("Tweak Shading Grade MapLevel", Range(-0.5, 0.5)) = 0
        _BlurLevelSGM("Blur Level of ShadingGradeMap", Range(0, 10)) = 0

        [Space(10)]
        [Header(Highlight Attributes)]
        // Specular Setting
        _HighlightColor("Highlight Color", Color) = (0,0,0,1)
        _HighlightTex("Highlight Color Texture", 2D) = "white" {}
        [Toggle(_)] _SetLightColorToHighlightColor("Set HighlightColor To LightColor", Float) = 1
        [Toggle(_)] _SetNormalMapToHighlight ("Set NormalMap To HighColor", Float ) = 0
        _HighlightPower ("Highlight Power", Range(0, 1)) = 0
        [Toggle(_)] _SetSpecularColorToHighlightColor("Set SpecularColor To HighlightColor", Float) = 1
        [Toggle(_)] _IsBlendAddToHighlighColor ("Is Blend Add To Highligh Color", Float ) = 0
        [Toggle(_)] _IsUseTweakHighlightColorOnShadow ("Is Use Tweak Highlight Color On Shadow", Float ) = 0
        _TweakHighlightOnShadow ("Tweak Highlight On Shadow", Range(0, 1)) = 0
        // Highlight Mask Texture
        _HighlightMaskTex ("Highlight Mask Texture", 2D) = "white" {}
        _TweakHighlightMaskLevel ("Tweak Highlight Mask Level", Range(-1, 1)) = 0

        // Rim Light Setting
        [Space(10)]
        [Header(RimLight Attributes)]
        [Toggle(_)] _RimLight ("RimLight", Float ) = 0
        _RimLightColor ("Rim Light Color", Color) = (1,1,1,1)
        [Toggle(_)] _BlendLightColorToRimLightColor("Blend Light Color To Rim Light Color", Float) = 1
        [Toggle(_)] _SetNormalMapToRimLight("Set NormalMap To RimLight", Float) = 0
        _RimLightPower ("Rim Light Power", Range(0, 1)) = 0.1
        _RimLightInsideMask ("Rim Light Inside Mask", Range(0.0001, 1)) = 0.0001
        [Toggle(_)] _RimLightFeatherOff ("Rim Light Feather Off", Float ) = 0
        [Toggle(_)] _LightDirectionMaskOn ("Light Direction Mask On", Float ) = 0
        _TweakLightDirectionMaskLevel ("Tweak Light Direction Mask Level", Range(0, 0.5)) = 0
        // Antipodean Rim Light Setting
        [Toggle(_)] _AddAntipodeanRimLight ("Add Antipodean RimLight", Float) = 0
        _ApRimLightColor ("Antipodean Rim Light Color", Color) = (1,1,1,1)
        [Toggle(_)] _SetLightColorToApRimLightColor ("Set Light Color To Antipodean RimLight Color", Float ) = 1
        _ApRimLightPower ("Antipodean Rim Light Power", Range(0, 1)) = 0.1
        [Toggle(_)] _ApRimLightFeatherOff ("Antipodean Rim Light Feather Off", Float ) = 0
        //RimLightMask Texture
        _RimLightMaskTex("Rim Light Mask Texture", 2D) = "white" {}
        _TweakRimLightMaskLevel ("Tweak Rim Light Mask Level", Range(-1, 1)) = 0
        
        
        // MatCap Setting
        [Space(10)]
        [Header(Matrix Caption Attributes)]
        [Toggle(_)] _MatCap ("MatCap", Float ) = 0
        _MatCapTex ("MatCap Texture", 2D) = "black" {}
        _BlurLevelMatCap ("Blur Level of MatCap Texture", Range(0, 10)) = 0
        _MatCapColor ("MatCapColor", Color) = (1,1,1,1)
        [Toggle(_)] _IsLightColor_MatCap ("Is LightColor MatCap", Float ) = 1
        [Toggle(_)] _IsBlendAddToMatCap ("Is Blend Add To MatCap", Float ) = 1
        _TweakMatCapUV ("Tweak MatCapUV", Range(-0.5, 0.5)) = 0
        _RotateMatCapUV ("Rotate MatCapUV", Range(-1, 1)) = 0
        [Toggle(_)] _CameraRollingStabilizer ("Activate CameraRolling Stabilizer", Float ) = 0
        [Toggle(_)] _UseNormalMapForMatCap ("Use NormalMap For MatCap", Float ) = 0
        _NormalMapForMatCapTex ("Normal Map For MatCap", 2D) = "bump" {}
        _BumpScaleMatCap ("Scale for Normal Map for MatCap", Range(0, 1)) = 1
        _RotateNormalMapForMatCapUV ("Rotate_NormalMapForMatCapUV", Range(-1, 1)) = 0
        [Toggle(_)] _IsUseTweakMatCapOnShadow ("Is Use Tweak MatCap On Shadow", Float ) = 0
        _TweakMatCapOnShadow ("Tweak MatCap On Shadow", Range(0, 1)) = 0
        _MatCapMaskTex ("Set MatCap Mask", 2D) = "white" {}
        _TweakMatCapMaskLevel ("Tweak MatCap Mask Level", Range(-1, 1)) = 0
        [Toggle(_)] _InverseMatcapMask ("Inverse MatcapMask", Float ) = 0
        [Toggle(_)] _IsOrtho ("Orthographic Projection for MatCap", Float ) = 0
 
        // Angel Ring Setting
        [Space(10)]
        [Header(Angel Ring Attributes)]
        [Toggle(_)] _AngelRing("Angel Ring", Float) = 0
        _AngelRingTex("Angel Ring Texture", 2D) = "black" {}
        _AngelRingColor("Angel Ring Color", Color) = (1,1,1,1)
        [Toggle(_)] _UseLightColorAsAngelRingColor("Use Light Color As Angel Ring Color", Float) = 1
        _AngelRingOffsetU("Angel Ring Offset U", Range(0, 0.5)) = 0
        _AngelRingOffsetV("Angel Ring Offset V", Range(0, 1)) = 0.3
        [Toggle(_)] _AngelRinSamplerAlphaOn("Angel Ring Sampler Alpha On", Float) = 0

        // Emissive Setting
        [Space(10)]
        [Header(Emissive Attributes)]
        [KeywordEnum(SIMPLE,ANIMATION)] _EMISSIVE("EMISSIVE MODE", Float) = 0
        _EmissiveTex ("Emissive Texture", 2D) = "white" {}
        [HDR]_EmissiveColor ("Emissive Color", Color) = (0,0,0,1)
        _BaseSpeed ("Base Speed", Float ) = 0
        _ScrollEmissiveU ("Scroll Emissive U", Range(-1, 1)) = 0
        _ScrollEmissiveV ("Scroll Emissive V", Range(-1, 1)) = 0
        _RotateEmissiveUV ("Rotate Emissive UV", Float ) = 0
        [Toggle(_)] _IsPingPongBase ("Is Ping Pong Base", Float ) = 0
        [HDR]_ColorShift ("Color Sift", Color) = (0,0,0,1)
        _ColorShiftSpeed ("Color Shift Speed", Float ) = 0
        [Toggle(_)] _IsViewShift ("Activate View Shift", Float ) = 0
        [HDR]_ViewShift ("View Sift", Color) = (0,0,0,1)
        [Toggle(_)] _IsViewCoordScroll ("Is View Coord Scroll", Float ) = 0
        
        // Outline Attributes
        [Space(10)]
        [Header(Outline Attributes)]
        [KeywordEnum(NML, POS)] _OUTLINE ("Outline Mode", Float) = 0
        [KeywordEnum(DISABLE, ENABLE)] _OUTLINE_CLIPPING ("Outline Clipping", Float) = 0
        [Enum(OFF,0, ON,1)]	_ZOverDrawMode("ZOver Draw Mode", Float) = 0  //OFF/ON
        _OutlineThickness ("Outline Thickness", Float) = 0
        _FarthestDistance ("Farthest Distance", Float ) = 100
        _NearestDistance ("Nearest Distance", Float ) = 0.5
        _OutlineColor ("Outline Color", Color) = (0.5,0.5,0.5,1)
        [Toggle(_)] _UseOutlineTex ("Use Outline Texture", Float ) = 0
        _OutlineTex ("Outline Texture", 2D) = "white" {}
        _Offset_Z ("Offset Camera Z", Float) = 0
        [Toggle(_)] _UseBakedNormal ("Use Baked Normal", Float ) = 0
        _BakedNormalTex ("Baked Normal for Outline", 2D) = "white" {}
        [Toggle(_)] _IsBlendBaseColor ("Use_BlendBaseColor", Float ) = 0
        [Toggle(_)] _IsLightColorOutline ("Use LightColor Outline", Float ) = 1
        [HideInInspector] _Cutoff("Alpha cutoff", Range(0, 1)) = 0.5
        
        // GI Attributes
        [Space(10)]
        [Header(Global Illumination Attributes)]
        _GIIntensity ("Global Illumination Intensity", Range(0, 100)) = 0
        _UnlitIntensity ("Unlit Intensity", Range(0.001, 4)) = 1
        // [Toggle(_)] _IsFilterLightColor ("VRChat : SceneLights HiCut_Filter", Float ) = 0
        [HideInInspector][Toggle(_)] _IsFilterLightColor ("VRChat : SceneLights HiCut_Filter", Float ) = 0
        //Built-in Light Direction
        [HideInInspector][Toggle(_)] _IsBLD ("Advanced : Activate Built-in Light Direction", Float ) = 0
        [HideInInspector]_OffsetXAxisBLD (" Offset X-Axis (Built-in Light Direction)", Range(-1, 1)) = -0.05
        [HideInInspector]_OffsetYAxisBLD (" Offset Y-Axis (Built-in Light Direction)", Range(-1, 1)) = 0.09
        [HideInInspector][Toggle(_)] _InverseZAxisBLD (" Inverse Z-Axis (Built-in Light Direction)", Float ) = 1
    
        [HideInInspector] _Metallic("Metallic", Range(0.0, 1.0)) = 0
        [HideInInspector] _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _SpecColor("Specular Color", Color) = (1, 1, 1, 1)

    }
    SubShader
    {
        Tags{"RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}

        Pass
        {
            Name "Outline"
            Tags {"LightMode" = "SRPDefaultUnlit"}
            Cull FRONT
            ColorMask RGB
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma target 3.5

            #pragma multi_compile _OUTLINE_CLIPPING_DISABLE _OUTLINE_CLIPPING_ENABLE
            #pragma multi_compile _OUTLINE_NML _OUTLINE_POS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Full Path is "Assets/Shaders/Toon/Includes/xxx.hlsl"
            #include "./Includes/MyToonShaderInput.hlsl"
            #include "./Includes/MyToonShaderUtilities.hlsl"
            #include "./Includes/MyToonShaderOutline.hlsl"

            ENDHLSL
        }
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex vert
            #pragma fragment frag

            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _RECEIVE_SHADOWS_OFF


            // Pipeline Shadow-Related keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ADDITIONAL_LIGHTS _ADDITIONAL_LIGHTS_VERTEX 
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            #pragma multi_compile   _IS_PASS_FWDBASE
            // #pragma multi_compile   _ENVIRONMENTREFLECTIONS_OFF
            
            #pragma shader_feature _ _SHADINGGRADEMAP
            
            // Toon Shader Keywords
            #pragma shader_feature _ENABLE_TRANSCLIPPING _DISABLE_TRANSCLIPPING 
            #pragma shader_feature _DISABLE_ANGELRING _ENABLE_ANGELRING 
            
            #pragma shader_feature _ USE_TOON_RAYTRACING_SHADOW
            #pragma shader_feature _CLIPPING_DISABLE _CLIPPING_ENABLE_STDMODE _CLIPPING_ENABLE_TRANSMODE

            #pragma shader_feature _EMISSIVE_SIMPLE _EMISSIVE_ANIMATION 

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "./Includes/MyToonShaderInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            #include "./Includes/MyToonShaderUtilities.hlsl"
            // #include "./Includes/MyToonShader.hlsl"
            #include "./Includes/MyToonShaderWithFeather.hlsl"

            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "./Includes/MyToonShaderInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

    }
}
