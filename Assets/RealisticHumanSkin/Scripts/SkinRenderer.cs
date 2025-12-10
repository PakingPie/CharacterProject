using UnityEngine;

public class FaceworksRenderer : MonoBehaviour
{
    [SerializeField] private MeshFilter _meshFilter;
    [field: SerializeField] public int CurvatureSmoothIterations { get; private set; } = 3;
    [field: SerializeField] public SkinSettings Profile { get; private set; }
    [field: SerializeField] public Renderer Renderer { get; private set; }
    [field: SerializeField] public float MMToUnitMultiplier { get; private set; } = 0.1f;

    public Mesh Mesh { get => _meshFilter.sharedMesh; set => _meshFilter.sharedMesh = value; }
}