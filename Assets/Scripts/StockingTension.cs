using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Measures how much a skinned stocking mesh is stretched or squashed by the
/// current pose and sends it to the stocking shader every frame.
///
/// HOW IT WORKS
/// ─────────────
/// For every vertex, the surface area of the triangles around it is compared
/// with the same area in the mesh's rest (bind) pose:
///
///     tension = current area / rest area
///
///     above 1  → stretched (front of a bent knee)  → fabric gets sheerer
///     below 1  → squashed  (back of a bent knee)   → fabric gets denser
///
/// The result is divided by the change of the whole mesh's area, so the
/// character's scale and the mesh's units do not matter.
///
/// SETUP
/// ──────
/// 1. Add this component to the stocking object (it needs a
///    SkinnedMeshRenderer).
/// 2. On the material, enable "Live Tension (needs StockingTension)".
/// 3. To check it, enable "Debug View" on the material and bend the knee:
///    the front should turn red and the back blue.
/// </summary>
[ExecuteAlways]
[DisallowMultipleComponent]
[RequireComponent(typeof(SkinnedMeshRenderer))]
public class StockingTension : MonoBehaviour
{
    [Tooltip("Smoothing passes over the measured tension. Higher values hide\n" +
             "the mesh triangles but soften small details.")]
    [Range(0, 6)]
    public int smoothingPasses = 2;

    private static readonly int TensionBufferId = Shader.PropertyToID("_TensionBuffer");

    private SkinnedMeshRenderer skinnedRenderer;
    private Mesh sourceMesh;
    private Mesh bakedMesh;
    private readonly List<Vector3> bakedVertices = new List<Vector3>();

    private int vertexCount;
    private int[] triangles;

    // Vertices at the same position (UV seams) share one canonical vertex.
    private int[] canon;

    // Neighbours of every canonical vertex, stored as one flat list.
    private int[] neighbourStart;
    private int[] neighbours;

    private float[] restArea;
    private float restTotalArea;
    private float[] currentArea;
    private float[] tension;
    private float[] scratch;

    private ComputeBuffer tensionBuffer;
    private MaterialPropertyBlock propertyBlock;
    private bool ready;

    private void OnEnable()
    {
        Initialise();
    }

    private void OnDisable()
    {
        Release();
    }

    private void LateUpdate()
    {
        if (skinnedRenderer == null)
            skinnedRenderer = GetComponent<SkinnedMeshRenderer>();

        if (!ready || skinnedRenderer.sharedMesh != sourceMesh)
            Initialise();

        if (ready)
            UpdateTension();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Setup
    // ══════════════════════════════════════════════════════════════════════════

    private void Initialise()
    {
        Release();

        skinnedRenderer = GetComponent<SkinnedMeshRenderer>();
        if (skinnedRenderer == null)
            return;

        sourceMesh = skinnedRenderer.sharedMesh;
        if (sourceMesh == null)
            return;

        Vector3[] restVertices = sourceMesh.vertices;
        triangles = sourceMesh.triangles;
        vertexCount = restVertices.Length;

        if (vertexCount == 0 || triangles.Length < 3)
            return;

        BuildCanonicalIndices(restVertices);
        BuildNeighbours();

        restArea = new float[vertexCount];
        currentArea = new float[vertexCount];
        tension = new float[vertexCount];
        scratch = new float[vertexCount];

        restTotalArea = AccumulateAreas(restVertices, restArea);
        if (restTotalArea <= 0f)
            return;

        for (int i = 0; i < vertexCount; i++)
            tension[i] = 1f;

        bakedMesh = new Mesh();
        bakedMesh.name = "StockingTension Baked";
        bakedMesh.hideFlags = HideFlags.HideAndDontSave;

        tensionBuffer = new ComputeBuffer(vertexCount, sizeof(float));
        tensionBuffer.SetData(tension);

        propertyBlock = new MaterialPropertyBlock();
        ready = true;
    }

    private void Release()
    {
        ready = false;

        if (skinnedRenderer != null)
            skinnedRenderer.SetPropertyBlock(null);

        if (tensionBuffer != null)
        {
            tensionBuffer.Release();
            tensionBuffer = null;
        }

        if (bakedMesh != null)
        {
            if (Application.isPlaying) Destroy(bakedMesh);
            else DestroyImmediate(bakedMesh);
            bakedMesh = null;
        }
    }

    private void BuildCanonicalIndices(Vector3[] positions)
    {
        canon = new int[vertexCount];

        // Snap positions to a fine grid so seam vertices land in the same cell.
        float grid = Mathf.Max(sourceMesh.bounds.size.magnitude * 1e-5f, 1e-7f);
        var cellToVertex = new Dictionary<Vector3Int, int>(vertexCount);

        for (int i = 0; i < vertexCount; i++)
        {
            Vector3 p = positions[i] / grid;
            var cell = new Vector3Int(
                Mathf.RoundToInt(p.x), Mathf.RoundToInt(p.y), Mathf.RoundToInt(p.z));

            if (!cellToVertex.TryGetValue(cell, out int first))
            {
                first = i;
                cellToVertex[cell] = i;
            }
            canon[i] = first;
        }
    }

    private void BuildNeighbours()
    {
        var sets = new HashSet<int>[vertexCount];

        for (int t = 0; t + 2 < triangles.Length; t += 3)
        {
            int a = canon[triangles[t]];
            int b = canon[triangles[t + 1]];
            int c = canon[triangles[t + 2]];
            AddNeighbour(sets, a, b);
            AddNeighbour(sets, b, c);
            AddNeighbour(sets, c, a);
        }

        neighbourStart = new int[vertexCount + 1];
        int total = 0;
        for (int i = 0; i < vertexCount; i++)
        {
            neighbourStart[i] = total;
            if (sets[i] != null) total += sets[i].Count;
        }
        neighbourStart[vertexCount] = total;

        neighbours = new int[total];
        for (int i = 0; i < vertexCount; i++)
        {
            if (sets[i] == null) continue;
            int k = neighbourStart[i];
            foreach (int n in sets[i]) neighbours[k++] = n;
        }
    }

    private static void AddNeighbour(HashSet<int>[] sets, int a, int b)
    {
        if (a == b) return;
        if (sets[a] == null) sets[a] = new HashSet<int>();
        if (sets[b] == null) sets[b] = new HashSet<int>();
        sets[a].Add(b);
        sets[b].Add(a);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Per frame
    // ══════════════════════════════════════════════════════════════════════════

    private void UpdateTension()
    {
        skinnedRenderer.BakeMesh(bakedMesh, true);
        bakedMesh.GetVertices(bakedVertices);
        if (bakedVertices.Count != vertexCount)
            return;

        float currentTotalArea = AccumulateAreas(bakedVertices, currentArea);
        if (currentTotalArea <= 0f)
            return;

        // Removes the character's scale and the mesh's units from the ratio.
        float normalise = restTotalArea / currentTotalArea;

        for (int i = 0; i < vertexCount; i++)
        {
            if (canon[i] != i) continue;
            tension[i] = restArea[i] > 1e-12f
                ? currentArea[i] / restArea[i] * normalise
                : 1f;
        }

        for (int pass = 0; pass < smoothingPasses; pass++)
            SmoothCanonical();

        // Seam copies take the value of their canonical vertex.
        for (int i = 0; i < vertexCount; i++)
            tension[i] = tension[canon[i]];

        tensionBuffer.SetData(tension);

        skinnedRenderer.GetPropertyBlock(propertyBlock);
        propertyBlock.SetBuffer(TensionBufferId, tensionBuffer);
        skinnedRenderer.SetPropertyBlock(propertyBlock);
    }

    /// <summary>
    /// Adds a third of every triangle's area to each of its (canonical)
    /// vertices. Returns the total area.
    /// </summary>
    private float AccumulateAreas(IList<Vector3> positions, float[] areas)
    {
        for (int i = 0; i < vertexCount; i++)
            areas[i] = 0f;

        float total = 0f;
        for (int t = 0; t + 2 < triangles.Length; t += 3)
        {
            int ia = triangles[t];
            int ib = triangles[t + 1];
            int ic = triangles[t + 2];

            Vector3 a = positions[ia];
            float area = Vector3.Cross(positions[ib] - a, positions[ic] - a).magnitude * 0.5f;
            float third = area / 3f;

            areas[canon[ia]] += third;
            areas[canon[ib]] += third;
            areas[canon[ic]] += third;
            total += area;
        }

        return total;
    }

    private void SmoothCanonical()
    {
        for (int i = 0; i < vertexCount; i++)
        {
            if (canon[i] != i)
                continue;

            int start = neighbourStart[i];
            int end = neighbourStart[i + 1];
            if (end == start)
            {
                scratch[i] = tension[i];
                continue;
            }

            float sum = 0f;
            for (int k = start; k < end; k++)
                sum += tension[neighbours[k]];

            scratch[i] = tension[i] * 0.5f + sum / (end - start) * 0.5f;
        }

        for (int i = 0; i < vertexCount; i++)
        {
            if (canon[i] == i)
                tension[i] = scratch[i];
        }
    }
}
