using UnityEngine;

[CreateAssetMenu(fileName = "SkinSettings", menuName = "Scriptable Objects/SkinSettings")]
public class SkinSettings : ScriptableObject
{
    [field: SerializeField] public int LutSize { get; private set; }
    [field: SerializeField] public int MonteCarloIterations { get; private set; } = 300;
    [field: SerializeField] public float MaxIntegrationDistanceMM { get; private set; } = 20;
    [field: SerializeField] public float DiffusionRadiusMM { get; private set; } = 2.7f;

    [field: Header("Curvature")]
    [field: SerializeField] public float MinCurvatureRadiusMM { get; private set; } = 1.0f;
    [field: SerializeField] public float MaxCurvatureRadiusMM { get; private set; } = 100.0f;
    [field: SerializeField] public Texture2D CurvatureLUT { get; private set; }

    [field: Header("Shadow")]
    [field: SerializeField] public Texture2D ShadowLUT { get; private set; }
    [field: SerializeField] public float MinShadowWidthMM { get; private set; } = 8f;
    [field: SerializeField] public float MaxShadowWidthMM { get; private set; } = 100.0f;
    [field: SerializeField] public float ShadowSharpening { get; private set; } = 10.0f;
}
