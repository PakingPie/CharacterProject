#ifndef CEL_EYE_UV_UTILITIES_INCLUDED
#define CEL_EYE_UV_UTILITIES_INCLUDED
// Adapted from the user's CompundTest 1/Assets/Shaders/EyeShader/eye.shader,
// RemapUV pupil-dilation construction. Fixes center division and the outer
// interval so radius 0.5 always maps to 0.5. No spherical refraction is assumed.
float2 RemapAnimePupilUV(float2 uv,float pupilRadius,float sourcePupilRadius)
{
    float r=length(uv);
    float2 direction=uv/max(r,1e-6);
    float target=clamp(pupilRadius,0.005,0.49);
    float source=clamp(sourcePupilRadius,0.005,0.49);
    float remapped=r<target?r/target*source:source+(r-target)/max(0.5-target,1e-5)*(0.5-source);
    return direction*remapped;
}
#endif
